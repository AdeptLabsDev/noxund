// Documentation Agent — README, changelog, decision log, handoffs, index, glossary,
// traceability. Escalates to the Orchestrator when a doc records/changes a decision.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/documentation-agent.md";

export function createDocumentationAgent(): Agent {
  return defineAgent({
    id: "documentation_agent",
    name: "Documentation",
    description: "README, changelog, decision log, handoffs, context index, glossary, traceability.",
    owns: "Docs + traceability. Not decision content, scope, code.",
    contractDoc: DOC,
    handlers: {
      update_readme: planningHandler({ agentId: "documentation_agent", contractDoc: DOC }),
      record_handoff: planningHandler({ agentId: "documentation_agent", contractDoc: DOC, artifactType: "handoff" }),
      update_decision_log: planningHandler({ agentId: "documentation_agent", contractDoc: DOC }),
      update_context_index: planningHandler({ agentId: "documentation_agent", contractDoc: DOC }),
    },
  });
}
