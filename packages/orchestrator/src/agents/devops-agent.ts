// DevOps / Infra Agent — environments, build, deploy, env, cron, observability,
// branch protection. deploy and configure_env are SENSITIVE — gated for approval.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/devops-infra-agent.md";

export function createDevopsAgent(): Agent {
  return defineAgent({
    id: "devops_agent",
    name: "DevOps / Infra",
    description: "Environments, build, deploy, env, cron, observability, branch protection.",
    owns: "Pipelines + environments. Not stack, features, schema, secrets policy.",
    contractDoc: DOC,
    handlers: {
      define_pipeline: planningHandler({ agentId: "devops_agent", contractDoc: DOC, artifactType: "spec" }),
      setup_observability: planningHandler({ agentId: "devops_agent", contractDoc: DOC }),
      configure_branch_protection: planningHandler({ agentId: "devops_agent", contractDoc: DOC }),
      // Sensitive actions — allowed, but gated by the safety policy.
      deploy: planningHandler({ agentId: "devops_agent", contractDoc: DOC }),
      configure_env: planningHandler({ agentId: "devops_agent", contractDoc: DOC }),
    },
  });
}
