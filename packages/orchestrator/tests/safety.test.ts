import { test } from "node:test";
import assert from "node:assert/strict";
import { assessSensitivity, createApproval } from "../src/core/safety.ts";
import { createTaskCommand } from "../src/core/task-schema.ts";

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
  const a = assessSensitivity(
    createTaskCommand({
      target_agent: "database_agent",
      action: "run_migration",
      payload: { migration: "m" },
      success_criteria: ["c"],
      reason: "r",
    }),
  );
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

test("createApproval stamps who + when", () => {
  const ap = createApproval("lead@noxund", "ok");
  assert.equal(ap.approved_by, "lead@noxund");
  assert.equal(ap.note, "ok");
  assert.ok(Date.parse(ap.granted_at) > 0);
});
