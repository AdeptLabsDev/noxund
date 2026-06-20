// AgentResult — the standardized envelope every agent returns. The Orchestrator
// consumes ONLY this shape; it never parses free-form agent prose. This keeps the
// loop machine-readable: status drives state transitions, next_recommendation
// drives the next decision.

import type { Priority } from "./task-schema.ts";

export type AgentStatus = "completed" | "failed" | "needs_review" | "blocked";

export const AGENT_STATUSES: readonly AgentStatus[] = [
  "completed",
  "failed",
  "needs_review",
  "blocked",
];

export function isAgentStatus(value: unknown): value is AgentStatus {
  return typeof value === "string" && (AGENT_STATUSES as readonly string[]).includes(value);
}

/** A concrete output produced by an agent (a file, a doc, a spec, a report). */
export interface Artifact {
  /** e.g. "doc", "spec", "handoff", "code", "report". */
  type: string;
  /** Repo-relative path when the artifact is a file. */
  path?: string;
  /** External locator when applicable. */
  uri?: string;
  description: string;
}

export interface AgentError {
  code: string;
  message: string;
  /** When true, the error is terminal for this task. */
  fatal?: boolean;
}

/** A machine-readable suggestion for what the Orchestrator should do next. */
export interface NextRecommendation {
  target_agent?: string;
  action?: string;
  priority?: Priority;
  reason: string;
}

export interface AgentResult {
  task_id: string;
  agent: string;
  status: AgentStatus;
  summary: string;
  artifacts: Artifact[];
  errors: AgentError[];
  next_recommendation: NextRecommendation | null;
}

export interface ResultInput {
  task_id: string;
  agent: string;
  status: AgentStatus;
  summary: string;
  artifacts?: Artifact[];
  errors?: AgentError[];
  next_recommendation?: NextRecommendation | null;
}

export function makeResult(input: ResultInput): AgentResult {
  return {
    task_id: input.task_id,
    agent: input.agent,
    status: input.status,
    summary: input.summary,
    artifacts: input.artifacts ?? [],
    errors: input.errors ?? [],
    next_recommendation: input.next_recommendation ?? null,
  };
}

/** Ergonomic constructors so agents (and the dispatcher) never hand-build envelopes. */
export const result = {
  completed(
    input: Omit<ResultInput, "status">,
  ): AgentResult {
    return makeResult({ ...input, status: "completed" });
  },
  failed(input: Omit<ResultInput, "status">): AgentResult {
    return makeResult({ ...input, status: "failed" });
  },
  needsReview(input: Omit<ResultInput, "status">): AgentResult {
    return makeResult({ ...input, status: "needs_review" });
  },
  blocked(input: Omit<ResultInput, "status">): AgentResult {
    return makeResult({ ...input, status: "blocked" });
  },
};

export interface ResultShapeResult {
  ok: boolean;
  issues: string[];
}

/** Structural validation of an AgentResult (used to defend the loop against bad agents). */
export function validateResultShape(value: unknown): ResultShapeResult {
  const issues: string[] = [];
  if (typeof value !== "object" || value === null) {
    return { ok: false, issues: ["result must be an object"] };
  }
  const r = value as Record<string, unknown>;
  if (typeof r.task_id !== "string") issues.push("task_id must be a string");
  if (typeof r.agent !== "string") issues.push("agent must be a string");
  if (!isAgentStatus(r.status)) {
    issues.push(`status must be one of ${AGENT_STATUSES.join(", ")}`);
  }
  if (typeof r.summary !== "string") issues.push("summary must be a string");
  if (!Array.isArray(r.artifacts)) issues.push("artifacts must be an array");
  if (!Array.isArray(r.errors)) issues.push("errors must be an array");
  return { ok: issues.length === 0, issues };
}
