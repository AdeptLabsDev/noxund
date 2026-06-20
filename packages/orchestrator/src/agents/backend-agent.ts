// Backend / Next API Agent — Route Handlers, Server Actions, events, approval gate.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/backend-agent.md";

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
      review_authz_contract: planningHandler({ agentId: "backend_agent", contractDoc: DOC }),
    },
  });
}
