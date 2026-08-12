import { test } from "node:test";
import assert from "node:assert/strict";
import { createOrchestrator } from "../src/core/orchestrator.ts";
import { createStateStore } from "../src/core/project-state.ts";
import { createLogger, memorySink, type MemorySink } from "../src/core/logger.ts";
import { createDefaultRegistry } from "../src/agents/index.ts";
import { delegateTask } from "../src/core/decision-schema.ts";
import { createTaskCommand } from "../src/core/task-schema.ts";
import { mintApproval } from "../src/core/safety.ts";

const T0 = new Date("2026-01-01T00:00:00.000Z");
const MIN = 60_000;

function harness() {
  const registry = createDefaultRegistry();
  const state = createStateStore(); // in-memory
  const sink: MemorySink = memorySink();
  const logger = createLogger({ sinks: [sink] });
  // Fixed gate clock so approval expiry is deterministic.
  const orchestrator = createOrchestrator({ registry, state, logger, clock: () => T0 });
  return { orchestrator, sink };
}

test("end-to-end: delegate → validate → dispatch → result → state update → next", async () => {
  const { orchestrator, sink } = harness();
  const run = await orchestrator.run(
    delegateTask(
      createTaskCommand({
        task_id: "task_042",
        target_agent: "data_agent",
        action: "define_scoring_methodology",
        priority: "high",
        payload: { feature: "Type Beat Market Report" },
        success_criteria: ["define score"],
        reason: "methodology before backend",
      }),
    ),
  );

  assert.equal(run.validation.ok, true);
  assert.equal(run.result?.status, "completed");
  assert.equal(run.gated, false);
  assert.deepEqual(run.state.completed_tasks, ["task_042"]);
  assert.equal(run.state.pending_tasks.length, 0);
  assert.equal(run.next?.target_agent, "backend_agent");

  // Decision + result are both logged (terminal-as-observation).
  assert.ok(sink.records.some((r) => r.event === "decision.received"));
  assert.ok(sink.records.some((r) => r.event === "result.recorded"));
  // Decision is recorded in central state.
  assert.equal(run.state.decisions.length, 1);
});

test("invalid decision is blocked before any agent runs", async () => {
  const { orchestrator, sink } = harness();
  const run = await orchestrator.run(
    delegateTask(
      createTaskCommand({
        task_id: "task_bad",
        target_agent: "frontend_agent",
        action: "rm_rf_everything",
        payload: {},
        success_criteria: ["never"],
        reason: "invalid",
      }),
    ),
  );
  assert.equal(run.validation.ok, false);
  assert.equal(run.result, null);
  assert.deepEqual(run.state.blocked_tasks, ["task_bad"]);
  assert.ok(sink.records.some((r) => r.event === "decision.invalid"));
});

test("sensitive task is gated, then runs once approved (command-bound)", async () => {
  const { orchestrator } = harness();
  const input = {
    task_id: "task_mig",
    target_agent: "database_agent",
    action: "run_migration",
    priority: "critical" as const,
    payload: { migration: "m" },
    success_criteria: ["apply"],
    reason: "schema",
  };

  const gated = await orchestrator.delegate(input);
  assert.equal(gated.result?.status, "needs_review");
  assert.equal(gated.gated, true);
  assert.deepEqual(gated.state.blocked_tasks, ["task_mig"]);

  // Mint an approval bound to the EXACT command the orchestrator will build.
  const boundTask = createTaskCommand(input);
  const approval = mintApproval(boundTask, {
    approved_by: "lead@noxund",
    ttl_ms: 10 * MIN,
    now: T0,
    nonce: "flow1",
    note: "reviewed",
  });

  const approved = await orchestrator.delegate(input, { approval });
  assert.equal(approved.result?.status, "completed");
  assert.deepEqual(approved.state.completed_tasks, ["task_mig"]);
  assert.deepEqual(approved.state.blocked_tasks, []);
});

test("a legacy/unbound approval cannot release a gated task through the orchestrator", async () => {
  const { orchestrator } = harness();
  const input = {
    task_id: "task_mig2",
    target_agent: "database_agent",
    action: "run_migration",
    priority: "critical" as const,
    payload: { migration: "m" },
    success_criteria: ["apply"],
    reason: "schema",
  };
  // Legacy truthiness token — no command binding.
  const legacy = { approved_by: "lead@noxund", granted_at: T0.toISOString() } as never;
  const run = await orchestrator.delegate(input, { approval: legacy });
  assert.equal(run.result?.status, "needs_review");
  assert.equal(run.gated, true);
  assert.deepEqual(run.state.blocked_tasks, ["task_mig2"]);
});

test("no_action is recorded without dispatching", async () => {
  const { orchestrator } = harness();
  const run = await orchestrator.run({ decision_type: "no_action", reason: "waiting on dependency" });
  assert.equal(run.result, null);
  assert.equal(run.state.decisions.at(-1)?.decision_type, "no_action");
});
