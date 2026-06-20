// Marketing / GTM Agent — invite, application, manual selection, follow-up/WTP
// messaging, honest copy. Cannot change the product promise alone.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/marketing-gtm-agent.md";

export function createMarketingAgent(): Agent {
  return defineAgent({
    id: "marketing_agent",
    name: "Marketing / GTM",
    description: "Invite waves, application, manual selection, follow-up/WTP messaging, honest copy.",
    owns: "Outreach + honest copy. Not central promise/positioning, public opening, events/UI.",
    contractDoc: DOC,
    handlers: {
      plan_invite_wave: planningHandler({ agentId: "marketing_agent", contractDoc: DOC }),
      draft_invite_copy: planningHandler({ agentId: "marketing_agent", contractDoc: DOC, artifactType: "copy" }),
      draft_followup_message: planningHandler({ agentId: "marketing_agent", contractDoc: DOC, artifactType: "copy" }),
      review_public_copy: planningHandler({ agentId: "marketing_agent", contractDoc: DOC, artifactType: "review" }),
    },
  });
}
