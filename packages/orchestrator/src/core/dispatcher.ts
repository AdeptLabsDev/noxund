// Task Dispatcher — the routing + safety layer. It receives a TaskCommand, confirms
// the target agent and action, enforces the human-approval gate, calls the agent,
// and returns a standardized AgentResult. It makes NO product decisions; it only
// routes and guards. (Defense in depth: it re-checks everything the validator
// checked, because a dispatcher must be safe even if called directly.)
//
// COMMAND-BINDING HARDENING (this unit): the approval gate is no longer truthiness.
// For a sensitive task, the presented approval must be a command-bound ApprovalRecord
// whose identity matches the LIVE, recomputed identity of the exact command about to
// run, is unexpired (per an injected gate clock), and has not already been consumed.
//
// Gate order (NO sensitive handler runs before every preceding gate passes):
//   validated TaskCommand
//     → sensitivity assessment
//     → recompute live command identity
//     → command-bound approval verification (identity + version)
//     → expiry check (injected gate clock)
//     → single-use atomic durable consumption
//     → handler

import type { AgentRegistry } from "./agent-registry.ts";
import type { TaskCommand } from "./task-schema.ts";
import { validateTaskShape } from "./task-schema.ts";
import type { AgentResult } from "./result-schema.ts";
import { result, validateResultShape } from "./result-schema.ts";
import type { ApprovalRecord, SensitivityAssessment } from "./safety.ts";
import { assessSensitivity, verifyApproval } from "./safety.ts";
import { computeCommandIdentity, CanonicalizationError } from "./command-identity.ts";
import type { ConsumptionLedger } from "./project-state.ts";
import type { Logger } from "./logger.ts";
import { nullLogger } from "./logger.ts";
import { nowIso } from "./ids.ts";
import type { AgentContext } from "../agents/base-agent.ts";

export const HUMAN_APPROVAL_SUMMARY =
  "Esta tarefa exige aprovação humana antes da execução.";

/** Gate-layer clock. SEPARATE from the handler-level `ctx.now`; controls expiry only. */
export type GateClock = () => Date;

export interface DispatchOptions {
  /** Presenting a command-bound ApprovalRecord releases a gated (sensitive) task. */
  approval?: ApprovalRecord;
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
  /**
   * Durable single-use ledger for approval consumption. Required to run sensitive
   * (gated) work — without it, an approved sensitive task cannot be consumed and is
   * held for review (fail closed).
   */
  ledger?: ConsumptionLedger;
  /**
   * Injected gate-layer clock used ONLY for approval expiry. Defaults to `() => new Date()`.
   * Distinct from the handler-level `ctx.now`.
   */
  clock?: GateClock;
}

export function createDispatcher(config: DispatcherConfig): Dispatcher {
  const baseLogger = config.logger ?? nullLogger();
  const { registry, ledger } = config;
  const clock: GateClock = config.clock ?? (() => new Date());

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
      //    For sensitive tasks the approval must be COMMAND-BOUND to THIS exact command,
      //    unexpired, and not yet consumed. Non-sensitive tasks skip the whole gate.
      if (sensitivity.sensitive) {
        // 4a. No approval presented → needs_review (unchanged behavior for the "please
        //     approve this" path). No handler runs.
        if (!options.approval) {
          return gatedNeedsReview(task, agent.id, sensitivity, logger);
        }

        // 4b. Recompute the LIVE command identity from the ACTUAL validated command about
        //     to execute (never a stored/mutable reference). Fail closed if the payload is
        //     not canonicalizable.
        let liveIdentity: string;
        try {
          liveIdentity = computeCommandIdentity({
            task_id: task.task_id,
            target_agent: task.target_agent,
            action: task.action,
            payload: task.payload,
          }).command_identity;
        } catch (e) {
          const message =
            e instanceof CanonicalizationError ? e.message : String(e);
          return gateReject(
            task,
            agent.id,
            sensitivity,
            "UNCANONICALIZABLE_PAYLOAD",
            `command identity could not be computed: ${message}`,
            logger,
          );
        }

        // 4c. Verify the presented approval against the live identity + gate clock. A
        //     legacy/unbound token, wrong identity (any task_id/target_agent/action/payload
        //     mutation), unknown version, or expiry all reject here with ZERO handler runs.
        const verification = verifyApproval(options.approval, liveIdentity, clock());
        if (!verification.ok) {
          return gateReject(
            task,
            agent.id,
            sensitivity,
            verification.code,
            verification.message,
            logger,
          );
        }

        // 4d. Single-use atomic durable consumption BEFORE the handler runs. Requires a
        //     ledger — without one we cannot enforce single-use, so we fail closed.
        if (!ledger) {
          return gateReject(
            task,
            agent.id,
            sensitivity,
            "NO_CONSUMPTION_LEDGER",
            "no durable consumption ledger configured; cannot enforce single-use — refusing to execute",
            logger,
          );
        }
        const claimed = ledger.tryConsume(options.approval.approval_id);
        if (!claimed) {
          // Replay: this approval was already consumed (possibly by a concurrent
          // dispatch or a prior run — including before a restart, via the durable ledger).
          return gateReject(
            task,
            agent.id,
            sensitivity,
            "APPROVAL_ALREADY_CONSUMED",
            "approval has already been consumed (single-use); a fresh approval is required",
            logger,
          );
        }
        // From here the approval is durably consumed. If the handler later throws, the
        // approval STAYS consumed (accepted fail-safe: no auto-retry, fresh approval needed).
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

/** Sensitive task with NO approval presented → held for review, not executed. */
function gatedNeedsReview(
  task: TaskCommand,
  agentId: string,
  sensitivity: SensitivityAssessment,
  logger: Logger,
): DispatchOutcome {
  const res = result.needsReview({
    task_id: task.task_id,
    agent: agentId,
    summary: HUMAN_APPROVAL_SUMMARY,
    errors: [],
    next_recommendation: {
      reason: `Human approval required before "${task.action}" can run: ${sensitivity.reasons.join("; ")}`,
    },
  });
  logger.warn("dispatch.needs_review", {
    task_id: task.task_id,
    agent: agentId,
    action: task.action,
    reasons: sensitivity.reasons,
  });
  return { result: res, gated: true, sensitivity };
}

/**
 * Sensitive task with an INVALID/rejected approval (wrong binding, expired, replayed,
 * unbound legacy token, uncanonicalizable, or missing ledger) → needs_review, NOT
 * executed. Fail closed: handler invocation count for this path is exactly 0.
 */
function gateReject(
  task: TaskCommand,
  agentId: string,
  sensitivity: SensitivityAssessment,
  code: string,
  message: string,
  logger: Logger,
): DispatchOutcome {
  const res = result.needsReview({
    task_id: task.task_id,
    agent: agentId,
    summary: HUMAN_APPROVAL_SUMMARY,
    errors: [{ code, message, fatal: false }],
    next_recommendation: {
      reason: `Approval rejected (${code}): ${message}`,
    },
  });
  logger.warn("dispatch.approval_rejected", {
    task_id: task.task_id,
    agent: agentId,
    action: task.action,
    code,
  });
  return { result: res, gated: true, sensitivity };
}
