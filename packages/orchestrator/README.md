# @noxund/orchestrator

The **multi-agent orchestration control plane** for NOXUND.

It turns the Product Orchestrator from *"writes a decision as free text in the terminal,
a human forwards it manually"* into *"emits a structured decision that is validated,
routed to the right agent automatically, executed, and folded back into central state —
with the terminal reduced to a log/observation layer."*

This package is the **executable counterpart** of the markdown agent contracts in
[`docs/agents/`](../../docs/agents). The docs define *who each agent is and what it may do*;
this package makes the **delegation loop run**.

---

## The flow

```txt
Product Orchestrator
   ↓  emits
Structured Decision            (decision-schema.ts)   ← JSON, not free text
   ↓
Decision Validator             (decision-validator.ts) ← is it valid & safe?
   ↓
Task Dispatcher                (dispatcher.ts)         ← routing + human-approval gate
   ↓
Agent Registry                 (agent-registry.ts)     ← only registered agents
   ↓
Specialized Agent              (agents/*.ts)           ← executes
   ↓  returns
AgentResult                    (result-schema.ts)      ← standardized envelope
   ↓
Project State Update           (project-state.ts)      ← central, durable memory
   ↓
Product Orchestrator           (uses result.next_recommendation to decide again)
```

Everything is logged as JSONL (`logger.ts`). The terminal only observes.

---

## Architecture

```txt
packages/orchestrator/
  src/
    core/
      task-schema.ts        TaskCommand  + structural validation + factory
      result-schema.ts      AgentResult  + status union + constructors
      decision-schema.ts    OrchestratorDecision (delegate / approve / escalate / no_action)
      safety.ts             human-approval policy (sensitive + destructive detection)
      agent-registry.ts     allow-list of agents; blocks unknown agents/actions
      decision-validator.ts validates a decision BEFORE anything runs
      dispatcher.ts         routes a task, enforces the approval gate, captures the result
      project-state.ts      pure reducers + JSON-file store (central state)
      logger.ts             structured JSONL logging (file + console + in-memory sinks)
      orchestrator.ts       the central authority: run() → validate → dispatch → update → log
      ids.ts                id / timestamp helpers
    agents/
      base-agent.ts         Agent contract + defineAgent() + planningHandler()
      product-agent.ts  database-agent.ts  backend-agent.ts  frontend-agent.ts
      data-agent.ts     security-agent.ts  qa-agent.ts       devops-agent.ts
      marketing-agent.ts documentation-agent.ts
      index.ts              the canonical NOXUND agent set + default registry
    index.ts                public API + bootstrap()
  examples/delegate-task.ts runnable end-to-end demonstration
  tests/                     node:test suites (zero dependencies)
```

**Design choices (and why):**

- **Zero runtime dependencies.** A control plane that gates destructive operations should
  have the smallest possible supply-chain surface. The project's own rule
  (`global-agent-rules.md` → *"não instalar dependências"*) is respected: nothing is added
  to run this. Validation is bespoke and explicit rather than delegated to a schema library.
- **Runs as real TypeScript with no build step.** Node ≥ 22.6 strips types natively, matching
  the repo convention (`packages/shared` is also consumed as `.ts` source). `pnpm typecheck`
  runs `tsc --noEmit` for full type verification.
- **Defense in depth.** The validator *and* the dispatcher both check agent existence, action
  allow-listing and the safety gate. A dispatcher must be safe even if called directly.
- **The Orchestrator stays the authority.** The dispatcher only routes; agents only execute;
  the Orchestrator owns decisions and state.

---

## The contracts

### TaskCommand — what the Orchestrator delegates

```json
{
  "task_id": "task_042",
  "target_agent": "data_agent",
  "action": "define_scoring_methodology",
  "priority": "high",
  "payload": { "feature": "Type Beat Market Report" },
  "success_criteria": ["Definir cálculo conceitual do Score", "..."],
  "requires_human_approval": false,
  "reason": "A metodologia precisa ser definida antes do backend."
}
```

### AgentResult — what every agent returns

