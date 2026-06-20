// Task Dispatcher — the routing + safety layer. It receives a TaskCommand, confirms
// the target agent and action, enforces the human-approval gate, calls the agent,
// and returns a standardized AgentResult. It makes NO product decisions; it only
// routes and guards. (Defense in depth: it re-checks everything the validator
// checked, because a dispatcher must be safe even if called directly.)

import type { AgentRegistry } from "./agent-registry.ts";
import type { TaskCommand } from "./task-schema.ts";
import { validateTaskShape } from "./task-schema.ts";
import type { AgentResult } from "./result-schema.ts";
import { result, validateResultShape } from "./result-schema.ts";
import type { Approval, SensitivityAssessment } from "./safety.ts";
import { assessSensitivity } from "./safety.ts";
import type { Logger } from "./logger.ts";
import { nullLogger } from "./logger.ts";
import { nowIso } from "./ids.ts";
import type { AgentContext } from "../agents/base-agent.ts";

export const HUMAN_APPROVAL_SUMMARY =
  "Esta tarefa exige aprovação humana antes da execução.";

export interface DispatchOptions {
  /** Presenting an Approval releases a gated (sensitive) task. */
  approval?: Approval;
  logger?: Logger;
}

export interface DispatchOutcome {
  result: AgentResult;
  /** True when the task was held for human approval and NOT executed. */
  gated: boolean;
  sensitivity: SensitivityAssessment;
}

export interface Dispatcher {
  dispatch(task: TaskCommand, options?: DispatchOptions): Promise<DispatchOutcome>;
}

export interface DispatcherConfig {
  registry: AgentRegistry;
  logger?: Logger;
}

export function createDispatcher(config: DispatcherConfig): Dispatcher {
  const baseLogger = config.logger ?? nullLogger();
  const { registry } = config;

  return {
    async dispatch(task, options = {}) {
      const logger = options.logger ?? baseLogger;
      const sensitivity = assessSensitivity(task);

      // 1. Structural sanity (defense in depth).
      const shape = validateTaskShape(task);
      if (!shape.ok) {
        const res = result.failed({
          task_id: typeof task?.task_id === "string" ? task.task_id : "unknown",
          agent: typeof task?.target_agent === "string" ? task.target_agent : "unknown",
          summary: "Dispatch rejected: malformed TaskCommand.",
          errors: shape.issues.map((i) => ({
            code: "INVALID_TASK_SHAPE",
            message: `${i.field}: ${i.message}`,
            fatal: true,
          })),
        });
        logger.error("dispatch.rejected", { task_id: res.task_id, reason: "invalid_shape" });
        return { result: res, gated: false, sensitivity };
      }

      // 2. Agent must exist.
      if (!registry.has(task.target_agent)) {
        const res = result.failed({
          task_id: task.task_id,
          agent: task.target_agent,
          summary: `Dispatch failed: agent "${task.target_agent}" is not registered.`,
          errors: [
            { code: "UNKNOWN_AGENT", message: `Known agents: ${registry.ids().join(", ")}`, fatal: true },
          ],
        });
        logger.error("dispatch.unknown_agent", { task_id: task.task_id, agent: task.target_agent });
        return { result: res, gated: false, sensitivity };
      }

      const agent = registry.require(task.target_agent);

      // 3. Action must be allowed.
      if (!agent.allowedActions.includes(task.action)) {
        const res = result.failed({
          task_id: task.task_id,
          agent: agent.id,
          summary: `Dispatch failed: action "${task.action}" not allowed for ${agent.id}.`,
          errors: [
            { code: "ACTION_NOT_ALLOWED", message: `Allowed: ${agent.allowedActions.join(", ")}`, fatal: true },
          ],
        });
        logger.error("dispatch.action_not_allowed", {
          task_id: task.task_id,
          agent: agent.id,
          action: task.action,
        });
        return { result: res, gated: false, sensitivity };
      }

      // 4. Human-approval gate. The dispatcher will NOT auto-run sensitive work.
      if (sensitivity.sensitive && !options.approval) {
        const res = result.needsReview({
          task_id: task.task_id,
          agent: agent.id,
          summary: HUMAN_APPROVAL_SUMMARY,
          errors: [],
          next_recommendation: {
            reason: `Human approval required before "${task.action}" can run: ${sensitivity.reasons.join("; ")}`,
          },
        });
        logger.warn("dispatch.needs_review", {
          task_id: task.task_id,
          agent: agent.id,
          action: task.action,
          reasons: sensitivity.reasons,
        });
        return { result: res, gated: true, sensitivity };
      }

      // 5. Execute. Any throw becomes a structured failed result — the loop never crashes.
      const ctx: AgentContext = {
        now: nowIso,
        log: (event, data) => logger.info(event, data),
      };

      logger.info("dispatch.start", {
        task_id: task.task_id,
        agent: agent.id,
        action: task.action,
        approved_by: options.approval?.approved_by,
      });

      let res: AgentResult;
      try {
        res = await agent.handle(task, ctx);
      } catch (caught) {
        const message = caught instanceof Error ? caught.message : String(caught);
        res = result.failed({
          task_id: task.task_id,
          agent: agent.id,
          summary: `Agent "${agent.id}" threw while handling "${task.action}".`,
          errors: [{ code: "AGENT_EXCEPTION", message, fatal: true }],
        });
        logger.error("dispatch.exception", { task_id: task.task_id, agent: agent.id, message });
        return { result: res, gated: false, sensitivity };
      }

      // 6. Defend the loop against a misbehaving agent returning a bad envelope.
      const resShape = validateResultShape(res);
      if (!resShape.ok) {
        const fixed = result.failed({
          task_id: task.task_id,
          agent: agent.id,
          summary: `Agent "${agent.id}" returned a malformed AgentResult.`,
          errors: resShape.issues.map((m) => ({ code: "INVALID_RESULT_SHAPE", message: m, fatal: true })),
        });
        logger.error("dispatch.invalid_result", { task_id: task.task_id, agent: agent.id });
        return { result: fixed, gated: false, sensitivity };
      }

      logger.info("dispatch.done", { task_id: task.task_id, agent: agent.id, status: res.status });
      return { result: res, gated: false, sensitivity };
    },
  };
}
