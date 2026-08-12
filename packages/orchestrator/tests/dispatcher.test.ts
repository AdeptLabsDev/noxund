import { test } from "node:test";
import assert from "node:assert/strict";
import { createDispatcher, HUMAN_APPROVAL_SUMMARY } from "../src/core/dispatcher.ts";
import { createRegistry } from "../src/core/agent-registry.ts";
import { createDefaultRegistry } from "../src/agents/index.ts";
import { defineAgent } from "../src/agents/base-agent.ts";
import { createTaskCommand, type TaskCommand } from "../src/core/task-schema.ts";
import { mintApproval, type ApprovalRecord } from "../src/core/safety.ts";
import { createConsumptionLedger } from "../src/core/project-state.ts";
import { result } from "../src/core/result-schema.ts";

const registry = createDefaultRegistry();
const T0 = new Date("2026-01-01T00:00:00.000Z");
const MIN = 60_000;

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

function migrationTask(overrides: Partial<Parameters<typeof createTaskCommand>[0]> = {}) {
  return createTaskCommand({
    task_id: "task_mig",
    target_agent: "database_agent",
    action: "run_migration",
    payload: { migration: "m" },
    success_criteria: ["apply"],
    reason: "schema",
    ...overrides,
  });
}

function approvalFor(t: TaskCommand, nonce = "n1", ttl = 10 * MIN, now = T0): ApprovalRecord {
  return mintApproval(t, { approved_by: "lead@noxund", ttl_ms: ttl, now, nonce });
}

/** Dispatcher wired with a fresh in-memory ledger and a fixed clock. */
function dispatcherAt(now = T0, reg = registry) {
  const ledger = createConsumptionLedger();
  const d = createDispatcher({ registry: reg, ledger, clock: () => now });
  return { d, ledger };
}

// ── Baseline routing (unchanged behavior for non-sensitive tasks) ──────────────

test("happy path routes to the agent and returns completed", async () => {
  const { d } = dispatcherAt();
  const out = await d.dispatch(task());
  assert.equal(out.result.status, "completed");
  assert.equal(out.result.agent, "data_agent");
  assert.equal(out.gated, false);
});

test("unknown agent yields a failed result, not a throw", async () => {
  const { d } = dispatcherAt();
  const out = await d.dispatch(task({ target_agent: "ghost_agent" }));
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "UNKNOWN_AGENT");
});

test("disallowed action yields a failed result", async () => {
  const { d } = dispatcherAt();
  const out = await d.dispatch(task({ action: "deploy" }));
  assert.equal(out.result.status, "failed");
  assert.equal(out.result.errors[0]?.code, "ACTION_NOT_ALLOWED");
});

// ── Approval gate (command-bound) ──────────────────────────────────────────────

test("sensitive task without approval is gated to needs_review", async () => {
  const { d } = dispatcherAt();
  const out = await d.dispatch(migrationTask());
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.summary, HUMAN_APPROVAL_SUMMARY);
  assert.equal(out.gated, true);
});

test("sensitive task with a matching command-bound approval executes", async () => {
  const { d } = dispatcherAt();
  const t = migrationTask();
  const out = await d.dispatch(t, { approval: approvalFor(t) });
  assert.equal(out.result.status, "completed");
  assert.equal(out.gated, false);
});

test("legacy/unbound approval-shaped object CANNOT bypass the gate", async () => {
  const { d } = dispatcherAt();
  const t = migrationTask();
  // Old truthiness token: only approved_by/granted_at, no command_identity.
  const legacy = { approved_by: "lead@noxund", granted_at: T0.toISOString() } as unknown as ApprovalRecord;
  const out = await d.dispatch(t, { approval: legacy });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.gated, true);
  assert.equal(out.result.errors[0]?.code, "UNBOUND_OR_MALFORMED_APPROVAL");
});

// ── Command binding: every field mutation invalidates the approval ─────────────

test("payload mutation after approval is rejected (live recompute mismatch)", async () => {
  const { d } = dispatcherAt();
  const approved = migrationTask({ payload: { migration: "m" } });
  const ap = approvalFor(approved);
  // Mutate the payload of the command actually dispatched.
  const mutated = migrationTask({ payload: { migration: "m-EVIL" } });
  const out = await d.dispatch(mutated, { approval: ap });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.errors[0]?.code, "COMMAND_IDENTITY_MISMATCH");
});

