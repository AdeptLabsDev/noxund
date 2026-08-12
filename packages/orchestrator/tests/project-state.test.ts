import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, existsSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  initialState,
  withPendingTask,
  withCompletedTask,
  withBlockedTask,
  withResult,
  withDecision,
  decisionEntry,
  createStateStore,
  createConsumptionLedger,
} from "../src/core/project-state.ts";
import { result } from "../src/core/result-schema.ts";

test("a task moves cleanly between pending → completed (no duplicates)", () => {
  let s = initialState();
  s = withPendingTask(s, "t1");
  assert.deepEqual(s.pending_tasks, ["t1"]);
  s = withCompletedTask(s, "t1");
  assert.deepEqual(s.completed_tasks, ["t1"]);
  assert.deepEqual(s.pending_tasks, []);
});

test("blocking a completed task removes it from completed", () => {
  let s = initialState();
  s = withCompletedTask(s, "t1");
  s = withBlockedTask(s, "t1");
  assert.deepEqual(s.blocked_tasks, ["t1"]);
  assert.deepEqual(s.completed_tasks, []);
});

test("reducers are immutable (input untouched)", () => {
  const s0 = initialState();
  const s1 = withPendingTask(s0, "t1");
  assert.notEqual(s0, s1);
  assert.deepEqual(s0.pending_tasks, []);
});

test("withResult bounds the history to max", () => {
  let s = initialState();
  for (let i = 0; i < 30; i++) {
    s = withResult(s, result.completed({ task_id: `t${i}`, agent: "data_agent", summary: "ok" }), 5);
  }
  assert.equal(s.last_agent_results.length, 5);
  assert.equal(s.last_agent_results.at(-1)?.task_id, "t29");
});

test("decisions are appended with id + timestamp", () => {
  let s = initialState();
  s = withDecision(s, decisionEntry({ decision_type: "delegate_task", summary: "x", task_id: "t1" }));
  assert.equal(s.decisions.length, 1);
  assert.match(s.decisions[0]!.id, /^dec_/);
  assert.ok(Date.parse(s.decisions[0]!.ts) > 0);
});

test("store persists and reloads from disk", () => {
  const dir = mkdtempSync(join(tmpdir(), "noxund-state-"));
  const filePath = join(dir, "state.json");
  try {
    const store = createStateStore({ filePath });
    store.update((s) => withCompletedTask(s, "t1"));
    store.save();
    assert.ok(existsSync(filePath));

    const reloaded = createStateStore({ filePath });
    assert.deepEqual(reloaded.getState().completed_tasks, ["t1"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// ── Consumption ledger (single-use, durable write-through) ─────────────────────

test("ledger tryConsume: first consume true, replay false (single-use)", () => {
  const ledger = createConsumptionLedger(); // in-memory
  assert.equal(ledger.tryConsume("appr_1"), true);
  assert.equal(ledger.tryConsume("appr_1"), false);
  assert.equal(ledger.tryConsume("appr_2"), true);
  assert.equal(ledger.size(), 2);
  assert.equal(ledger.isConsumed("appr_1"), true);
  assert.equal(ledger.isConsumed("appr_3"), false);
});

test("ledger is durable write-through: consumed id survives reload (restart model)", () => {
  const dir = mkdtempSync(join(tmpdir(), "noxund-ledger-"));
  const filePath = join(dir, "ledger.json");
  try {
    const l1 = createConsumptionLedger({ filePath });
    assert.equal(l1.tryConsume("appr_x"), true);
    // File exists BEFORE any explicit save (write-through, not deferred).
    assert.ok(existsSync(filePath));

    // New ledger over the same file (simulated restart) still rejects the replay.
    const l2 = createConsumptionLedger({ filePath });
    assert.equal(l2.isConsumed("appr_x"), true);
    assert.equal(l2.tryConsume("appr_x"), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("ledger fails loudly on a corrupt file (no silent replay window)", () => {
  const dir = mkdtempSync(join(tmpdir(), "noxund-ledger-"));
  const filePath = join(dir, "ledger.json");
  try {
    writeFileSync(filePath, "{ not json", "utf8");
    assert.throws(() => createConsumptionLedger({ filePath }), /corrupt|unreadable/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
