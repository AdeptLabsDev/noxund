// Command Identity — deterministic, collision-resistant identity for an
// authority-bearing TaskCommand. This is the cryptographic substrate the approval
// gate binds to: an approval is valid ONLY for the exact command whose identity it
// carries. Any mutation of {task_id, target_agent, action, payload} changes the
// identity and invalidates the approval.
//
// SCOPE / NON-GOALS (locked for this unit):
//   - This computes a content-addressed IDENTITY. It is NOT a signature, NOT a MAC,
//     and proves NOTHING about WHO produced the command or the approval. Provenance
//     (authenticated approver identity) is explicitly OUT OF SCOPE and remains OPEN.
//   - No external dependency: only `node:crypto`. No new npm package is introduced.
//
// Canonicalization contract (RFC 8785 / JCS-compatible over the JSON payload domain):
//   - object keys are emitted in ascending UTF-16 code-unit order (JS default
//     Array.prototype.sort on the key strings — this matches JCS's code-unit order);
//   - array element order is preserved (order is semantically significant);
//   - strings are serialized via deterministic JSON string production (JSON.stringify
//     of the string), WITHOUT any Unicode normalization (NFC/NFD compositions remain
//     distinct on purpose);
//   - numbers use ECMAScript Number-to-String (ToString), with the single fix that
//     -0 serializes as "0" (JCS treats -0 and 0 as equal);
//   - supported value domain: null, boolean, finite number, string, array, plain
//     object. EVERYTHING ELSE FAILS CLOSED (throws): undefined, function, symbol,
//     bigint, NaN, +/-Infinity, Date/Map/Set/host objects, and circular structures.
//     We never silently coerce an unsupported value.

import { createHash } from "node:crypto";

/** Domain-separation tags. Versioned so the wire format can evolve without ambiguity. */
export const PAYLOAD_DOMAIN_V1 = "NOXUND.orchestrator.payload.v1";
export const COMMAND_IDENTITY_DOMAIN_V1 = "NOXUND.orchestrator.command-identity.v1";

/** ASCII Unit Separator (0x1F) — frames the identity fields so they cannot collide. */
const UNIT_SEPARATOR = "";

/** The authority-bearing subset of a TaskCommand that the identity is derived from. */
export interface CommandSubject {
  task_id: string;
  target_agent: string;
  action: string;
  payload: unknown;
}

/**
 * Thrown when canonicalization encounters a value outside the supported JSON domain.
 * Fail-closed: the caller must treat this as "cannot compute identity" (reject), never
 * as "empty payload".
 */
export class CanonicalizationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CanonicalizationError";
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  // Reject class instances / host objects: only accept `{}`-literals and null-prototype
  // objects. Anything with a non-Object/non-null prototype is not a plain data object.
  const proto = Object.getPrototypeOf(value) as object | null;
  return proto === Object.prototype || proto === null;
}

/**
 * Deterministically serialize an ECMAScript number per JCS.
 * Uses ToString (which JS `String(n)` / template already does), forcing -0 → "0".
 * Non-finite numbers are rejected by the caller before reaching here.
 */
function serializeNumber(n: number): string {
  // Object.is distinguishes -0 from +0; JCS collapses them.
  if (Object.is(n, -0)) return "0";
  return String(n);
}

/**
 * Produce the canonical JSON text for a value. Recursive; fails closed on anything
 * outside the supported domain. `seen` guards against circular references.
 */