test("action mutation after approval is rejected", async () => {
  // Build an agent that allows two sensitive actions so routing itself succeeds.
  const twoAction = defineAgent({
    id: "db2_agent",
    name: "DB2",
    description: "two sensitive actions",
    owns: "nothing",
    handlers: {
      run_migration: (t) => result.completed({ task_id: t.task_id, agent: "db2_agent", summary: "ok" }),
      change_db_schema: (t) => result.completed({ task_id: t.task_id, agent: "db2_agent", summary: "ok" }),
    },
  });
  const reg = createRegistry([twoAction]);
  const { d } = dispatcherAt(T0, reg);
  const approved = createTaskCommand({
    task_id: "task_x",
    target_agent: "db2_agent",
    action: "run_migration",
    payload: { migration: "m", change: "c" },
    success_criteria: ["c"],
    reason: "r",
  });
  const ap = approvalFor(approved);
  const mutated = { ...approved, action: "change_db_schema" };
  const out = await d.dispatch(mutated, { approval: ap });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.errors[0]?.code, "COMMAND_IDENTITY_MISMATCH");
});

test("task_id mutation after approval is rejected", async () => {
  const { d } = dispatcherAt();
  const approved = migrationTask({ task_id: "task_a" });
  const ap = approvalFor(approved);
  const mutated = migrationTask({ task_id: "task_b" });
  const out = await d.dispatch(mutated, { approval: ap });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.errors[0]?.code, "COMMAND_IDENTITY_MISMATCH");
});

test("target_agent mutation after approval is rejected", async () => {
  // database_agent and another agent both accept run_migration path is not needed:
  // we only need identity to differ; the approval was minted for database_agent.
  const other = defineAgent({
    id: "database_agent_clone",
    name: "Clone",
    description: "clone",
    owns: "nothing",
    handlers: {
      run_migration: (t) => result.completed({ task_id: t.task_id, agent: "database_agent_clone", summary: "ok" }),
    },
  });
  const reg = createRegistry([other]);
  const { d } = dispatcherAt(T0, reg);
  const approved = migrationTask({ target_agent: "database_agent" });
  const ap = approvalFor(approved);
  const mutated = migrationTask({ target_agent: "database_agent_clone" });
  const out = await d.dispatch(mutated, { approval: ap });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.errors[0]?.code, "COMMAND_IDENTITY_MISMATCH");
});

// ── Expiry via injected gate clock ─────────────────────────────────────────────

test("approval expiry is controlled by the injected gate clock", async () => {
  const t = migrationTask();
  const ap = approvalFor(t, "n1", 10 * MIN, T0);
  const expires = Date.parse(ap.expires_at);

  // before boundary → executes
  {
    const { d } = dispatcherAt(new Date(expires - 1));
    const out = await d.dispatch(t, { approval: ap });
    assert.equal(out.result.status, "completed");
  }
  // exact boundary → EXPIRED, needs_review, no execution
  {
    const { d } = dispatcherAt(new Date(expires));
    const out = await d.dispatch(t, { approval: ap });
    assert.equal(out.result.status, "needs_review");
    assert.equal(out.result.errors[0]?.code, "APPROVAL_EXPIRED");
  }
  // after boundary → EXPIRED
  {
    const { d } = dispatcherAt(new Date(expires + 5 * MIN));
    const out = await d.dispatch(t, { approval: ap });
    assert.equal(out.result.status, "needs_review");
    assert.equal(out.result.errors[0]?.code, "APPROVAL_EXPIRED");
  }
});

// ── Single-use consumption + replay ────────────────────────────────────────────

test("single-use: first consume executes, replay is rejected, handler runs at most once", async () => {
  const spy = { calls: 0 };
  const spyAgent = defineAgent({
    id: "spy_migrator",
    name: "Spy",
    description: "counts handler calls",
    owns: "nothing",
    handlers: {
      run_migration: (t) => {
        spy.calls += 1;
        return result.completed({ task_id: t.task_id, agent: "spy_migrator", summary: "ok" });
      },
    },
  });
  const reg = createRegistry([spyAgent]);
  const { d } = dispatcherAt(T0, reg);
  const t = migrationTask({ target_agent: "spy_migrator" });
  const ap = approvalFor(t);

  const first = await d.dispatch(t, { approval: ap });
  assert.equal(first.result.status, "completed");

  const replay = await d.dispatch(t, { approval: ap });
  assert.equal(replay.result.status, "needs_review");
  assert.equal(replay.result.errors[0]?.code, "APPROVAL_ALREADY_CONSUMED");

  assert.equal(spy.calls, 1);
});

