// Database Agent — schema, migrations, raw/computed, report snapshots, rubric
// versioning, RLS. Note: change_db_schema and run_migration are SENSITIVE actions —
// the safety policy gates them for human approval even though they are allowed here.

import type { Agent } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";

const DOC = "docs/agents/database-agent.md";

export function createDatabaseAgent(): Agent {
  return defineAgent({
    id: "database_agent",
    name: "Database",
    description: "Schema, migrations, raw/computed, report snapshots, rubric versioning, RLS.",
    owns: "Data model + migrations. Not endpoints, Score, UI, auth policy.",
    contractDoc: DOC,
    handlers: {
      design_schema: planningHandler({ agentId: "database_agent", contractDoc: DOC, artifactType: "spec" }),
      plan_migration: planningHandler({ agentId: "database_agent", contractDoc: DOC }),
      define_rls_policy: planningHandler({ agentId: "database_agent", contractDoc: DOC }),
      // Sensitive (mutating) actions — allowed, but gated by the safety policy.
      change_db_schema: planningHandler({ agentId: "database_agent", contractDoc: DOC, artifactType: "migration" }),
      run_migration: planningHandler({ agentId: "database_agent", contractDoc: DOC, artifactType: "migration" }),
    },
  });
}
