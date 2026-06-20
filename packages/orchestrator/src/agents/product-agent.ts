// Product Orchestrator as a registered, delegable agent (planning/coordination work
// it can be asked to perform). It remains the central authority elsewhere; here it is
// just another addressable executor for backlog/decision-shaping tasks.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/product-orchestrator-agent.md";

export function createProductAgent(): Agent {
  return defineAgent({
    id: "product_agent",
    name: "Product Orchestrator",
    description: "Breaks scope into tasks, prioritizes, records decisions, approves/rejects.",
    owns: "Backlog, priority, decision log, acceptance criteria, scope guardrails.",
    contractDoc: DOC,
    handlers: {
      break_down_scope: planningHandler({ agentId: "product_agent", contractDoc: DOC }),
      define_acceptance_criteria: planningHandler({ agentId: "product_agent", contractDoc: DOC }),
      prioritize_backlog: planningHandler({ agentId: "product_agent", contractDoc: DOC }),
      plan_sprint: planningHandler({ agentId: "product_agent", contractDoc: DOC }),
      record_decision: planningHandler({ agentId: "product_agent", contractDoc: DOC }),
    },
  });
}
