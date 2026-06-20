// Agent contract — the executable counterpart of the markdown agent contracts in
// docs/agents/. An Agent owns a domain, declares the actions it accepts, and turns
// a TaskCommand into an AgentResult. The Orchestrator never calls handlers directly;
// it goes through the registry + dispatcher.
//
// IMPORTANT (scope): the handlers built here are *foundation executors*. They produce
// structured plans/handoffs and never fabricate report numbers (Score, Velocity,
// Signals, Competition, Example) — that is a locked non-negotiable. Real product work
// is wired in later, agent by agent, behind this same contract.

import type { TaskCommand } from "../core/task-schema.ts";
import type { AgentResult, Artifact, NextRecommendation } from "../core/result-schema.ts";
import { result } from "../core/result-schema.ts";

/** Ambient services an agent may use while handling a task. */
export interface AgentContext {
  /** Single source of "now" so results are testable/reproducible. */
  now: () => string;
  /** Optional structured logger scoped to the dispatch. */
  log?: (event: string, data?: Record<string, unknown>) => void;
}

export type AgentHandler = (
  task: TaskCommand,
  ctx: AgentContext,
) => AgentResult | Promise<AgentResult>;

export interface Agent {
  id: string;
  name: string;
  description: string;
  /** What this agent owns (mirrors docs/agents/agent-registry.md). */
  owns: string;
  /** The closed set of actions this agent accepts. The validator enforces it. */
  allowedActions: readonly string[];
  handle: AgentHandler;
}

export interface AgentDefinition {
  id: string;
  name: string;
  description: string;
  owns: string;
  /** Per-action handlers. Keys must be a superset of allowedActions. */
  handlers: Record<string, AgentHandler>;
  /** Optional doc path used to attribute the contract source in artifacts. */
  contractDoc?: string;
}

/**
 * Build an Agent from per-action handlers. `allowedActions` is derived from the
 * handler keys, guaranteeing the registry and the executor can never drift apart.
 */
export function defineAgent(def: AgentDefinition): Agent {
  const allowedActions = Object.keys(def.handlers);
  return {
    id: def.id,
    name: def.name,
    description: def.description,
    owns: def.owns,
    allowedActions,
    handle(task, ctx) {
      const handler = def.handlers[task.action];
      if (!handler) {
        // Defense in depth: should be caught by the validator first.
        return result.failed({
          task_id: task.task_id,
          agent: def.id,
          summary: `Agent "${def.id}" has no handler for action "${task.action}".`,
          errors: [
            {
              code: "ACTION_NOT_IMPLEMENTED",
              message: `Allowed actions: ${allowedActions.join(", ")}`,
              fatal: true,
            },
          ],
        });
      }
      return handler(task, ctx);
    },
  };
}

/**
 * A reusable "foundation executor": records the decision as a structured handoff
 * artifact and reports `completed`, echoing the success criteria as a checklist.
 * Specialized agents use this for planning/definition/review actions and override
 * only where they need bespoke behavior.
 */
export function planningHandler(opts: {
  agentId: string;
  contractDoc?: string;
  artifactType?: string;
  next?: NextRecommendation;
}): AgentHandler {
  return (task, ctx) => {
    const artifacts: Artifact[] = [
      {
        type: opts.artifactType ?? "handoff",
        path: opts.contractDoc,
        description:
          `Foundation executor for "${task.action}": structured plan/handoff produced ` +
          `(${task.success_criteria.length} acceptance criteria captured). ` +
          `No report numbers were generated.`,
      },
    ];
    ctx.log?.("agent.planning", { agent: opts.agentId, action: task.action });
    return result.completed({
      task_id: task.task_id,
      agent: opts.agentId,
      summary:
        `${opts.agentId} handled "${task.action}". Acceptance criteria acknowledged: ` +
        task.success_criteria.map((c) => `“${c}”`).join("; ") + ".",
      artifacts,
      next_recommendation: opts.next ?? null,
    });
  };
}
