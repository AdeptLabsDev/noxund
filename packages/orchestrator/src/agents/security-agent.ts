// Security & Privacy Agent — auth, roles, RLS, secrets, endpoints, logs, privacy.
// A reviewer that can block; modeled here with review actions.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/security-privacy-agent.md";

export function createSecurityAgent(): Agent {
  return defineAgent({
    id: "security_agent",
    name: "Security & Privacy",
    description: "Auth, roles, RLS, secrets, endpoints, logs, privacy. Can block on security risk.",
    owns: "Security posture + reviews. Not scope, methodology, features.",
    contractDoc: DOC,
    handlers: {
      review_auth: planningHandler({ agentId: "security_agent", contractDoc: DOC, artifactType: "review" }),
      review_endpoint: planningHandler({ agentId: "security_agent", contractDoc: DOC, artifactType: "review" }),
      review_rls: planningHandler({ agentId: "security_agent", contractDoc: DOC, artifactType: "review" }),
      audit_secrets: planningHandler({ agentId: "security_agent", contractDoc: DOC, artifactType: "review" }),
      threat_model: planningHandler({ agentId: "security_agent", contractDoc: DOC, artifactType: "review" }),
    },
  });
}
