// Deterministic-ish id + timestamp helpers for the orchestration control plane.
// No external dependency: ids are sortable (time-prefixed) and collision-resistant
// enough for a single-process control plane. They are NOT security tokens.

let monotonicCounter = 0;

/** ISO-8601 UTC timestamp. Single source of "now" for the whole control plane. */
export function nowIso(): string {
  return new Date().toISOString();
}

/**
 * Create a sortable, prefixed id, e.g. `task_lq9f2k_0007_a3f9`.
 * - time component keeps ids chronologically sortable;
 * - counter component disambiguates ids created in the same millisecond;
 * - random suffix avoids collisions across processes.
 */
export function createId(prefix: string): string {
  const time = Date.now().toString(36);
  const seq = (monotonicCounter++ % 0xffff).toString(36).padStart(4, "0");
  const rand = Math.floor(Math.random() * 0xffff)
    .toString(36)
    .padStart(3, "0");
  return `${prefix}_${time}_${seq}_${rand}`;
}

/** Convenience: a fresh task id (`task_...`). */
export function newTaskId(): string {
  return createId("task");
}
