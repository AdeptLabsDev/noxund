// Project State — the central, durable memory the Orchestrator reasons over instead
// of "texto solto". Two layers:
//   1. pure reducers (no IO) — trivially testable, immutable;
//   2. a JSON-file store that wraps the reducers with load/save persistence.

import { writeFileSync, readFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type { AgentResult, Artifact } from "./result-schema.ts";
import type { DecisionType } from "./decision-schema.ts";
import { createId, nowIso } from "./ids.ts";

export interface DecisionLogEntry {
  id: string;
  ts: string;
  decision_type: DecisionType;
  summary: string;
  task_id?: string;
  reason?: string;
  references?: string[];
}

export interface ProjectState {
  project_id: string;
  current_phase: string;
  completed_tasks: string[];
  pending_tasks: string[];
  blocked_tasks: string[];
  decisions: DecisionLogEntry[];
  artifacts: Artifact[];
  last_agent_results: AgentResult[];
  updated_at: string;
}

export function initialState(projectId = "noxund", phase = "planning"): ProjectState {
  return {
    project_id: projectId,
    current_phase: phase,
    completed_tasks: [],
    pending_tasks: [],
    blocked_tasks: [],
    decisions: [],
    artifacts: [],
    last_agent_results: [],
    updated_at: nowIso(),
  };
}

// ---------------------------------------------------------------------------
// Pure reducers. Each returns a NEW state; none mutate their input.
// ---------------------------------------------------------------------------

function touch(state: ProjectState, patch: Partial<ProjectState>): ProjectState {
  return { ...state, ...patch, updated_at: nowIso() };
}

function withoutTask(ids: string[], taskId: string): string[] {
  return ids.filter((id) => id !== taskId);
}

function uniqueAppend(ids: string[], taskId: string): string[] {
  return ids.includes(taskId) ? ids : [...ids, taskId];
}

export function withPendingTask(state: ProjectState, taskId: string): ProjectState {
  return touch(state, {
    pending_tasks: uniqueAppend(state.pending_tasks, taskId),
    completed_tasks: withoutTask(state.completed_tasks, taskId),
    blocked_tasks: withoutTask(state.blocked_tasks, taskId),
  });
}

export function withCompletedTask(state: ProjectState, taskId: string): ProjectState {
  return touch(state, {
    completed_tasks: uniqueAppend(state.completed_tasks, taskId),
    pending_tasks: withoutTask(state.pending_tasks, taskId),
    blocked_tasks: withoutTask(state.blocked_tasks, taskId),
  });
}

export function withBlockedTask(state: ProjectState, taskId: string): ProjectState {
  return touch(state, {
    blocked_tasks: uniqueAppend(state.blocked_tasks, taskId),
    pending_tasks: withoutTask(state.pending_tasks, taskId),
    completed_tasks: withoutTask(state.completed_tasks, taskId),
  });
}

export function withDecision(state: ProjectState, entry: DecisionLogEntry): ProjectState {
  return touch(state, { decisions: [...state.decisions, entry] });
}

export function withArtifacts(state: ProjectState, artifacts: Artifact[]): ProjectState {
  if (artifacts.length === 0) return state;
  return touch(state, { artifacts: [...state.artifacts, ...artifacts] });
}

const DEFAULT_RESULT_HISTORY = 25;

export function withResult(
  state: ProjectState,
  result: AgentResult,
  max = DEFAULT_RESULT_HISTORY,
): ProjectState {
  const next = [...state.last_agent_results, result];
  return touch(state, {
    last_agent_results: next.length > max ? next.slice(next.length - max) : next,
  });
}

/** Build a decision-log entry with a generated id + timestamp. */
export function decisionEntry(input: {
  decision_type: DecisionType;
  summary: string;
  task_id?: string;
  reason?: string;
  references?: string[];
}): DecisionLogEntry {
  return { id: createId("dec"), ts: nowIso(), ...input };
}

// ---------------------------------------------------------------------------
// Store: thin persistence over the reducers.
// ---------------------------------------------------------------------------

export interface ProjectStateStore {
  getState(): ProjectState;
  /** Apply a pure reducer and keep the new state in memory (does not auto-save). */
  update(fn: (state: ProjectState) => ProjectState): ProjectState;
  /** Persist current in-memory state to disk (if a filePath was configured). */
  save(): void;
  /** (Re)load state from disk if present; otherwise keep current. */
  load(): ProjectState;
  readonly filePath?: string;
}

export interface StateStoreOptions {
  /** When omitted, the store is in-memory only (useful for tests). */
  filePath?: string;
  /** Initial state if no file exists. */
  seed?: ProjectState;
}

export function createStateStore(options: StateStoreOptions = {}): ProjectStateStore {
  const filePath = options.filePath;
  let state: ProjectState = options.seed ?? initialState();

  function load(): ProjectState {
    if (filePath && existsSync(filePath)) {
      const raw = readFileSync(filePath, "utf8");
      state = JSON.parse(raw) as ProjectState;
    }
    return state;
  }

  function save(): void {
    if (!filePath) return;
    mkdirSync(dirname(filePath), { recursive: true });
    writeFileSync(filePath, JSON.stringify(state, null, 2) + "\n", "utf8");
  }

  // Hydrate from disk on construction so restarts resume state.
  load();

  return {
    filePath,
    getState() {
      return state;
    },
    update(fn) {
      state = fn(state);
      return state;
    },
    save,
    load,
  };
}

// ---------------------------------------------------------------------------
// Consumption ledger — durable single-use record for command-bound approvals.
//
// This is the anti-replay substrate the dispatcher's single-use gate stands on. It is
// SEPARATE from ProjectState (approval consumption is security state, not product
// state) but lives in this authorized file to avoid a new unauthorized module.
//
// Durability contract: `tryConsume` is a SYNCHRONOUS test-and-set that WRITES THROUGH
// to disk BEFORE it returns true (no deferred save). Consumed ids therefore survive a
// process restart. Reload on construction rehydrates the set so a replay after restart
// is still rejected.
//
// Atomicity scope: SINGLE-PROCESS ATOMICITY ONLY. The check-and-insert has no `await`
// between reading membership and inserting, so within one Node process two concurrent
// dispatches of the same approval cannot both win. This makes NO cross-process claim —
// two processes over the same file could both consume (no OS-level file lock is taken).
// ---------------------------------------------------------------------------

export interface ConsumptionLedger {
  /**
   * Atomically claim an approval id for single use. Returns true on the FIRST consume
   * (durably persisted before return); false if already consumed (replay). Synchronous:
   * no await between the membership check and the insert.
   */
  tryConsume(approvalId: string): boolean;
  /** Whether an id has already been consumed (diagnostics/tests). */
  isConsumed(approvalId: string): boolean;
  /** Count of consumed ids (diagnostics/tests). */
  size(): number;
  readonly filePath?: string;
}

interface LedgerFile {
  version: 1;
  consumed: string[];
}

export interface ConsumptionLedgerOptions {
  /** When omitted, the ledger is in-memory only (useful for tests). */
  filePath?: string;
}

/**
 * Create a durable, write-through, single-use consumption ledger. If `filePath` is
 * given, consumed ids are persisted synchronously on each successful consume and reloaded
 * on construction (durable across restarts). If omitted, the ledger is in-memory only.
 */
export function createConsumptionLedger(
  options: ConsumptionLedgerOptions = {},
): ConsumptionLedger {
  const filePath = options.filePath;
  const consumed = new Set<string>();

  // Rehydrate from disk so a post-restart replay is still rejected.
  if (filePath && existsSync(filePath)) {
    try {
      const raw = readFileSync(filePath, "utf8");
      const parsed = JSON.parse(raw) as LedgerFile;
      if (parsed && Array.isArray(parsed.consumed)) {
        for (const id of parsed.consumed) {
          if (typeof id === "string") consumed.add(id);
        }
      }
    } catch {
      // A corrupt ledger must fail SAFE: treat as if everything is already consumed by
      // refusing to proceed would be too aggressive, but silently trusting an empty set
      // would enable replay. We rethrow so the operator sees it rather than silently
      // losing anti-replay durability.
      throw new Error(`consumption ledger at ${filePath} is unreadable/corrupt`);
    }
  }

  function persist(): void {
    if (!filePath) return;
    mkdirSync(dirname(filePath), { recursive: true });
    const payload: LedgerFile = { version: 1, consumed: [...consumed] };
    // Synchronous write-through: durable BEFORE tryConsume returns.
    writeFileSync(filePath, JSON.stringify(payload), "utf8");
  }

  return {
    filePath,
    tryConsume(approvalId: string): boolean {
      // Synchronous test-and-set — no await between check and insert.
      if (consumed.has(approvalId)) return false;
      consumed.add(approvalId);
      try {
        persist();
      } catch (e) {
        // If the durable write fails, roll back the in-memory claim so we never report
        // a consume that isn't durable (fail closed: caller sees false → no execution).
        consumed.delete(approvalId);
        throw e;
      }
      return true;
    },
    isConsumed(approvalId: string): boolean {
      return consumed.has(approvalId);
    },
    size(): number {
      return consumed.size;
    },
  };
}
