// Runnable demonstration of the full automated flow:
//
//   Product Orchestrator → Structured Decision → Decision Validator →
//   Task Dispatcher → Agent Registry → Specialized Agent → AgentResult →
//   Project State Update → (back to) Product Orchestrator
//
// Run:  pnpm --filter @noxund/orchestrator demo
//   or:  node examples/delegate-task.ts   (from the package directory, Node >= 22.6)

import { rmSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import {
  bootstrap,
  delegateTask,
  createTaskCommand,
  createApproval,
  type RunResult,
} from "../src/index.ts";

const runtimeDir = join(import.meta.dirname, "..", ".runtime", "demo");
// Fresh, reproducible run.
if (existsSync(runtimeDir)) rmSync(runtimeDir, { recursive: true, force: true });

const { orchestrator, stateFile, logFile } = bootstrap({
  runtimeDir,
  console: false, // keep the demo output clean; the JSONL log is the observation layer
  phase: "planning",
});

function section(title: string): void {
  console.log("\n" + "─".repeat(74));
  console.log(title);
  console.log("─".repeat(74));
}

function show(label: string, value: unknown): void {
  console.log(`\n${label}:`);
  console.log(JSON.stringify(value, null, 2));
}

function summarize(run: RunResult): void {
  console.log(
    `→ status=${run.result?.status ?? "—"} gated=${run.gated} ` +
      `valid=${run.validation.ok}` +
      (run.next ? ` next=${run.next.target_agent ?? "?"}:${run.next.action ?? "?"}` : ""),
  );
}

async function main(): Promise<void> {
  // ── Scenario A: the canonical brief example, delegated automatically ──────────
  section("A. Orchestrator delegates a task automatically (data_agent)");
  const decisionA = delegateTask(
    createTaskCommand({
      task_id: "task_042",
      target_agent: "data_agent",
      action: "define_scoring_methodology",
      priority: "high",
      payload: {
        feature: "Type Beat Market Report",
        columns: ["Title", "Tag", "Score", "Signals", "Velocity", "Competition", "Example"],
      },
      success_criteria: [
        "Definir cálculo conceitual do Score",
        "Definir origem de Signals",
        "Definir cálculo de Velocity",
        "Definir regra de Competition",
        "Explicitar limitações metodológicas",
      ],
      requires_human_approval: false,
      reason:
        "A metodologia de dados precisa ser definida antes da implementação do backend.",
    }),
  );
  show("Structured decision emitted by the Orchestrator", decisionA);
  const runA = await orchestrator.run(decisionA);
  show("AgentResult returned (standardized)", runA.result);
  summarize(runA);

  // ── Scenario B: follow the agent's machine-readable recommendation ────────────
  section("B. Orchestrator follows the result's next_recommendation (backend_agent)");
  if (runA.next?.target_agent && runA.next.action) {
    const runB = await orchestrator.delegate({
      target_agent: runA.next.target_agent,
      action: runA.next.action,
      priority: runA.next.priority ?? "high",
      payload: { feature: "Type Beat Market Report" },
      success_criteria: ["Define request/response contract", "No number generated in API layer"],
      reason: "Chaining off the data_agent recommendation, fully automatically.",
    });
    show("AgentResult", runB.result);
    summarize(runB);
  }

  // ── Scenario C: a SENSITIVE task is auto-gated for human approval ─────────────
  section("C. Sensitive task WITHOUT approval → needs_review (auto-gated)");
  const runC = await orchestrator.delegate({
    task_id: "task_900",
    target_agent: "database_agent",
    action: "run_migration",
    priority: "critical",
    payload: { migration: "2026_06_add_report_snapshots" },
    success_criteria: ["Apply migration", "Preserve raw immutability"],
    reason: "Schema needs the report_snapshots table.",
  });
  show("AgentResult (gated)", runC.result);
  summarize(runC);

  // ── Scenario D: same task WITH explicit human approval → executes ─────────────
  section("D. Same sensitive task WITH human approval → executes");
  const runD = await orchestrator.delegate(
    {
      task_id: "task_900",
      target_agent: "database_agent",
      action: "run_migration",
      priority: "critical",
      payload: { migration: "2026_06_add_report_snapshots" },
      success_criteria: ["Apply migration", "Preserve raw immutability"],
      reason: "Schema needs the report_snapshots table.",
    },
    { approval: createApproval("product-lead@noxund", "Reviewed migration plan; safe to apply.") },
  );
  show("AgentResult (approved)", runD.result);
  summarize(runD);

  // ── Scenario E: an invalid decision is rejected BEFORE any execution ──────────
  section("E. Invalid decision (unknown action) → rejected by the validator");
  const runE = await orchestrator.delegate({
    target_agent: "frontend_agent",
    action: "delete_production_database", // not in the agent's allow-list
    priority: "high",
    payload: {},
    success_criteria: ["should never run"],
    reason: "Intentionally invalid to demonstrate the validation gate.",
  });
  show("Validation errors", runE.validation.errors);
  summarize(runE);

  // ── Final state + observability ───────────────────────────────────────────────
  section("Final Project State (the Orchestrator's central memory)");
  const state = orchestrator.getState();
  show("Project state", {
    project_id: state.project_id,
    current_phase: state.current_phase,
    completed_tasks: state.completed_tasks,
    pending_tasks: state.pending_tasks,
    blocked_tasks: state.blocked_tasks,
    decisions: state.decisions.length,
    artifacts: state.artifacts.length,
    last_agent_results: state.last_agent_results.length,
  });

  section("Observability (terminal is just a log view)");
  console.log(`State snapshot : ${stateFile}`);
  console.log(`Structured log : ${logFile}`);
  if (existsSync(logFile)) {
    const lines = readFileSync(logFile, "utf8").trim().split("\n");
    console.log(`\nLast ${Math.min(6, lines.length)} log records (JSONL):`);
    for (const line of lines.slice(-6)) console.log("  " + line);
  }
  console.log("");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
