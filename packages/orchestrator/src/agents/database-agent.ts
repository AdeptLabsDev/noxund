// Database Agent — schema, migrations, raw/computed, report snapshots, rubric
// versioning, RLS. Note: change_db_schema and run_migration are SENSITIVE actions —
// the safety policy gates them for human approval even though they are allowed here.
//
// The planning actions below are bespoke executors faithful to the MVP data-model
// proposal in docs/database/ (reviewed by PO/DEC-0003 + Security/SEC-0001). They
// produce structured plans/handoffs and NEVER fabricate report numbers — Score,
// Velocity, Signals, Competition and Example stay deterministic in the data engine.

import type { Agent, AgentHandler } from "./base-agent.ts";
import { defineAgent, planningHandler } from "./base-agent.ts";
import { result } from "../core/result-schema.ts";

const DOC = "docs/agents/database-agent.md";

/**
 * Propose the MVP data model. Faithful to docs/database/: 20 tables organized by
 * immutability class, every public number traceable to raw_youtube_videos, producer
 * outcomes as append-only events (never boolean flags), and zero marketplace/Phase-2
 * tables. Proposal only — no migrations, no Supabase schema, no numbers generated.
 */
const designSchema: AgentHandler = (task) => {
  const feature = String(task.payload.feature ?? "NOXUND Hotspot Artists Report MVP");

  return result.completed({
    task_id: task.task_id,
    agent: "database_agent",
    summary:
      `MVP data model proposed for "${feature}": 20 tables (19 model + admin_users security ` +
      `control), organized by immutability class — RAW (immutable YouTube snapshots), COMPUTED ` +
      `(reconstructible, versioned by rubric_version + rubric_hash), SNAPSHOT (frozen report_items), ` +
      `EVENT (append-only producer_events/audit_events), STATE. Every public number is traceable to ` +
      `raw_youtube_videos; producer outcomes are events, never boolean flags; no marketplace/Phase-2 ` +
      `tables. Proposal only — no migrations, no Supabase schema, no numbers generated.`,
    artifacts: [
      {
        type: "spec",
        path: "docs/database/mvp-data-model.md",
        description:
          "Per-table data model (20 tables): raw/computed/snapshot/event/state classes, " +
          "auth_user_id (SEC-D01), admin_users (SEC-D02), immutability triggers (SEC-D03), " +
          "report_items public VIEW (SEC-F03). Provenance to raw_youtube_videos.",
      },
      {
        type: "doc",
        path: "docs/database/entity-relationship-notes.md",
        description: "ER diagram, immutability classes and provenance chains (raw → computed → snapshot).",
      },
      {
        type: "handoff",
        path: "docs/database/HANDOFF-mvp-data-model.md",
        description: "Handoff referencing DEC-0003 (PO ✅) + SEC-0001 (Security ⚠️ conditional, veto) verdicts.",
      },
    ],
    next_recommendation: {
      target_agent: "database_agent",
      action: "plan_migration",
      priority: "high",
      reason:
        "Schema designed and reviewed (PO + Data/AI ✅; Security conditional). Sequence the migration " +
        "order before any DDL; no migration opens until Backend review lands and OD-02 (Auth) is confirmed.",
    },
  });
};

/**
 * Recommended implementation order (9 phases: 8 of tables + RLS last). Mirrors
 * docs/database/migration-plan.md. Pure planning — every real DDL stays behind the
 * sensitive change_db_schema/run_migration gate plus Database + Security review.
 */
const planMigration: AgentHandler = (task) => {
  return result.completed({
    task_id: task.task_id,
    agent: "database_agent",
    summary:
      "Migration order planned in 9 phases: (1) identity/access + admin_users, (2) versioning, " +
      "(3) runs/artists, (4) raw snapshots + immutability trigger, (5) computed + report, " +
      "(6) producer events, (7) follow-ups + WTP, (8) audit_events, (9) RLS. Each migration is " +
      "reversible; raw never gets an UPDATE route; no destructive/marketplace migration. Plan only.",
    artifacts: [
      {
        type: "handoff",
        path: "docs/database/migration-plan.md",
        description:
          "9-phase migration plan with per-phase reviews. Phase 1 gated on OD-02; Phases 4/8 require " +
          "immutability triggers (SEC-D03); Phase 9 (RLS) gated by SEC-F01/F02/F03 + Security veto.",
      },
    ],
    next_recommendation: {
      target_agent: "database_agent",
      action: "define_rls_policy",
      priority: "high",
      reason: "Implementation order is set; draft the RLS access policy (Phase 9) for Security to review.",
    },
  });
};

/**
 * Draft RLS/access recommendations for the Security Agent to close (Security co-owns
 * RLS and holds veto). Mirrors docs/database/rls-review-notes.md with the decisions
 * already fixed by SEC-0001 (auth_user_id, admin_users + is_admin(), immutability
 * triggers) and the blocking conditions SEC-F01/F02/F03.
 */
const defineRlsPolicy: AgentHandler = (task) => {
  return result.completed({
    task_id: task.task_id,
    agent: "database_agent",
    summary:
      "RLS policy drafted: default-deny on all tables; producer isolation via auth_user_id = auth.uid(); " +
      "approved producers read only published reports through a public VIEW (SEC-F03); admin via " +
      "admin_users + is_admin() (SEC-D02); raw/audit immutability by trigger (SEC-D03). NOT final — " +
      "service_role bypasses RLS (SEC-F01), so authz on service-role paths lives in handler code. " +
      "Security retains veto on Phase 9 until re-review.",
    artifacts: [
      {
        type: "review",
        path: "docs/database/rls-review-notes.md",
        description:
          "RLS recommendations + the security decisions fixed in SEC-0001. Status: conditional, " +
          "Security veto held on Phase 9 / access endpoints / pre-production gate.",
      },
    ],
    next_recommendation: {
      target_agent: "security_agent",
      action: "review_rls",
      priority: "high",
      reason:
        "RLS draft ready. Security must re-review against SEC-F01/F02/F03 + SEC-F13/F14 with evidence " +
        "(policies + triggers + view + ownership checks) before RLS lands in main. Silence ≠ approval.",
    },
  });
};

export function createDatabaseAgent(): Agent {
  return defineAgent({
    id: "database_agent",
    name: "Database",
    description: "Schema, migrations, raw/computed, report snapshots, rubric versioning, RLS.",
    owns: "Data model + migrations. Not endpoints, Score, UI, auth policy.",
    contractDoc: DOC,
    handlers: {
      design_schema: designSchema,
      plan_migration: planMigration,
      define_rls_policy: defineRlsPolicy,
      // Sensitive (mutating) actions — allowed, but gated by the safety policy. When a
      // handler here runs, approval was already granted upstream by the dispatcher.
      change_db_schema: planningHandler({ agentId: "database_agent", contractDoc: DOC, artifactType: "migration" }),
      run_migration: planningHandler({ agentId: "database_agent", contractDoc: DOC, artifactType: "migration" }),
    },
  });
}
