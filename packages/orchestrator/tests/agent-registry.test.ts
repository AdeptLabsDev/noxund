import { test } from "node:test";
import assert from "node:assert/strict";
import { createRegistry, UnknownAgentError } from "../src/core/agent-registry.ts";
import { createDefaultAgents, createDefaultRegistry, DEFAULT_AGENT_IDS } from "../src/agents/index.ts";

test("default registry exposes the full NOXUND agent set", () => {
  const reg = createDefaultRegistry();
  assert.equal(reg.list().length, 10);
  assert.ok(reg.has("data_agent"));
  assert.ok(reg.has("database_agent"));
  assert.equal(reg.has("nonexistent_agent"), false);
  assert.deepEqual(reg.ids(), [...DEFAULT_AGENT_IDS]);
});

test("require() throws UnknownAgentError for missing agents", () => {
  const reg = createDefaultRegistry();
  assert.throws(() => reg.require("ghost_agent"), UnknownAgentError);
});

test("allows() enforces the action allow-list", () => {
  const reg = createDefaultRegistry();
  assert.equal(reg.allows("data_agent", "define_scoring_methodology"), true);
  assert.equal(reg.allows("data_agent", "deploy"), false);
  assert.equal(reg.allows("ghost_agent", "anything"), false);
});

test("duplicate agent ids are rejected at construction", () => {
  const agents = createDefaultAgents();
  assert.throws(() => createRegistry([agents[0]!, agents[0]!]), /Duplicate agent id/);
});
