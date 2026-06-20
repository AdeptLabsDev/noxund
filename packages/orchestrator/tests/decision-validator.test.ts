import { test } from "node:test";
import assert from "node:assert/strict";
import { validateDecision } from "../src/core/decision-validator.ts";
import { createDefaultRegistry } from "../src/agents/index.ts";
import { delegateTask, escalate, noAction } from "../src/core/decision-schema.ts";
import { createTaskCommand } from "../src/core/task-schema.ts";

const registry = createDefaultRegistry();

function task(overrides: Partial<Parameters<typeof createTaskCommand>[0]> = {}) {
  return createTaskCommand({
    target_agent: "data_agent",
    action: "define_scoring_methodology",
    payload: { feature: "Type Beat Market Report" },
    success_criteria: ["define score"],
    reason: "needed before backend",
    ...overrides,
  });
}

test("valid delegate_task passes", () => {
  const v = validateDecision(delegateTask(task()), registry);
  assert.equal(v.ok, true);
  assert.equal(v.requires_human_approval, false);
  assert.equal(v.errors.length, 0);
});

test("unknown decision type is rejected", () => {
  const v = validateDecision({ decision_type: "yolo" }, registry);
  assert.equal(v.ok, false);
  assert.equal(v.errors[0]?.code, "UNKNOWN_DECISION_TYPE");
});

test("malformed JSON (not an object) is rejected", () => {
  const v = validateDecision("not-json", registry);
  assert.equal(v.ok, false);
  assert.equal(v.errors[0]?.code, "DECISION_NOT_OBJECT");
});

test("unknown target agent is rejected", () => {
  const v = validateDecision(delegateTask(task({ target_agent: "ghost_agent" })), registry);
  assert.equal(v.ok, false);
  assert.ok(v.errors.some((e) => e.code === "UNKNOWN_AGENT"));
});

test("action not allowed for the agent is rejected", () => {
  const v = validateDecision(delegateTask(task({ action: "deploy" })), registry);
  assert.equal(v.ok, false);
  assert.ok(v.errors.some((e) => e.code === "ACTION_NOT_ALLOWED"));
});

test("missing required payload key is rejected", () => {
  const v = validateDecision(delegateTask(task({ payload: {} })), registry);
  assert.equal(v.ok, false);
  assert.ok(v.errors.some((e) => e.code === "MISSING_PAYLOAD_KEY"));
});

test("invalid task shape (empty success_criteria) is rejected", () => {
  const v = validateDecision(delegateTask(task({ success_criteria: [] })), registry);
  assert.equal(v.ok, false);
  assert.ok(v.errors.some((e) => e.code === "INVALID_TASK_SHAPE"));
});

test("sensitive task is valid but flagged for human approval", () => {
  const v = validateDecision(
    delegateTask(
      createTaskCommand({
        target_agent: "database_agent",
        action: "run_migration",
        payload: { migration: "m" },
        success_criteria: ["apply"],
        reason: "schema",
      }),
    ),
    registry,
  );
  assert.equal(v.ok, true);
  assert.equal(v.requires_human_approval, true);
  assert.ok(v.warnings.some((w) => w.code === "REQUIRES_HUMAN_APPROVAL"));
});

test("escalate requires open_decision + reason", () => {
  assert.equal(validateDecision(escalate("", "", []), registry).ok, false);
  assert.equal(validateDecision(escalate("conflict", "docs disagree"), registry).ok, true);
});

test("no_action requires a reason", () => {
  assert.equal(validateDecision({ decision_type: "no_action" }, registry).ok, false);
  assert.equal(validateDecision(noAction("waiting on dependency"), registry).ok, true);
});
