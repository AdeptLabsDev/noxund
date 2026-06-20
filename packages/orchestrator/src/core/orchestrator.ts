// Product Orchestrator — the central authority. It does NOT route or execute work
// itself; it (1) emits/accepts a structured decision, (2) validates it, (3) hands it
// to the dispatcher, (4) folds the AgentResult back into Project State, and (5) logs
// every step. The terminal only observes; this object is the operational center.
//
// Decision-making policy (which task to create) is intentionally pluggable: in this
// foundation the Orchestrator executes decisions it is given (or builds via delegate()),
// because choosing the next product step is a reasoning concern layered on top of this
// mechanism. What is implemented here is the *deterministic machinery* that makes a
// structured decision actually happen — safely, traceably, and with state.

import type { AgentRegistry } from "./agent-registry.ts";
import type { Dispatcher } from "./dispatcher.ts";
import { createDispatcher } from "./dispatcher.ts";
import type { DecisionValidation } from "./decision-validator.ts";
import { validateDecision } from "./decision-validator.ts";
import type {
  OrchestratorDecision,
  DelegateTaskDecision,
  RequestHumanApprovalDecision,
  EscalateDecision,
  NoActionDecision,
} from "./decision-schema.ts";
import { delegateTask } from "./decision-schema.ts";
import type { CreateTaskInput } from "./task-schema.ts";
import { createTaskCommand } from "./task-schema.ts";
import type { AgentResult, NextRecommendation } from "./result-schema.ts";
import type { Approval } from "./safety.ts";
import type { Logger } from "./logger.ts";
import { nullLogger } from "./logger.ts";
import type { ProjectState, ProjectStateStore } from "./project-state.ts";
import {
  decisionEntry,
  withBlockedTask,
  withCompletedTask,
  withDecision,
  withPendingTask,
  withArtifacts,
  withResult,
} from "./project-state.ts";

export interface RunResult {
  decision: OrchestratorDecision;
  validation: DecisionValidation;
  /** The agent's envelope, or null when nothing was dispatched. */
  result: AgentResult | null;
  /** True when the task was held for human approval and not executed. */
  gated: boolean;
  /** Snapshot of project state AFTER this run. */
  state: ProjectState;
  /** The next step the Orchestrator should consider, if any. */
  next: NextRecommendation | null;
}

export interface Orchestrator {
  /** Validate + (if applicable) dispatch a structured decision, updating state + logs. */
  run(decision: OrchestratorDecision, options?: { approval?: Approval }): Promise<RunResult>;
  /** Convenience: build a delegate_task decision from input, then run it. */
  delegate(input: CreateTaskInput, options?: { approval?: Approval }): Promise<RunResult>;
  getState(): ProjectState;
}

export interface OrchestratorConfig {
  registry: AgentRegistry;
  state: ProjectStateStore;
  logger?: Logger;
  /** Inject a dispatcher (e.g. for tests); defaults to one over the registry. */
  dispatcher?: Dispatcher;
}

