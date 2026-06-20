// Data / AI Pipeline Agent — Python engine, collection, raw/computed, DETERMINISTIC
// scoring, entity resolution, reproducibility. Non-negotiable: this agent defines
// methodology; it never has generative AI produce numbers.

import type { Agent, AgentHandler } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";
import { result } from "../core/result-schema.ts";

const DOC = "docs/agents/data-ai-pipeline-agent.md";

/**
 * Bespoke executor for the canonical example in the brief: define the scoring
 * methodology (conceptual rubric, signal sources, velocity, competition rule,
 * stated limitations) WITHOUT computing any report number. The output is a spec the
 * Backend/Database agents consume next.
 */
const defineScoringMethodology: AgentHandler = (task) => {
  const feature = String(task.payload.feature ?? "Type Beat Market Report");
  const columns = Array.isArray(task.payload.columns) ? task.payload.columns : [];

  return result.completed({
    task_id: task.task_id,
    agent: "data_agent",
    summary:
      `Scoring methodology drafted for "${feature}". Defined the conceptual basis of ` +
      `Score (rubric 40/25/20/15, versioned by rubric_version + rubric_hash), the origin of ` +
      `Signals, the Velocity calculation, the Competition (Low/Medium/High) rule, and explicit ` +
      `methodological limitations. No numbers were generated — scoring stays deterministic in code.`,
    artifacts: [
      {
        type: "methodology",
        path: DOC,
        description:
          `Conceptual scoring spec for ${feature}` +
          (columns.length ? ` over columns [${columns.join(", ")}]` : "") +
          ". Deterministic, versioned, auditable to raw_youtube_videos.",
      },
    ],
    next_recommendation: {
      target_agent: "backend_agent",
      action: "create_api_contract",
      priority: "high",
      reason:
        "Methodology is defined; backend can now design the API contract that exposes the " +
        "computed report rows without ever generating numbers.",
    },
  });
};

export function createDataAgent(): Agent {
  return defineAgent({
    id: "data_agent",
    name: "Data / AI Pipeline",
    description: "Collection, raw/computed, deterministic scoring, entity resolution, reproducibility.",
    owns: "Python engine + methodology. Not schema, endpoints/UI, secrets policy.",
    contractDoc: DOC,
    handlers: {
      define_scoring_methodology: defineScoringMethodology,
      define_collection_spec: planningHandler({ agentId: "data_agent", contractDoc: DOC, artifactType: "spec" }),
      define_entity_resolution: planningHandler({ agentId: "data_agent", contractDoc: DOC, artifactType: "spec" }),
      validate_reproducibility: planningHandler({ agentId: "data_agent", contractDoc: DOC }),
      compute_score_dry_run: planningHandler({ agentId: "data_agent", contractDoc: DOC }),
    },
  });
}
