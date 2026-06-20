// Safety policy — the human-approval gate. This is the single source of truth for
// "what is dangerous". The dispatcher refuses to auto-execute anything this module
// flags, unless an explicit Approval is presented. Conservative by design: when in
// doubt, flag it (per the project's "decisão mais conservadora" instruction).

import type { TaskCommand } from "./task-schema.ts";

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

/** Token a human (or an approving system) presents to release a gated task. */
export interface Approval {
  approved_by: string;
  note?: string;
  granted_at: string;
}

export function createApproval(approvedBy: string, note?: string): Approval {
  return { approved_by: approvedBy, note, granted_at: new Date().toISOString() };
}
