// Agent Registry — the allow-list of agents the Orchestrator may delegate to.
// Nothing is dispatched to an agent that is not registered here. This is the
// structural guarantee against "calling agents that don't exist".

import type { Agent } from "../agents/base-agent.ts";

export class UnknownAgentError extends Error {
  readonly agentId: string;
  constructor(agentId: string, known: readonly string[]) {
    super(`Unknown agent "${agentId}". Registered agents: ${known.join(", ") || "<none>"}`);
    this.name = "UnknownAgentError";
    this.agentId = agentId;
  }
}

export interface AgentRegistry {
  has(id: string): boolean;
  get(id: string): Agent | undefined;
  /** Returns the agent or throws UnknownAgentError. */
  require(id: string): Agent;
  /** Whether `id` is registered AND accepts `action`. */
  allows(id: string, action: string): boolean;
  list(): Agent[];
  ids(): string[];
}

export function createRegistry(agents: readonly Agent[]): AgentRegistry {
  const byId = new Map<string, Agent>();
  for (const agent of agents) {
    if (byId.has(agent.id)) {
      throw new Error(`Duplicate agent id in registry: "${agent.id}"`);
    }
    byId.set(agent.id, agent);
  }

  return {
    has(id) {
      return byId.has(id);
    },
    get(id) {
      return byId.get(id);
    },
    require(id) {
      const agent = byId.get(id);
      if (!agent) throw new UnknownAgentError(id, [...byId.keys()]);
      return agent;
    },
    allows(id, action) {
      const agent = byId.get(id);
      return agent ? agent.allowedActions.includes(action) : false;
    },
    list() {
      return [...byId.values()];
    },
    ids() {
      return [...byId.keys()];
    },
  };
}
