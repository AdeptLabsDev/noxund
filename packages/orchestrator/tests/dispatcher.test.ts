import { test } from "node:test";
import assert from "node:assert/strict";
import { createDispatcher, HUMAN_APPROVAL_SUMMARY } from "../src/core/dispatcher.ts";
import { createRegistry } from "../src/core/agent-registry.ts";
import { createDefaultRegistry } from "../src/agents/index.ts";
import { defineAgent } from "../src/agents/base-agent.ts";
import { createTaskCommand } from "../src/core/task-schema.ts";
import { createApproval } from "../src/core/safety.ts";
import { result } from "../src/core/result-schema.ts";

const registry = createDefaultRegistry();

function task(overrides: Partial<Parameters<typeof createTaskCommand>[0]> = {}) {
  return createTaskCommand({
    target_agent: "data_agent",
    action: "define_scoring_methodology",
    payload: { feature: "X" },
    success_criteria: ["c"],
    reason: "r",
    ...overrides,
  });
}

test("happy path routes to the agent and returns completed", async () => {
  const d = createDispatcher({ registry });
  const out = await d.dispatch(task());
  assert.equal(out.result.status, "completed");
  assert.equal(out.result.agent, "data_agent");
  assert.equal(out.gated, false);
});

test("unknown agent yields a failed result, not a throw", async () => {
  const d = createDispatcher({ registry });
  const out = await d.dispatch(task({ target_agent: "ghost_agent" }));
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "UNKNOWN_AGENT");
});

test("disallowed action yields a failed result", async () => {
  const d = createDispatcher({ registry });
  const out = await d.dispatch(task({ action: "deploy" }));
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "ACTION_NOT_ALLOWED");
});

test("sensitive task without approval is gated to needs_review", async () => {
  const d = createDispatcher({ registry });
  const out = await d.dispatch(
    createTaskCommand({
      target_agent: "database_agent",
      action: "run_migration",
      payload: { migration: "m" },
      success_criteria: ["apply"],
      reason: "schema",
    }),
  );
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.summary, HUMAN_APPROVAL_SUMMARY);
  assert.equal(out.gated, true);
});

test("sensitive task with approval executes", async () => {
  const d = createDispatcher({ registry });
  const out = await d.dispatch(
    createTaskCommand({
      target_agent: "database_agent",
      action: "run_migration",
      payload: { migration: "m" },
      success_criteria: ["apply"],
      reason: "schema",
    }),
    { approval: createApproval("lead@noxund") },
  );
  assert.equal(out.result.status, "completed");
  assert.equal(out.gated, false);
});

test("an agent that throws is contained as a failed result", async () => {
  const throwing = defineAgent({
    id: "boom_agent",
    name: "Boom",
    description: "always throws",
    owns: "nothing",
    handlers: {
      explode: () => {
        throw new Error("kaboom");
      },
    },
  });
  const d = createDispatcher({ registry: createRegistry([throwing]) });
  const out = await d.dispatch(
    createTaskCommand({
      target_agent: "boom_agent",
      action: "explode",
      payload: {},
      success_criteria: ["c"],
      reason: "r",
    }),
  );
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "AGENT_EXCEPTION");
  assert.match(out.result.errors[0]?.message ?? "", /kaboom/);
});

test("an agent returning a malformed envelope is rejected", async () => {
  const bad = defineAgent({
    id: "bad_agent",
    name: "Bad",
    description: "returns garbage",
    owns: "nothing",
    handlers: {
      // @ts-expect-error intentionally malformed result for the test
      misbehave: () => ({ nope: true }),
    },
  });
  const d = createDispatcher({ registry: createRegistry([bad]) });
  const out = await d.dispatch(
    createTaskCommand({
      target_agent: "bad_agent",
      action: "misbehave",
      payload: {},
      success_criteria: ["c"],
      reason: "r",
    }),
  );
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "INVALID_RESULT_SHAPE");
});
