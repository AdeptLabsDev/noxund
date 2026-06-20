// @noxund/orchestrator — public entry point.
//
// The multi-agent control plane: the Product Orchestrator emits a structured
// decision → the Decision Validator judges it → the Task Dispatcher routes it
// through the Agent Registry to a specialized agent → the agent returns a
// standardized AgentResult → Project State is updated → everything is logged.
//
// `bootstrap()` wires the default agents, a JSON state store and a logger into a
// ready-to-use Orchestrator. The terminal becomes pure observation.

import { join } from "node:path";
import { createOrchestrator, type Orchestrator } from "./core/orchestrator.ts";
import { createStateStore, initialState } from "./core/project-state.ts";
import { createLogger, consoleSink, fileSink, type Logger, type LogSink } from "./core/logger.ts";
import { createDefaultRegistry } from "./agents/index.ts";
import type { AgentRegistry } from "./core/agent-registry.ts";

export * from "./core/index.ts";
export * from "./agents/index.ts";

const DEFAULT_RUNTIME_DIR = ".runtime";

export interface BootstrapOptions {
  /** Directory for state + log artifacts. Default: `<cwd>/.runtime`. */
  runtimeDir?: string;
  /** Echo a concise line per event to the console. Default: true. */
  console?: boolean;
  /** Override the registry (e.g. a subset of agents). Default: all NOXUND agents. */
  registry?: AgentRegistry;
  /** Seed state if no snapshot exists yet. */
  projectId?: string;
  phase?: string;
}

export interface Bootstrapped {
  orchestrator: Orchestrator;
  logger: Logger;
  registry: AgentRegistry;
  stateFile: string;
  logFile: string;
}

/** Wire a fully-functional Orchestrator with sensible, file-backed defaults. */
export function bootstrap(options: BootstrapOptions = {}): Bootstrapped {
  const runtimeDir = options.runtimeDir ?? join(process.cwd(), DEFAULT_RUNTIME_DIR);
  const stateFile = join(runtimeDir, "project-state.json");
  const logFile = join(runtimeDir, "orchestrator.jsonl");

  const sinks: LogSink[] = [fileSink(logFile)];
  if (options.console ?? true) sinks.push(consoleSink());
  const logger = createLogger({ sinks, context: { project: options.projectId ?? "noxund" } });

  const registry = options.registry ?? createDefaultRegistry();
  const state = createStateStore({
    filePath: stateFile,
    seed: initialState(options.projectId ?? "noxund", options.phase ?? "planning"),
  });

  const orchestrator = createOrchestrator({ registry, state, logger });
  return { orchestrator, logger, registry, stateFile, logFile };
}
