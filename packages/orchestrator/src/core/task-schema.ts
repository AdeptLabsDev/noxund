// TaskCommand — the structured, delegable unit of work the Product Orchestrator
// emits instead of free-form terminal text. This module owns the *shape* of a
// task and its structural validation. Semantic validation (does the agent exist?
// is the action allowed? is it sensitive?) lives in decision-validator.ts so that
// this schema stays dependency-free and reusable.

import { newTaskId } from "./ids.ts";

export type Priority = "low" | "medium" | "high" | "critical";

export const PRIORITIES: readonly Priority[] = ["low", "medium", "high", "critical"];

export function isPriority(value: unknown): value is Priority {
  return typeof value === "string" && (PRIORITIES as readonly string[]).includes(value);
}

/**
 * The canonical command the Orchestrator delegates to an agent.
 * Every field is required by contract — partial tasks are rejected by the validator.
 */
export interface TaskCommand {
  /** Unique id, e.g. `task_001`. */
  task_id: string;
  /** Registered agent id this task is routed to, e.g. `data_agent`. */
  target_agent: string;
  /** Verb the target agent must support, e.g. `define_scoring_methodology`. */
  action: string;
  priority: Priority;
  /** Action-specific input. Always an object (may be empty). */
  payload: Record<string, unknown>;
  /** Objective, checkable conditions for success. Must be non-empty. */
  success_criteria: string[];
  /** When true (or when the safety policy flags it), execution is gated on a human. */
  requires_human_approval: boolean;
  /** Why the Orchestrator made this decision. Forces explicit reasoning. */
  reason: string;
}

export interface CreateTaskInput {
  task_id?: string;
  target_agent: string;
  action: string;
  priority?: Priority;
  payload?: Record<string, unknown>;
  success_criteria?: string[];
  requires_human_approval?: boolean;
  reason: string;
}

/** Build a fully-formed TaskCommand from partial input, filling safe defaults. */
export function createTaskCommand(input: CreateTaskInput): TaskCommand {
  return {
    task_id: input.task_id ?? newTaskId(),
    target_agent: input.target_agent,
    action: input.action,
    priority: input.priority ?? "medium",
    payload: input.payload ?? {},
    success_criteria: input.success_criteria ?? [],
    // Conservative default: opt-in to autonomy, never assume it.
    requires_human_approval: input.requires_human_approval ?? false,
    reason: input.reason,
  };
}

export interface ShapeIssue {
  field: string;
  message: string;
}

export interface ShapeResult {
  ok: boolean;
  issues: ShapeIssue[];
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * Structural validation only: confirms the JSON has every required field with the
 * right primitive type. This is the "is the JSON valid?" gate. It does NOT decide
 * whether the agent/action are real — that is the validator's job.
 */
export function validateTaskShape(value: unknown): ShapeResult {
  const issues: ShapeIssue[] = [];

  if (!isPlainObject(value)) {
    return { ok: false, issues: [{ field: "<root>", message: "task must be a JSON object" }] };
  }

  if (!isNonEmptyString(value.task_id)) {
    issues.push({ field: "task_id", message: "required non-empty string" });
  }
  if (!isNonEmptyString(value.target_agent)) {
    issues.push({ field: "target_agent", message: "required non-empty string" });
  }
  if (!isNonEmptyString(value.action)) {
    issues.push({ field: "action", message: "required non-empty string" });
  }
  if (!isPriority(value.priority)) {
    issues.push({
      field: "priority",
      message: `must be one of ${PRIORITIES.join(", ")}`,
    });
  }
  if (!isPlainObject(value.payload)) {
    issues.push({ field: "payload", message: "must be an object (may be empty)" });
  }
  if (!Array.isArray(value.success_criteria)) {
    issues.push({ field: "success_criteria", message: "must be an array of strings" });
  } else if (value.success_criteria.length === 0) {
    issues.push({ field: "success_criteria", message: "must contain at least one criterion" });
  } else if (!value.success_criteria.every((c) => typeof c === "string")) {
    issues.push({ field: "success_criteria", message: "every criterion must be a string" });
  }
  if (typeof value.requires_human_approval !== "boolean") {
    issues.push({ field: "requires_human_approval", message: "must be a boolean" });
  }
  if (!isNonEmptyString(value.reason)) {
    issues.push({ field: "reason", message: "required non-empty string explaining the decision" });
  }

  return { ok: issues.length === 0, issues };
}
