// Decision Validator — the gate between "the Orchestrator decided" and "the system
// acts". It answers, before anything runs:
//   - is the JSON a valid decision?
//   - (for delegate_task) is the task shape valid?
//   - does the target agent exist?
//   - is the action allowed for that agent?
//   - is the minimal payload present?
//   - does it require human approval / is it destructive?
// It NEVER executes; it only judges.

import type { AgentRegistry } from "./agent-registry.ts";
import type { DecisionType } from "./decision-schema.ts";
import { isDecisionType } from "./decision-schema.ts";
import type { TaskCommand } from "./task-schema.ts";
import { validateTaskShape } from "./task-schema.ts";
import type { SensitivityAssessment } from "./safety.ts";
import { assessSensitivity } from "./safety.ts";

export interface ValidationIssue {
  code: string;
  message: string;
  field?: string;
  severity: "error" | "warning";
}

export interface DecisionValidation {
  ok: boolean;
  errors: ValidationIssue[];
  warnings: ValidationIssue[];
  decision_type?: DecisionType;
  /** Present and structurally valid only for delegate_task / request_human_approval. */
  task?: TaskCommand;
  /** Effective approval requirement (explicit flag OR safety policy). */
  requires_human_approval: boolean;
  sensitivity?: SensitivityAssessment;
}

/**
 * Minimal required payload keys per action. Absent actions impose no payload
 * requirement beyond "payload is an object". Kept intentionally small — the goal
 * is to catch obviously-incomplete delegations, not to model every action.
 */
const REQUIRED_PAYLOAD_KEYS: Readonly<Record<string, readonly string[]>> = {
  define_scoring_methodology: ["feature"],
  create_api_contract: ["feature"],
  build_report_table: ["columns"],
  run_migration: ["migration"],
  change_db_schema: ["change"],
  deploy: ["environment"],
};

function err(code: string, message: string, field?: string): ValidationIssue {
  return { code, message, field, severity: "error" };
}

function warn(code: string, message: string, field?: string): ValidationIssue {
  return { code, message, field, severity: "warning" };
}

export function validateDecision(
  decision: unknown,
  registry: AgentRegistry,
): DecisionValidation {
  const errors: ValidationIssue[] = [];
  const warnings: ValidationIssue[] = [];

  if (typeof decision !== "object" || decision === null) {
    return {
      ok: false,
      errors: [err("DECISION_NOT_OBJECT", "decision must be a JSON object")],
      warnings,
      requires_human_approval: false,
    };
  }

  const d = decision as Record<string, unknown>;
  const decisionType = d.decision_type;

  if (!isDecisionType(decisionType)) {
    return {
      ok: false,
      errors: [
        err(
          "UNKNOWN_DECISION_TYPE",
          `decision_type must be one of delegate_task, request_human_approval, escalate, no_action`,
          "decision_type",
        ),
      ],
      warnings,
      requires_human_approval: false,
    };
  }

  // Non-task decisions are valid as long as they carry a reason / open decision.
  if (decisionType === "no_action") {
    if (typeof d.reason !== "string" || d.reason.trim() === "") {
      errors.push(err("MISSING_REASON", "no_action requires a reason", "reason"));
    }
    return { ok: errors.length === 0, errors, warnings, decision_type: decisionType, requires_human_approval: false };
  }

  if (decisionType === "escalate") {
    if (typeof d.open_decision !== "string" || d.open_decision.trim() === "") {
      errors.push(err("MISSING_OPEN_DECISION", "escalate requires an open_decision", "open_decision"));
    }
    if (typeof d.reason !== "string" || d.reason.trim() === "") {
      errors.push(err("MISSING_REASON", "escalate requires a reason", "reason"));
    }
    // Escalation always lands on a human by definition.
    return {
      ok: errors.length === 0,
      errors,
      warnings,
      decision_type: decisionType,
      requires_human_approval: true,
    };
  }

  // From here: delegate_task | request_human_approval — both carry a task.
  const shape = validateTaskShape((d as { task?: unknown }).task);
  if (!shape.ok) {
    for (const issue of shape.issues) {
      errors.push(err("INVALID_TASK_SHAPE", issue.message, `task.${issue.field}`));
    }
    return {
      ok: false,
      errors,
      warnings,
      decision_type: decisionType,
      requires_human_approval: decisionType === "request_human_approval",
    };
  }

  const task = (d as { task: TaskCommand }).task;

  // Agent must be registered.
  if (!registry.has(task.target_agent)) {
    errors.push(
      err(
        "UNKNOWN_AGENT",
        `target_agent "${task.target_agent}" is not registered. Known: ${registry.ids().join(", ")}`,
        "task.target_agent",
      ),
    );
  } else if (!registry.allows(task.target_agent, task.action)) {
    // Action must be in the agent's allow-list.
    const agent = registry.require(task.target_agent);
    errors.push(
      err(
        "ACTION_NOT_ALLOWED",
        `agent "${task.target_agent}" does not allow action "${task.action}". Allowed: ${agent.allowedActions.join(", ")}`,
        "task.action",
      ),
    );
  }

  // Minimal payload requirements for known actions.
  const requiredKeys = REQUIRED_PAYLOAD_KEYS[task.action] ?? [];
  for (const key of requiredKeys) {
    if (!(key in task.payload)) {
      errors.push(
        err("MISSING_PAYLOAD_KEY", `action "${task.action}" requires payload.${key}`, `task.payload.${key}`),
      );
    }
  }

  // Sensitivity / human-approval assessment.
  const sensitivity = assessSensitivity(task);
  const requiresHumanApproval =
    decisionType === "request_human_approval" || sensitivity.sensitive;

  if (sensitivity.sensitive) {
    warnings.push(
      warn(
        "REQUIRES_HUMAN_APPROVAL",
        `task will be gated for human approval: ${sensitivity.reasons.join("; ")}`,
      ),
    );
  }
  if (sensitivity.destructive) {
    warnings.push(
      warn("DESTRUCTIVE_OPERATION", "task is classified as potentially destructive"),
    );
  }

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    decision_type: decisionType,
    task,
    requires_human_approval: requiresHumanApproval,
    sensitivity,
  };
}
