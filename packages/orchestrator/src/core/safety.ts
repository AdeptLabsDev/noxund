// Safety policy — the human-approval gate. This is the single source of truth for
// "what is dangerous". The dispatcher refuses to auto-execute anything this module
// flags, unless a COMMAND-BOUND ApprovalRecord for the exact command is presented.
// Conservative by design: when in doubt, flag it (per the project's "decisão mais
// conservadora" instruction).

import type { TaskCommand } from "./task-schema.ts";
import {
  computeCommandIdentity,
  type CommandIdentity,
} from "./command-identity.ts";

/**
 * Actions that ALWAYS require human approval, regardless of payload. These map
 * directly to the destructive operations listed in the project brief.
 */
export const SENSITIVE_ACTIONS: ReadonlySet<string> = new Set([
  "delete_files",
  "remove_directory",
  "overwrite_file",
  "modify_env",
  "configure_env",
  "install_dependency",
  "change_db_schema",
  "design_schema_change",
  "run_migration",
  "run_destructive_migration",
  "git_push",
  "deploy",
  "change_core_architecture",
  "run_shell_command",
]);

/**
 * Payload heuristics that indicate a destructive operation even when the action
 * name looks benign. Matched against a JSON serialization of the payload.
 */
const DESTRUCTIVE_PATTERNS: ReadonlyArray<{ label: string; re: RegExp }> = [
  { label: "rm -rf", re: /\brm\s+-rf?\b/i },
  { label: "recursive force delete", re: /\b(remove|delete)[-_]?(dir|directory|folder|recursive)\b/i },
  { label: "DROP/TRUNCATE (destructive SQL)", re: /\b(drop|truncate)\s+(table|database|schema|index)\b/i },
  { label: "DELETE without WHERE", re: /\bdelete\s+from\b(?![\s\S]*\bwhere\b)/i },
  { label: "force flag", re: /(--force\b|force\s*[:=]\s*true|\bforce[-_]?push\b)/i },
  { label: "git push", re: /\bgit\s+push\b/i },
  { label: "deploy", re: /\b(deploy|vercel\s+--prod|--prod\b)\b/i },
  { label: ".env mutation", re: /\.env\b/i },
  { label: "dependency install", re: /\b(npm\s+i(nstall)?|pnpm\s+add|yarn\s+add|pip\s+install)\b/i },
  { label: "migration", re: /\bmigrat(e|ion)\b/i },
  { label: "overwrite", re: /\b(overwrite|truncate|wipe|reset\s+--hard)\b/i },
];

export interface SensitivityAssessment {
  /** Whether the task may NOT run autonomously. */
  sensitive: boolean;
  /** Whether the task looks irreversibly destructive (subset of sensitive). */
  destructive: boolean;
  /** Human-readable reasons, suitable for logs and the needs_review summary. */
  reasons: string[];
}

/**
 * Decide whether a task is sensitive (needs a human) and/or destructive.
 * Sources, in order:
 *   1. explicit `requires_human_approval` on the task;
 *   2. the action name being in SENSITIVE_ACTIONS;
 *   3. destructive payload patterns.
 *
 * NOTE: this classification logic is deliberately UNCHANGED by the command-binding
 * hardening. What changed is what counts as a VALID *approval*, not what is sensitive.
 */
export function assessSensitivity(task: TaskCommand): SensitivityAssessment {
  const reasons: string[] = [];
  let destructive = false;

  if (task.requires_human_approval) {
    reasons.push("task explicitly marked requires_human_approval");
  }

  if (SENSITIVE_ACTIONS.has(task.action)) {
    reasons.push(`action "${task.action}" is classified as sensitive`);
    // Schema/migration/deploy/delete-style actions are treated as destructive.
    destructive = true;
  }

  let payloadJson = "";
  try {
    payloadJson = JSON.stringify(task.payload ?? {});
  } catch {
    // A payload that cannot even be serialized is itself a red flag.
    reasons.push("payload is not serializable (potential circular/unsafe structure)");
    destructive = true;
  }

  for (const { label, re } of DESTRUCTIVE_PATTERNS) {
    if (re.test(payloadJson)) {
      reasons.push(`payload matches destructive pattern: ${label}`);
      destructive = true;
    }
  }

  const sensitive = reasons.length > 0;
  return { sensitive, destructive, reasons };
}

