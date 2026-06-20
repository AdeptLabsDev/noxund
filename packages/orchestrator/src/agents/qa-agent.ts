// QA Agent — acceptance criteria, critical flows, UI/API/regression/reproducibility
// tests, metrics. A reviewer that can block on a failed acceptance criterion.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/qa-agent.md";

export function createQaAgent(): Agent {
  return defineAgent({
    id: "qa_agent",
    name: "QA",
    description: "Acceptance criteria, critical flows, regression, reproducibility tests, metrics.",
    owns: "Quality gates + tests. Not scope, schema, methodology, features.",
    contractDoc: DOC,
    handlers: {
      define_test_plan: planningHandler({ agentId: "qa_agent", contractDoc: DOC }),
      validate_acceptance: planningHandler({ agentId: "qa_agent", contractDoc: DOC, artifactType: "review" }),
      run_smoke_test: planningHandler({ agentId: "qa_agent", contractDoc: DOC }),
      regression_check: planningHandler({ agentId: "qa_agent", contractDoc: DOC }),
    },
  });
}
