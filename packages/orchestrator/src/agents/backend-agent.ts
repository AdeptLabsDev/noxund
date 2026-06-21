// Backend / Next API Agent — Route Handlers, Server Actions, events, approval gate.

import type { Agent, AgentHandler } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";
import { result } from "../core/result-schema.ts";

const DOC = "docs/agents/backend-agent.md";

const AUTHZ_REVIEW = "docs/backend/BE-0001-consumability-authz-contract-review.md";
const AUTHZ_HANDOFF = "docs/backend/HANDOFF-consumability-authz-review.md";

/**
 * Bespoke handler for `review_authz_contract`. Unlike the generic planning stub,
 * it reports the actual BE-0001 deliverable: a per-endpoint consumability review
 * of `02_` §7 against the data model, plus Backend's binding commitment to the
 * handler-level conditions SEC-F01/F02/F03/F11. No report numbers are generated
 * here — this is a design/authz contract, not computation. It chains to Security
 * because the assumed authz contract must be signed off before Phase 9 (RLS).
 */
const reviewAuthzContract: AgentHandler = (task, ctx) => {
  ctx.log?.("agent.review", { agent: "backend_agent", action: task.action });
  return result.completed({
    task_id: task.task_id,
    agent: "backend_agent",
    summary:
      "Consumability + authz contract review complete: the data model serves every " +
      "endpoint in 02_ §7, and Backend assumes SEC-F01 (in-code ownership/role on all " +
      "service-role paths), SEC-F02 (/apply zero-grant + whitelist + forced status), " +
      "SEC-F03 (producer reads only the public VIEW), and SEC-F11 (/internal/* secret, " +
      "constant-time, 404) as non-negotiable handler design before Phase 1/9. Atomic " +
      "event+payload writes (WTP, intent) confirmed via Postgres RPC. DevOps actioned " +
      "for SEC-F10/F11; one API-surface gap raised (§2-E: missing follow-up response " +
      "route). Blocked on OD-02 (Auth) only for the final /apply post-approval + session.",
    artifacts: [
      {
        type: "review",
        path: AUTHZ_REVIEW,
        description:
          "Created: endpoint consumability matrix (02_ §7 → model) and the binding " +
          "authz contract (SEC-F01/F02/F03/F11) + atomic-write confirmation.",
      },
      {
        type: "handoff",
        path: AUTHZ_HANDOFF,
        description: "Created: governance handoff to the Product Orchestrator.",
      },
    ],
    next_recommendation: {
      target_agent: "security_agent",
      action: "review_auth",
      priority: "high",
      reason:
        "Backend assumed SEC-F01/F02/F03/F11 as the handler authz contract; Security " +
        "must sign it off (with handler+test evidence) to lift the veto on Phase 9. " +
        "DevOps separately owns SEC-F10 (Sentry scrub) and SEC-F11 (cron secret).",
    },
  });
};

export function createBackendAgent(): Agent {
  return defineAgent({
    id: "backend_agent",
    name: "Backend / Next API",
    description: "Route Handlers, Server Actions, event endpoints, approval gate, follow-up trigger.",
    owns: "API surface (Next), events, approval gate. Not schema, Score, auth policy, UI.",
    contractDoc: DOC,
    handlers: {
      create_api_contract: planningHandler({
        agentId: "backend_agent",
        contractDoc: DOC,
        artifactType: "spec",
        next: {
          target_agent: "security_agent",
          action: "review_endpoint",
          reason: "New API contract must pass a security/authz review before implementation.",
          priority: "high",
        },
      }),
      implement_route_handler: planningHandler({ agentId: "backend_agent", contractDoc: DOC }),
      define_event_schema: planningHandler({ agentId: "backend_agent", contractDoc: DOC }),
      add_server_action: planningHandler({ agentId: "backend_agent", contractDoc: DOC }),
      review_authz_contract: reviewAuthzContract,
    },
  });
}
