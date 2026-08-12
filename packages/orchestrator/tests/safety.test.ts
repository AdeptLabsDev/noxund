import { test } from "node:test";
import assert from "node:assert/strict";
import {
  assessSensitivity,
  mintApproval,
  verifyApproval,
  isApprovalRecord,
  APPROVAL_VERSION,
} from "../src/core/safety.ts";
import { createTaskCommand } from "../src/core/task-schema.ts";
import { computeCommandIdentity } from "../src/core/command-identity.ts";

const T0 = new Date("2026-01-01T00:00:00.000Z");
const MIN = 60_000;

function sensitiveTask() {
  return createTaskCommand({
    task_id: "task_mig",
    target_agent: "database_agent",
    action: "run_migration",
    payload: { migration: "m" },
    success_criteria: ["apply"],
    reason: "schema",
  });
}

test("benign planning task is not sensitive", () => {
  const a = assessSensitivity(
    createTaskCommand({
      target_agent: "data_agent",
      action: "define_scoring_methodology",
      payload: { feature: "X" },
      success_criteria: ["c"],
      reason: "r",
    }),
  );
  assert.equal(a.sensitive, false);
  assert.equal(a.destructive, false);
});

test("sensitive action (run_migration) is flagged", () => {
  const a = assessSensitivity(sensitiveTask());
  assert.equal(a.sensitive, true);
  assert.equal(a.destructive, true);
  assert.ok(a.reasons.some((r) => r.includes("sensitive")));
});

test("destructive payload pattern flags an otherwise-benign action", () => {
  const a = assessSensitivity(
    createTaskCommand({
      target_agent: "devops_agent",
      action: "setup_observability",
      payload: { command: "rm -rf ./dist" },
      success_criteria: ["c"],
      reason: "r",
    }),
  );
  assert.equal(a.destructive, true);
  assert.equal(a.sensitive, true);
});

test("explicit requires_human_approval makes a task sensitive", () => {
  const a = assessSensitivity(
    createTaskCommand({
      target_agent: "data_agent",
      action: "define_scoring_methodology",
      payload: { feature: "X" },
      success_criteria: ["c"],
      requires_human_approval: true,
      reason: "r",
    }),
  );
  assert.equal(a.sensitive, true);
});

test("mintApproval binds to the exact command identity + stamps claimed approver", () => {
  const task = sensitiveTask();
  const ap = mintApproval(task, {
    approved_by: "lead@noxund",
    ttl_ms: 10 * MIN,
    now: T0,
    nonce: "n1",
    note: "ok",
  });
  const expected = computeCommandIdentity({
    task_id: task.task_id,
    target_agent: task.target_agent,
    action: task.action,
    payload: task.payload,
  });
  assert.equal(ap.approval_version, APPROVAL_VERSION);
  assert.equal(ap.command_identity, expected.command_identity);
  assert.equal(ap.payload_digest, expected.payload_digest);
  assert.equal(ap.approved_by, "lead@noxund");
  assert.equal(ap.note, "ok");
  assert.equal(ap.granted_at, "2026-01-01T00:00:00.000Z");
  assert.equal(ap.expires_at, "2026-01-01T00:10:00.000Z");
  assert.match(ap.approval_id, /^appr_/);
});

test("mintApproval fails closed on non-positive ttl and empty approver", () => {
  const task = sensitiveTask();
  assert.throws(() => mintApproval(task, { approved_by: "x", ttl_ms: 0, now: T0, nonce: "n" }));
  assert.throws(() => mintApproval(task, { approved_by: "x", ttl_ms: -1, now: T0, nonce: "n" }));
  assert.throws(() => mintApproval(task, { approved_by: "", ttl_ms: MIN, now: T0, nonce: "n" }));
  assert.throws(() => mintApproval(task, { approved_by: "x", ttl_ms: MIN, now: T0, nonce: "" }));
});

test("verifyApproval accepts a matching, unexpired, known-version approval", () => {
  const task = sensitiveTask();
  const ap = mintApproval(task, { approved_by: "lead", ttl_ms: 10 * MIN, now: T0, nonce: "n1" });
  const live = computeCommandIdentity({
    task_id: task.task_id,
    target_agent: task.target_agent,
    action: task.action,
    payload: task.payload,
  }).command_identity;
  const v = verifyApproval(ap, live, new Date(T0.getTime() + MIN));
  assert.equal(v.ok, true);
});

test("verifyApproval rejects a legacy/unbound token (no command_identity)", () => {
  const legacy = { approved_by: "lead@noxund", granted_at: T0.toISOString() };
  assert.equal(isApprovalRecord(legacy), false);
  const v = verifyApproval(legacy, "any-identity", T0);
  assert.equal(v.ok, false);
  assert.equal(v.ok === false && v.code, "UNBOUND_OR_MALFORMED_APPROVAL");
});

test("verifyApproval rejects an identity mismatch", () => {
  const task = sensitiveTask();
  const ap = mintApproval(task, { approved_by: "lead", ttl_ms: 10 * MIN, now: T0, nonce: "n1" });
  const v = verifyApproval(ap, "a-different-command-identity", new Date(T0.getTime() + MIN));
  assert.equal(v.ok, false);
  assert.equal(v.ok === false && v.code, "COMMAND_IDENTITY_MISMATCH");
});

test("verifyApproval rejects an unknown approval_version", () => {
  const task = sensitiveTask();
  const ap = mintApproval(task, { approved_by: "lead", ttl_ms: 10 * MIN, now: T0, nonce: "n1" });
  const live = ap.command_identity;
  const tampered = { ...ap, approval_version: 999 };
  const v = verifyApproval(tampered, live, new Date(T0.getTime() + MIN));
  assert.equal(v.ok, false);
  assert.equal(v.ok === false && v.code, "UNKNOWN_APPROVAL_VERSION");
});

test("verifyApproval expiry: before accepted, exact boundary rejected, after rejected", () => {
  const task = sensitiveTask();
  const ap = mintApproval(task, { approved_by: "lead", ttl_ms: 10 * MIN, now: T0, nonce: "n1" });
  const live = ap.command_identity;
  const expires = Date.parse(ap.expires_at);

  // before
  assert.equal(verifyApproval(ap, live, new Date(expires - 1)).ok, true);
  // exact boundary → EXPIRED (now >= expires_at)
  const atBoundary = verifyApproval(ap, live, new Date(expires));
  assert.equal(atBoundary.ok, false);
  assert.equal(atBoundary.ok === false && atBoundary.code, "APPROVAL_EXPIRED");
  // after
  const after = verifyApproval(ap, live, new Date(expires + 1));
  assert.equal(after.ok, false);
  assert.equal(after.ok === false && after.code, "APPROVAL_EXPIRED");
});

// PROVENANCE HONESTY — approved_by is CLAIMED ONLY, not authenticated.
// This is BLOCKED / TODO-BY-DESIGN for this unit (APPROVER-PROVENANCE-GAP = OPEN).
// It is intentionally recorded as skipped and MUST NOT be represented as passing.
test("provenance of approved_by is authenticated", { skip: "TODO-BY-DESIGN: APPROVER-PROVENANCE-GAP = OPEN-BLOCKING-OPERATIONAL — approved_by is a claimed identity only; authenticated provenance is out of scope for this unit" }, () => {
  assert.fail("authenticated approver provenance is not implemented (by design, this unit)");
});