// ---------------------------------------------------------------------------
// Command-bound approvals.
// ---------------------------------------------------------------------------

/** Bumped whenever the ApprovalRecord wire shape or binding semantics change. */
export const APPROVAL_VERSION = 1 as const;

/** The set of approval_version values this build knows how to verify. */
export const KNOWN_APPROVAL_VERSIONS: ReadonlySet<number> = new Set([APPROVAL_VERSION]);

/**
 * A COMMAND-BOUND approval. Unlike the previous truthiness token, this binds the grant
 * to the exact authority-bearing identity of ONE TaskCommand. The dispatcher recomputes
 * `command_identity` from the live command about to run and refuses to execute unless it
 * matches — so mutating task_id/target_agent/action/payload after approval invalidates it.
 *
 * PROVENANCE (SECURITY-CRITICAL, OPEN):
 *   `approved_by` is a CLAIMED IDENTITY ONLY. It is NOT authenticated. Nothing here
 *   proves the named human actually granted the approval. Authenticated approver
 *   provenance is OUT OF SCOPE for this unit:
 *       APPROVER-PROVENANCE-GAP = OPEN-BLOCKING-OPERATIONAL.
 *   Do NOT treat a present `approved_by` as authorization by that principal.
 */
export interface ApprovalRecord {
  /** Wire/semantics version. Verified against KNOWN_APPROVAL_VERSIONS. */
  approval_version: number;
  /** Unique id for this grant. Used as the single-use consumption ledger key. */
  approval_id: string;
  /** Bound command coordinates — mirror the subject the identity is derived from. */
  task_id: string;
  target_agent: string;
  action: string;
  /** "sha256:<hex>" digest of the canonical payload at approval time. */
  payload_digest: string;
  /** The full command identity this approval authorizes (and only this). */
  command_identity: string;
  /**
   * CLAIMED approver identity — NOT authenticated provenance. See ApprovalRecord doc.
   */
  approved_by: string;
  /** ISO-8601 timestamp the approval was minted (from the injected clock). */
  granted_at: string;
  /** ISO-8601 timestamp after which the approval is EXPIRED and cannot be used. */
  expires_at: string;
  /** Optional free-form note (audit only; not part of the binding). */
  note?: string;
}

export interface MintApprovalOptions {
  /** CLAIMED approver identity (see provenance caveat). Required. */
  approved_by: string;
  /** Time-to-live in milliseconds. Must be > 0. */
  ttl_ms: number;
  /** Injected clock — the moment of granting. Deterministic in tests. */
  now: Date;
  /** Unique nonce for approval_id. Caller-supplied so it's deterministic in tests. */
  nonce: string;
  note?: string;
}

/**
 * Mint a command-bound approval for a CONCRETE command. There is deliberately NO way to
 * mint an approval without a real command: `command_identity`/`payload_digest` are derived
 * here from the task itself, closing the old unbound `createApproval("anyone")` path.
 *
 * Throws (fail closed) if the payload is not canonicalizable or ttl_ms <= 0.
 */
export function mintApproval(task: TaskCommand, opts: MintApprovalOptions): ApprovalRecord {
  if (typeof opts.approved_by !== "string" || opts.approved_by.trim() === "") {
    throw new Error("mintApproval: approved_by (claimed identity) is required");
  }
  if (!Number.isFinite(opts.ttl_ms) || opts.ttl_ms <= 0) {
    throw new Error("mintApproval: ttl_ms must be a positive finite number");
  }
  if (!(opts.now instanceof Date) || Number.isNaN(opts.now.getTime())) {
    throw new Error("mintApproval: now must be a valid Date");
  }
  if (typeof opts.nonce !== "string" || opts.nonce.trim() === "") {
    throw new Error("mintApproval: nonce is required");
  }

  const identity: CommandIdentity = computeCommandIdentity({
    task_id: task.task_id,
    target_agent: task.target_agent,
    action: task.action,
    payload: task.payload,
  });

  const grantedMs = opts.now.getTime();
  const expiresMs = grantedMs + opts.ttl_ms;

  return {
    approval_version: APPROVAL_VERSION,
    approval_id: `appr_${opts.nonce}`,
    task_id: task.task_id,
    target_agent: task.target_agent,
    action: task.action,
    payload_digest: identity.payload_digest,
    command_identity: identity.command_identity,
    approved_by: opts.approved_by,
    granted_at: new Date(grantedMs).toISOString(),
    expires_at: new Date(expiresMs).toISOString(),
    note: opts.note,
  };
}