```json
{
  "task_id": "task_042",
  "agent": "data_agent",
  "status": "completed",
  "summary": "Scoring methodology drafted ...",
  "artifacts": [{ "type": "methodology", "path": "docs/agents/data-ai-pipeline-agent.md", "description": "..." }],
  "errors": [],
  "next_recommendation": { "target_agent": "backend_agent", "action": "create_api_contract", "reason": "..." }
}
```

`status ∈ { completed, failed, needs_review, blocked }`.

---

## Running it

> Requires **Node ≥ 22.6** (native TypeScript execution). The machine here runs Node 24.

```bash
# from the repo root
pnpm --filter @noxund/orchestrator demo        # full end-to-end demonstration
pnpm --filter @noxund/orchestrator test        # node:test suites
pnpm --filter @noxund/orchestrator typecheck   # tsc --noEmit (after pnpm install)

# or directly, from this package directory (no install, no build)
node examples/delegate-task.ts
node --test "tests/**/*.test.ts"
```

Runtime artifacts land in `./.runtime/` (gitignored): the state snapshot
(`project-state.json`) and the JSONL log (`orchestrator.jsonl`).

---

## Using it in code

```ts
import { bootstrap, delegateTask, createTaskCommand, createApproval } from "@noxund/orchestrator";

const { orchestrator } = bootstrap();

// 1. Delegate automatically — the Orchestrator routes to the right agent.
const run = await orchestrator.delegate({
  target_agent: "data_agent",
  action: "define_scoring_methodology",
  priority: "high",
  payload: { feature: "Type Beat Market Report" },
  success_criteria: ["Definir cálculo conceitual do Score"],
  reason: "Methodology before backend.",
});

run.result?.status;        // "completed"
run.next;                  // { target_agent: "backend_agent", action: "create_api_contract", ... }
orchestrator.getState();   // central project state, updated

// 2. A sensitive task is auto-gated until a human approves.
await orchestrator.delegate({
  target_agent: "database_agent", action: "run_migration",
  payload: { migration: "add_report_snapshots" },
  success_criteria: ["apply"], reason: "schema",
}); // → status "needs_review" (not executed)

await orchestrator.delegate(
  { target_agent: "database_agent", action: "run_migration", payload: { migration: "add_report_snapshots" },
    success_criteria: ["apply"], reason: "schema" },
  { approval: createApproval("product-lead@noxund", "Reviewed; safe to apply.") },
); // → executes
```

---

## Human-approval gate (security)

Tasks are **never auto-executed** when the safety policy (`safety.ts`) flags them. A task is
gated when *any* of the following holds, and then requires an explicit `Approval` to run:

- `requires_human_approval: true` is set on the task;
- the **action** is one of the sensitive operations:
  `delete_files`, `remove_directory`, `overwrite_file`, `modify_env`, `configure_env`,
  `install_dependency`, `change_db_schema`, `run_migration`, `run_destructive_migration`,
  `git_push`, `deploy`, `change_core_architecture`, `run_shell_command`;
- the **payload** matches a destructive pattern (`rm -rf`, `DROP`/`TRUNCATE`, `DELETE` without
  `WHERE`, `--force`, `git push`, `deploy`, `.env`, dependency installs, migrations, overwrite/wipe).

When gated, the dispatcher returns:

```json
{ "status": "needs_review", "summary": "Esta tarefa exige aprovação humana antes da execução." }
```

---

## Scope honesty (what the agents do *not* do yet)

The specialized agents here are **foundation executors**: they validate the action, produce a
structured plan/handoff artifact, and return a well-formed `AgentResult`. They deliberately do
**not** perform real product work yet (no schema is written, no report number is computed). This
honors two locked non-negotiables:

- **gen-AI never produces numbers** — Score / Velocity / Signals / Competition / Example stay in
  deterministic code; this layer only routes and records;
- **minimum necessary** — no tables, services or dependencies beyond the orchestration mechanism.

Real executors are wired in later, agent by agent, **behind this same contract** — the loop does
not change when an agent graduates from "plan" to "do".
