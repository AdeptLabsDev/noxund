// Frontend Agent — landing/apply, report UI, table, honest toggle, row actions, a11y.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/frontend-agent.md";

export function createFrontendAgent(): Agent {
  return defineAgent({
    id: "frontend_agent",
    name: "Frontend",
    description: "Report UI, table, responsiveness, a11y, states, honest toggle.",
    owns: "UI. Not copy/promise, methodology, thresholds, data.",
    contractDoc: DOC,
    handlers: {
      build_report_table: planningHandler({ agentId: "frontend_agent", contractDoc: DOC, artifactType: "spec" }),
      implement_landing: planningHandler({ agentId: "frontend_agent", contractDoc: DOC }),
      add_row_actions: planningHandler({ agentId: "frontend_agent", contractDoc: DOC }),
      define_ui_states: planningHandler({ agentId: "frontend_agent", contractDoc: DOC }),
      audit_accessibility: planningHandler({ agentId: "frontend_agent", contractDoc: DOC }),
    },
  });
}
