// Agent assembly — the canonical NOXUND agent set and the default registry.
// Order mirrors docs/agents/agent-registry.md "Recommended Execution Order".

import type { Agent } from "./base-agent.ts";
import { createRegistry, type AgentRegistry } from "../core/agent-registry.ts";
import { createProductAgent } from "./product-agent.ts";
import { createDatabaseAgent } from "./database-agent.ts";
import { createBackendAgent } from "./backend-agent.ts";
import { createFrontendAgent } from "./frontend-agent.ts";
import { createDataAgent } from "./data-agent.ts";
import { createSecurityAgent } from "./security-agent.ts";
import { createQaAgent } from "./qa-agent.ts";
import { createDevopsAgent } from "./devops-agent.ts";
import { createMarketingAgent } from "./marketing-agent.ts";
import { createDocumentationAgent } from "./documentation-agent.ts";

export * from "./base-agent.ts";
export {
  createProductAgent,
  createDatabaseAgent,
  createBackendAgent,
  createFrontendAgent,
  createDataAgent,
  createSecurityAgent,
  createQaAgent,
  createDevopsAgent,
  createMarketingAgent,
  createDocumentationAgent,
};

/** Build the full set of NOXUND agents (fresh instances). */
export function createDefaultAgents(): Agent[] {
  return [
    createProductAgent(),
    createDatabaseAgent(),
    createBackendAgent(),
    createFrontendAgent(),
    createDataAgent(),
    createSecurityAgent(),
    createQaAgent(),
    createDevopsAgent(),
    createMarketingAgent(),
    createDocumentationAgent(),
  ];
}

/** The canonical registry the Orchestrator delegates to by default. */
export function createDefaultRegistry(): AgentRegistry {
  return createRegistry(createDefaultAgents());
}

/** Stable list of known agent ids (handy for docs, UIs, validation messages). */
export const DEFAULT_AGENT_IDS: readonly string[] = createDefaultAgents().map((a) => a.id);