export function createOrchestrator(config: OrchestratorConfig): Orchestrator {
  const logger = config.logger ?? nullLogger();
  const { registry, state } = config;
  const dispatcher = config.dispatcher ?? createDispatcher({ registry, logger });

  function snapshot(): ProjectState {
    state.save();
    return state.getState();
  }

  async function run(
    decision: OrchestratorDecision,
    options: { approval?: Approval } = {},
  ): Promise<RunResult> {
    logger.info("decision.received", { decision_type: (decision as { decision_type?: string }).decision_type });

    // 1. Validate before anything acts.
    const validation = validateDecision(decision, registry);
    if (!validation.ok) {
      logger.error("decision.invalid", {
        errors: validation.errors.map((e) => `${e.code}:${e.message}`),
      });
      // Record the rejected decision for traceability; block the task if we have an id.
      const taskId = validation.task?.task_id;
      state.update((s) =>
        withDecision(s, decisionEntry({
          decision_type: validation.decision_type ?? "no_action",
          summary: `Rejected by validator: ${validation.errors.map((e) => e.code).join(", ")}`,
          task_id: taskId,
          reason: validation.errors.map((e) => e.message).join("; "),
        })),
      );
      if (taskId) state.update((s) => withBlockedTask(s, taskId));
      return { decision, validation, result: null, gated: false, state: snapshot(), next: null };
    }

    // 2. Branch by decision type.
    switch (decision.decision_type) {
      case "no_action":
        return handleNoAction(decision, validation);
      case "escalate":
        return handleEscalate(decision, validation);
      case "request_human_approval":
        return handleRequestApproval(decision, validation, options.approval);
      case "delegate_task":
        return handleDelegate(decision, validation, options.approval);
      default: {
        // Exhaustiveness guard.
        const _never: never = decision;
        throw new Error(`Unhandled decision: ${JSON.stringify(_never)}`);
      }
    }
  }

  function handleNoAction(decision: NoActionDecision, validation: DecisionValidation): RunResult {
    state.update((s) =>
      withDecision(s, decisionEntry({
        decision_type: "no_action",
        summary: "No action taken.",
        reason: decision.reason,
      })),
    );
    logger.info("decision.no_action", { reason: decision.reason });
    return { decision, validation, result: null, gated: false, state: snapshot(), next: null };
  }

  function handleEscalate(decision: EscalateDecision, validation: DecisionValidation): RunResult {
    state.update((s) =>
      withDecision(s, decisionEntry({
        decision_type: "escalate",
        summary: `OPEN DECISION: ${decision.open_decision}`,
        reason: decision.reason,
        references: decision.references,
      })),
    );
    logger.warn("decision.escalated", {
      open_decision: decision.open_decision,
      reason: decision.reason,
    });
    return {
      decision,
      validation,
      result: null,
      gated: true,
      state: snapshot(),
      next: { reason: `OPEN DECISION awaiting Product Lead: ${decision.open_decision}` },
    };
  }

  function handleRequestApproval(
    decision: RequestHumanApprovalDecision,
    validation: DecisionValidation,
    approval: Approval | undefined,
  ): Promise<RunResult> {
    // request_human_approval is delegate_task with the gate forced on.
    return handleDelegate(delegateTask(decision.task), validation, approval, decision.reason);
  }

  async function handleDelegate(
    decision: DelegateTaskDecision,
    validation: DecisionValidation,
    approval: Approval | undefined,
    approvalReason?: string,
  ): Promise<RunResult> {
    const task = decision.task;

    // Record the decision + mark the task pending BEFORE dispatch.
    state.update((s) =>
      withDecision(s, decisionEntry({
        decision_type: "delegate_task",
        summary: `Delegate "${task.action}" → ${task.target_agent}`,
        task_id: task.task_id,
        reason: approvalReason ? `${task.reason} (${approvalReason})` : task.reason,
      })),
    );
    state.update((s) => withPendingTask(s, task.task_id));

    // Dispatch (routing + safety gate + execution).
    const outcome = await dispatcher.dispatch(task, { approval, logger });
    const res = outcome.result;

    // Fold the result back into state by status.
    state.update((s) => withResult(s, res));
    state.update((s) => withArtifacts(s, res.artifacts));
    switch (res.status) {
      case "completed":
        state.update((s) => withCompletedTask(s, task.task_id));
        break;
      case "needs_review":
      case "blocked":
      case "failed":
        state.update((s) => withBlockedTask(s, task.task_id));
        break;
    }

    logger.info("result.recorded", {
      task_id: task.task_id,
      agent: res.agent,
      status: res.status,
      gated: outcome.gated,
    });

    return {
      decision,
      validation,
      result: res,
      gated: outcome.gated,
      state: snapshot(),
      next: res.next_recommendation,
    };
  }

  async function delegate(
    input: CreateTaskInput,
    options: { approval?: Approval } = {},
  ): Promise<RunResult> {
    const task = createTaskCommand(input);
    return run(delegateTask(task), options);
  }

  return {
    run,
    delegate,
    getState() {
      return state.getState();
    },
  };
}