function canonicalizeValue(value: unknown, seen: Set<object>): string {
  if (value === null) return "null";

  const t = typeof value;

  if (t === "boolean") return value ? "true" : "false";

  if (t === "number") {
    const n = value as number;
    if (!Number.isFinite(n)) {
      throw new CanonicalizationError(
        `non-finite number is not serializable: ${String(n)}`,
      );
    }
    return serializeNumber(n);
  }

  if (t === "string") {
    // JSON.stringify performs deterministic JSON string escaping. No Unicode
    // normalization is applied, so distinct compositions hash distinctly.
    return JSON.stringify(value);
  }

  if (t === "undefined") {
    throw new CanonicalizationError("undefined is not serializable (fail closed)");
  }
  if (t === "function") {
    throw new CanonicalizationError("function is not serializable (fail closed)");
  }
  if (t === "symbol") {
    throw new CanonicalizationError("symbol is not serializable (fail closed)");
  }
  if (t === "bigint") {
    throw new CanonicalizationError("bigint is not serializable (fail closed)");
  }

  // Composite types.
  if (Array.isArray(value)) {
    if (seen.has(value)) {
      throw new CanonicalizationError("circular structure is not serializable (fail closed)");
    }
    seen.add(value);
    // Array order is significant. Each element must itself be in-domain — arrays may
    // NOT contain holes/undefined. We iterate by index (NOT Array.map, which SKIPS
    // holes) so a sparse array fails closed instead of silently collapsing.
    const parts: string[] = [];
    for (let i = 0; i < value.length; i++) {
      if (!(i in value)) {
        throw new CanonicalizationError(
          `array hole at index ${i} is not serializable (fail closed)`,
        );
      }
      const el = value[i];
      if (el === undefined) {
        throw new CanonicalizationError(
          `array element at index ${i} is undefined (fail closed)`,
        );
      }
      parts.push(canonicalizeValue(el, seen));
    }
    seen.delete(value);
    return "[" + parts.join(",") + "]";
  }

  if (isPlainObject(value)) {
    if (seen.has(value)) {
      throw new CanonicalizationError("circular structure is not serializable (fail closed)");
    }
    seen.add(value);
    // Sort keys by UTF-16 code unit (JS default sort on strings == JCS ordering).
    const keys = Object.keys(value).sort();
    const parts: string[] = [];
    for (const key of keys) {
      const child = value[key];
      // A key mapping to `undefined` is NOT valid JSON — fail closed rather than drop it
      // (dropping would let two distinct payloads collide).
      if (child === undefined) {
        throw new CanonicalizationError(
          `object key "${key}" maps to undefined (fail closed)`,
        );
      }
      parts.push(JSON.stringify(key) + ":" + canonicalizeValue(child, seen));
    }
    seen.delete(value);
    return "{" + parts.join(",") + "}";
  }

  // Any other object (Date, Map, Set, RegExp, class instances, host objects…).
  throw new CanonicalizationError(
    "unsupported non-plain object is not serializable (fail closed)",
  );
}

/**
 * RFC 8785 / JCS-compatible canonical serialization of a JSON value.
 * Deterministic and stable across runs/processes. Throws (fail closed) on any value
 * outside the supported JSON data domain.
 */
export function canonicalize(value: unknown): string {
  return canonicalizeValue(value, new Set<object>());
}

function sha256Hex(...parts: string[]): string {
  const h = createHash("sha256");
  for (const p of parts) h.update(p, "utf8");
  return h.digest("hex");
}

/**
 * payload_digest = "sha256:" + hex(sha256( utf8(PAYLOAD_DOMAIN_V1) + utf8(canonical(payload)) )).
 * The domain tag is prefixed so a payload digest can never be confused with a bare
 * SHA-256 of arbitrary bytes.
 */
export function computePayloadDigest(payload: unknown): string {
  const canonical = canonicalize(payload);
  return "sha256:" + sha256Hex(PAYLOAD_DOMAIN_V1, canonical);
}

/**
 * command_identity = hex(sha256( domain-separated, 0x1F-framed:
 *   COMMAND_IDENTITY_DOMAIN_V1, task_id, target_agent, action, payload_digest )).
 *
 * The 0x1F Unit Separator frames each field so that no combination of field contents
 * can produce the same byte stream as a different field split (e.g. task_id "a" +
 * action "bc" vs task_id "ab" + action "c").
 */
export function computeCommandIdentityFrom(subject: {
  task_id: string;
  target_agent: string;
  action: string;
  payload_digest: string;
}): string {
  const framed =
    COMMAND_IDENTITY_DOMAIN_V1 +
    UNIT_SEPARATOR +
    subject.task_id +
    UNIT_SEPARATOR +
    subject.target_agent +
    UNIT_SEPARATOR +
    subject.action +
    UNIT_SEPARATOR +
    subject.payload_digest;
  return sha256Hex(framed);
}

export interface CommandIdentity {
  payload_digest: string;
  command_identity: string;
}

/**
 * Pure derivation of a command's authority-bearing identity from a TaskCommand-like
 * subject. Throws (fail closed) if the payload is not canonicalizable.
 */
export function computeCommandIdentity(subject: CommandSubject): CommandIdentity {
  if (typeof subject.task_id !== "string") {
    throw new CanonicalizationError("task_id must be a string");
  }
  if (typeof subject.target_agent !== "string") {
    throw new CanonicalizationError("target_agent must be a string");
  }
  if (typeof subject.action !== "string") {
    throw new CanonicalizationError("action must be a string");
  }
  const payload_digest = computePayloadDigest(subject.payload);
  const command_identity = computeCommandIdentityFrom({
    task_id: subject.task_id,
    target_agent: subject.target_agent,
    action: subject.action,
    payload_digest,
  });
  return { payload_digest, command_identity };
}