test("consumed approval survives a store 'restart' (durable ledger reload)", async () => {
  const { mkdtempSync, rmSync } = await import("node:fs");
  const { tmpdir } = await import("node:os");
  const { join } = await import("node:path");
  const dir = mkdtempSync(join(tmpdir(), "noxund-ledger-"));
  const ledgerPath = join(dir, "ledger.json");
  try {
    const t = migrationTask();
    const ap = approvalFor(t);

    // First process: durable ledger, consumes the approval.
    const ledger1 = createConsumptionLedger({ filePath: ledgerPath });
    const d1 = createDispatcher({ registry, ledger: ledger1, clock: () => T0 });
    const out1 = await d1.dispatch(t, { approval: ap });
    assert.equal(out1.result.status, "completed");

    // Simulate restart: brand-new ledger reading the SAME file.
    const ledger2 = createConsumptionLedger({ filePath: ledgerPath });
    assert.equal(ledger2.isConsumed(ap.approval_id), true);
    const d2 = createDispatcher({ registry, ledger: ledger2, clock: () => T0 });
    const out2 = await d2.dispatch(t, { approval: ap });
    assert.equal(out2.result.status, "needs_review");
    assert.equal(out2.result.errors[0]?.code, "APPROVAL_ALREADY_CONSUMED");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("concurrent duplicate dispatch: at most one reaches the handler (single-process atomicity)", async () => {
  const spy = { calls: 0 };
  const spyAgent = defineAgent({
    id: "spy_migrator2",
    name: "Spy2",
    description: "counts handler calls",
    owns: "nothing",
    handlers: {
      run_migration: async (t) => {
        spy.calls += 1;
        // Yield to the event loop to interleave the two dispatches.
        await Promise.resolve();
        return result.completed({ task_id: t.task_id, agent: "spy_migrator2", summary: "ok" });
      },
    },
  });
  const reg = createRegistry([spyAgent]);
  const { d } = dispatcherAt(T0, reg);
  const t = migrationTask({ target_agent: "spy_migrator2" });
  const ap = approvalFor(t);

  const [a, b] = await Promise.all([
    d.dispatch(t, { approval: ap }),
    d.dispatch(t, { approval: ap }),
  ]);

  const statuses = [a.result.status, b.result.status].sort();
  assert.deepEqual(statuses, ["completed", "needs_review"]);
  assert.equal(spy.calls, 1);
});

test("no ledger configured → sensitive approved task fails closed (no execution)", async () => {
  const spy = { calls: 0 };
  const spyAgent = defineAgent({
    id: "spy_migrator3",
    name: "Spy3",
    description: "counts handler calls",
    owns: "nothing",
    handlers: {
      run_migration: (t) => {
        spy.calls += 1;
        return result.completed({ task_id: t.task_id, agent: "spy_migrator3", summary: "ok" });
      },
    },
  });
  const reg = createRegistry([spyAgent]);
  const d = createDispatcher({ registry: reg, clock: () => T0 }); // NO ledger
  const t = migrationTask({ target_agent: "spy_migrator3" });
  const ap = approvalFor(t);
  const out = await d.dispatch(t, { approval: ap });
  assert.equal(out.result.status, "needs_review");
  assert.equal(out.result.errors[0]?.code, "NO_CONSUMPTION_LEDGER");
  assert.equal(spy.calls, 0);
});

// ── Gate ordering: handler invocation count = 0 on EVERY rejection path ─────────

test("gate ordering: handler is NEVER invoked on any rejection path (spy)", async () => {
  const spy = { calls: 0 };
  const spyAgent = defineAgent({
    id: "gate_spy",
    name: "GateSpy",
    description: "counts handler calls",
    owns: "nothing",
    handlers: {
      run_migration: (t) => {
        spy.calls += 1;
        return result.completed({ task_id: t.task_id, agent: "gate_spy", summary: "ok" });
      },
    },
  });
  const reg = createRegistry([spyAgent]);
  const t = migrationTask({ target_agent: "gate_spy" });

  // no approval
  {
    const { d } = dispatcherAt(T0, reg);
    await d.dispatch(t);
  }
  // legacy/unbound approval
  {
    const { d } = dispatcherAt(T0, reg);
    await d.dispatch(t, { approval: { approved_by: "x", granted_at: T0.toISOString() } as unknown as ApprovalRecord });
  }
  // identity mismatch
  {
    const { d } = dispatcherAt(T0, reg);
    const ap = approvalFor(migrationTask({ target_agent: "gate_spy", payload: { migration: "OTHER" } }));
    await d.dispatch(t, { approval: ap });
  }
  // expired
  {
    const ap = approvalFor(t);
    const { d } = dispatcherAt(new Date(Date.parse(ap.expires_at) + MIN), reg);
    await d.dispatch(t, { approval: ap });
  }

  assert.equal(spy.calls, 0);
});

// ── Existing throw-containment + result-shape defense preserved ────────────────

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
  const { d } = dispatcherAt(T0, createRegistry([throwing]));
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
  const { d } = dispatcherAt(T0, createRegistry([bad]));
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
