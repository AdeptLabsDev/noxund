import { test } from "node:test";
import assert from "node:assert/strict";
import {
  canonicalize,
  computePayloadDigest,
  computeCommandIdentity,
  CanonicalizationError,
} from "../src/core/command-identity.ts";

// ── Canonicalization: structure & ordering ─────────────────────────────────────

test("canonicalize sorts object keys (UTF-16 code unit) and preserves array order", () => {
  assert.equal(
    canonicalize({ b: 1, a: "x", c: [3, 2, 1] }),
    '{"a":"x","b":1,"c":[3,2,1]}',
  );
  assert.equal(canonicalize({}), "{}");
  assert.equal(canonicalize([]), "[]");
});

test("canonicalize serializes numbers per ECMAScript ToString, collapsing -0 to 0", () => {
  assert.equal(
    canonicalize({ n: -0, z: 0, big: 1e21, frac: 0.5, nul: null, t: true }),
    '{"big":1e+21,"frac":0.5,"n":0,"nul":null,"t":true,"z":0}',
  );
});

// ── Golden vectors (known payload → known digest). Frozen; a change here is a
//    wire-format break and must be intentional. ─────────────────────────────────

test("GOLDEN: payload digest for {b,a,c} object", () => {
  assert.equal(
    computePayloadDigest({ b: 1, a: "x", c: [3, 2, 1] }),
    "sha256:4cf3437ed02ed6dec44b34526fb8c076b116e871d37f93581f950e792b1a599f",
  );
});

test("GOLDEN: payload digest for empty object", () => {
  assert.equal(
    computePayloadDigest({}),
    "sha256:2d43faa9d1f3447d0528cafa51c504b0f6feeb2362e7e3a49a4fa206796fc29f",
  );
});

test("GOLDEN: payload digest for number/null/bool payload", () => {
  assert.equal(
    computePayloadDigest({ n: -0, z: 0, big: 1e21, frac: 0.5, nul: null, t: true }),
    "sha256:95afe02e9ee37d69ff3eaf1febef897179c31e0c71213dda5ae5cd2a0b3edd26",
  );
});

test("GOLDEN: command identity for the canonical migration command", () => {
  const id = computeCommandIdentity({
    task_id: "task_mig",
    target_agent: "database_agent",
    action: "run_migration",
    payload: { migration: "m" },
  });
  assert.equal(
    id.payload_digest,
    "sha256:10597da5247a924edd7e94dd7c852491db44d2c7b82163f2968b251bb2310950",
  );
  assert.equal(
    id.command_identity,
    "69d9949fc265463d438176deb3f7c4c7fab616d7164e37ba88b1216f7bf662a7",
  );
});

// ── Determinism & sensitivity ──────────────────────────────────────────────────

test("equal key-order permutations produce the SAME digest", () => {
  const a = computePayloadDigest({ b: 1, a: "x", c: [3, 2, 1] });
  const b = computePayloadDigest({ c: [3, 2, 1], a: "x", b: 1 });
  assert.equal(a, b);
});

test("array-order change produces a DIFFERENT digest", () => {
  const a = computePayloadDigest({ c: [1, 2, 3] });
  const b = computePayloadDigest({ c: [3, 2, 1] });
  assert.notEqual(a, b);
});

test("nested semantic change produces a DIFFERENT digest", () => {
  const a = computePayloadDigest({ x: { y: { z: 1 } } });
  const b = computePayloadDigest({ x: { y: { z: 2 } } });
  assert.notEqual(a, b);
});

test("Unicode compositions (NFC vs NFD) remain DISTINCT (no normalization)", () => {
  const composed = computePayloadDigest({ s: "é" }); // é precomposed
  const decomposed = computePayloadDigest({ s: "é" }); // e + combining acute
  assert.notEqual(composed, decomposed);
});

test("command_identity changes when any of task_id/target_agent/action/payload changes", () => {
  const base = computeCommandIdentity({
    task_id: "t", target_agent: "a", action: "x", payload: { p: 1 },
  }).command_identity;
  assert.notEqual(
    base,
    computeCommandIdentity({ task_id: "t2", target_agent: "a", action: "x", payload: { p: 1 } }).command_identity,
  );
  assert.notEqual(
    base,
    computeCommandIdentity({ task_id: "t", target_agent: "a2", action: "x", payload: { p: 1 } }).command_identity,
  );
  assert.notEqual(
    base,
    computeCommandIdentity({ task_id: "t", target_agent: "a", action: "x2", payload: { p: 1 } }).command_identity,
  );
  assert.notEqual(
    base,
    computeCommandIdentity({ task_id: "t", target_agent: "a", action: "x", payload: { p: 2 } }).command_identity,
  );
});

test("0x1F framing prevents field-boundary collisions", () => {
  // Without framing, ("ab","c") and ("a","bc") could collide when concatenated.
  const a = computeCommandIdentity({ task_id: "ab", target_agent: "c", action: "x", payload: {} }).command_identity;
  const b = computeCommandIdentity({ task_id: "a", target_agent: "bc", action: "x", payload: {} }).command_identity;
  assert.notEqual(a, b);
});

// ── Fail-closed on unsupported values ──────────────────────────────────────────

test("canonicalize FAILS CLOSED on undefined, functions, symbols, bigint", () => {
  assert.throws(() => canonicalize(undefined), CanonicalizationError);
  assert.throws(() => canonicalize({ f: () => 1 }), CanonicalizationError);
  assert.throws(() => canonicalize({ s: Symbol("x") }), CanonicalizationError);
  assert.throws(() => canonicalize({ b: 10n }), CanonicalizationError);
});

test("canonicalize FAILS CLOSED on NaN and Infinity", () => {
  assert.throws(() => canonicalize({ n: NaN }), CanonicalizationError);
  assert.throws(() => canonicalize({ n: Infinity }), CanonicalizationError);
  assert.throws(() => canonicalize({ n: -Infinity }), CanonicalizationError);
});

test("canonicalize FAILS CLOSED on undefined object values and array holes", () => {
  assert.throws(() => canonicalize({ a: undefined }), CanonicalizationError);
  // Array hole reads as undefined → fail closed.
  // eslint-disable-next-line no-sparse-arrays
  assert.throws(() => canonicalize([1, , 3]), CanonicalizationError);
});

test("canonicalize FAILS CLOSED on non-plain objects (Date, Map, Set, class instances)", () => {
  assert.throws(() => canonicalize(new Date()), CanonicalizationError);
  assert.throws(() => canonicalize(new Map()), CanonicalizationError);
  assert.throws(() => canonicalize(new Set()), CanonicalizationError);
  class Foo { x = 1; }
  assert.throws(() => canonicalize(new Foo()), CanonicalizationError);
});

test("canonicalize FAILS CLOSED on circular structures", () => {
  const obj: Record<string, unknown> = { a: 1 };
  obj.self = obj;
  assert.throws(() => canonicalize(obj), CanonicalizationError);

  const arr: unknown[] = [1];
  arr.push(arr);
  assert.throws(() => canonicalize(arr), CanonicalizationError);
});

test("null-prototype plain objects are accepted (data objects)", () => {
  const o = Object.create(null) as Record<string, unknown>;
  o.a = 1;
  assert.equal(canonicalize(o), '{"a":1}');
});
