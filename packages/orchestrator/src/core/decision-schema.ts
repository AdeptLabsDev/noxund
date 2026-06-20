// OrchestratorDecision — the structured output that REPLACES free-form terminal
// text as the Orchestrator's primary signal. A decision is a discriminated union:
// the Orchestrator either delegates a task, asks for human approval, escalates an
// OPEN DECISION, or explicitly does nothing. Every branch is auditable.

import type { TaskCommand } from "./task-schema.ts";

export type DecisionType =
  | "delegate_task"
  | "request_human_approval"
  | "escalate"
  | "no_action";

export const DECISION_TYPES: readonly DecisionType[] = [
  "delegate_task",
  "request_human_approval",
  "escalate",
  "no_action",
];

/** Route a fully-specified task to its target agent. */
export interface DelegateTaskDecision {
  decision_type: "delegate_task";
  task: TaskCommand;
}

/** Explicitly request a human gate before the (already-formed) task may run. */
export interface RequestHumanApprovalDecision {
  decision_type: "request_human_approval";
  task: TaskCommand;
  reason: string;
}

/** Stop and surface an OPEN DECISION to the Product Lead (per global-agent-rules). */
export interface EscalateDecision {
  decision_type: "escalate";
  reason: string;
  open_decision: string;
  references?: string[];
}

/** Deliberate no-op (e.g. waiting on a dependency). Recorded for traceability. */
export interface NoActionDecision {
  decision_type: "no_action";
  reason: string;
}

export type OrchestratorDecision =
  | DelegateTaskDecision
  | RequestHumanApprovalDecision
  | EscalateDecision
  | NoActionDecision;

export function isDecisionType(value: unknown): value is DecisionType {
  return typeof value === "string" && (DECISION_TYPES as readonly string[]).includes(value);
}

export function delegateTask(task: TaskCommand): DelegateTaskDecision {
  return { decision_type: "delegate_task", task };
}

export function requestHumanApproval(
  task: TaskCommand,
  reason: string,
): RequestHumanApprovalDecision {
  return { decision_type: "request_human_approval", task, reason };
}

export function escalate(
  open_decision: string,
  reason: string,
  references?: string[],
): EscalateDecision {
  return { decision_type: "escalate", open_decision, reason, references };
}

export function noAction(reason: string): NoActionDecision {
  return { decision_type: "no_action", reason };
}