/** Result of verifying an approval against a live, recomputed command identity. */
export type ApprovalVerification =
  | { ok: true }
  | { ok: false; code: ApprovalRejectionCode; message: string };

export type ApprovalRejectionCode =
  | "UNBOUND_OR_MALFORMED_APPROVAL"
  | "UNKNOWN_APPROVAL_VERSION"
  | "COMMAND_IDENTITY_MISMATCH"
  | "APPROVAL_EXPIRED";

/**
 * Type guard: is this object shaped like a command-bound ApprovalRecord? A legacy/unbound
 * token (only `approved_by`/`granted_at`, missing `command_identity`) fails here and is
 * therefore rejected — there is intentionally NO compatibility fallback.
 */
export function isApprovalRecord(value: unknown): value is ApprovalRecord {
  if (typeof value !== "object" || value === null) return false;
  const a = value as Record<string, unknown>;
  return (
    typeof a.approval_version === "number" &&
    typeof a.approval_id === "string" &&
    typeof a.task_id === "string" &&
    typeof a.target_agent === "string" &&
    typeof a.action === "string" &&
    typeof a.payload_digest === "string" &&
    typeof a.command_identity === "string" &&
    typeof a.approved_by === "string" &&
    typeof a.granted_at === "string" &&
    typeof a.expires_at === "string"
  );
}

/**
 * Verify a presented approval against the LIVE recomputed identity and the gate clock.
 * Pure: performs no consumption. The dispatcher owns ordering + single-use consumption.
 *
 * Rejection is fail-closed for every branch:
 *   - not an ApprovalRecord (legacy/unbound/garbage) → UNBOUND_OR_MALFORMED_APPROVAL;
 *   - unknown approval_version → UNKNOWN_APPROVAL_VERSION;
 *   - command_identity != recomputed live identity → COMMAND_IDENTITY_MISMATCH;
 *   - now >= expires_at → APPROVAL_EXPIRED (boundary is exclusive: expired at exactly expires_at).
 */
export function verifyApproval(
  approval: unknown,
  liveCommandIdentity: string,
  now: Date,
): ApprovalVerification {
  if (!isApprovalRecord(approval)) {
    return {
      ok: false,
      code: "UNBOUND_OR_MALFORMED_APPROVAL",
      message:
        "approval is not a command-bound ApprovalRecord (legacy/unbound approvals are rejected)",
    };
  }
  if (!KNOWN_APPROVAL_VERSIONS.has(approval.approval_version)) {
    return {
      ok: false,
      code: "UNKNOWN_APPROVAL_VERSION",
      message: `approval_version ${approval.approval_version} is not recognized`,
    };
  }
  if (approval.command_identity !== liveCommandIdentity) {
    return {
      ok: false,
      code: "COMMAND_IDENTITY_MISMATCH",
      message:
        "approval.command_identity does not match the live command about to execute",
    };
  }
  const expiresMs = Date.parse(approval.expires_at);
  if (Number.isNaN(expiresMs)) {
    return {
      ok: false,
      code: "UNBOUND_OR_MALFORMED_APPROVAL",
      message: "approval.expires_at is not a valid timestamp",
    };
  }
  // now < expires_at eligible; now >= expires_at EXPIRED (exact boundary rejected).
  if (now.getTime() >= expiresMs) {
    return {
      ok: false,
      code: "APPROVAL_EXPIRED",
      message: `approval expired at ${approval.expires_at}`,
    };
  }
  return { ok: true };
}
