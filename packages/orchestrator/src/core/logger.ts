// Structured logging — the terminal stops being the operational center and becomes
// a pure observation layer. Every decision, validation, dispatch, result, block and
// human-approval gate is emitted as a JSONL record (machine-readable) and, optionally,
// a concise human line to the console. Sinks are injectable so tests capture in memory.

import { appendFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { nowIso } from "./ids.ts";

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogRecord {
  ts: string;
  level: LogLevel;
  event: string;
  [key: string]: unknown;
}

export interface LogSink {
  write(record: LogRecord): void;
}

/** Appends one JSON object per line to a file (JSONL). Creates the dir if needed. */
export function fileSink(filePath: string): LogSink {
  let ensured = false;
  return {
    write(record) {
      if (!ensured) {
        mkdirSync(dirname(filePath), { recursive: true });
        ensured = true;
      }
      appendFileSync(filePath, JSON.stringify(record) + "\n", "utf8");
    },
  };
}

/** Prints a concise, human-readable one-liner per event to stdout/stderr. */
export function consoleSink(): LogSink {
  return {
    write(record) {
      const { ts, level, event, ...rest } = record;
      const summary =
        typeof rest.summary === "string"
          ? ` ${rest.summary}`
          : Object.keys(rest).length > 0
            ? " " + compact(rest)
            : "";
      const line = `${ts} ${level.toUpperCase().padEnd(5)} ${event}${summary}\n`;
      if (level === "error" || level === "warn") process.stderr.write(line);
      else process.stdout.write(line);
    },
  };
}

function compact(data: Record<string, unknown>): string {
  return Object.entries(data)
    .map(([k, v]) => `${k}=${typeof v === "string" ? v : JSON.stringify(v)}`)
    .join(" ");
}

export interface MemorySink extends LogSink {
  records: LogRecord[];
}

/** Captures records in memory for assertions in tests. */
export function memorySink(): MemorySink {
  const records: LogRecord[] = [];
  return {
    records,
    write(record) {
      records.push(record);
    },
  };
}

export interface Logger {
  log(level: LogLevel, event: string, data?: Record<string, unknown>): void;
  debug(event: string, data?: Record<string, unknown>): void;
  info(event: string, data?: Record<string, unknown>): void;
  warn(event: string, data?: Record<string, unknown>): void;
  error(event: string, data?: Record<string, unknown>): void;
  /** Returns a logger that injects `context` into every record. */
  child(context: Record<string, unknown>): Logger;
}

export interface LoggerOptions {
  sinks: LogSink[];
  context?: Record<string, unknown>;
}

export function createLogger(options: LoggerOptions): Logger {
  const { sinks, context = {} } = options;

  function emit(level: LogLevel, event: string, data?: Record<string, unknown>): void {
    const record: LogRecord = { ts: nowIso(), level, event, ...context, ...data };
    for (const sink of sinks) sink.write(record);
  }

  return {
    log: emit,
    debug: (event, data) => emit("debug", event, data),
    info: (event, data) => emit("info", event, data),
    warn: (event, data) => emit("warn", event, data),
    error: (event, data) => emit("error", event, data),
    child(childContext) {
      return createLogger({ sinks, context: { ...context, ...childContext } });
    },
  };
}

/** A logger that discards everything (safe default when none is provided). */
export function nullLogger(): Logger {
  return createLogger({ sinks: [] });
}
