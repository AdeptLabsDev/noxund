#!/usr/bin/env bash
# ============================================================================
# NOXUND · SG-8 R0 preflight — LOCAL disposable-DB test (NO remote, NO secrets).
# ----------------------------------------------------------------------------
# Validates supabase/remote/sg8_r0_preflight_pre_0008.sql against a DISPOSABLE
# LOCAL Supabase stack in TWO states:
#   (A) PRE-0008  — migrations 0008/0009 temporarily relocated out of
#       supabase/migrations/ so `supabase start` applies ONLY 0001..0006. The
#       ledger truly lacks 0008/0009 and no SG-8 object exists → expect GREEN.
#   (B) FULL      — all migrations applied (incl. 0008/0009) → expect RED.
#
# The LOCAL sentinel (expected_ref=LOCAL) disables ONLY the remote-identity match;
# the remote workflow ALWAYS passes the real project ref, never LOCAL.
#
# Requires: docker + supabase CLI + psql (same toolchain as the hermetic harness).
# Talks ONLY to loopback 127.0.0.1:54322. Applies NOTHING to any remote.
# Idempotent cleanup: relocated files are restored and the stack stopped on exit.
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

DBURL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
SQL="supabase/remote/sg8_r0_preflight_pre_0008.sql"
HOLD="$(mktemp -d)"
M8="supabase/migrations/20260620000008_sg8_reconciliation_session.sql"
M9="supabase/migrations/20260620000009_sg8_runtime_identity_grants_rls.sql"

cleanup() {
  # restore relocated migrations no matter what
  [ -f "$HOLD/$(basename "$M8")" ] && mv -f "$HOLD/$(basename "$M8")" "$M8" || true
  [ -f "$HOLD/$(basename "$M9")" ] && mv -f "$HOLD/$(basename "$M9")" "$M9" || true
  supabase stop --no-backup >/dev/null 2>&1 || true
  rm -rf "$HOLD" || true
}
trap cleanup EXIT

run_preflight() { psql "$DBURL" -v ON_ERROR_STOP=1 -v expected_ref=LOCAL -v expected_host=LOCAL -f "$SQL"; }

assert_grep()  { grep -qE "$1" "$2" || { echo "FAIL: expected /$1/ in $2"; exit 1; }; }
refute_grep()  { grep -qE "$1" "$2" && { echo "FAIL: did NOT expect /$1/ in $2"; exit 1; } || true; }

echo "== (A) PRE-0008 state — relocate 0008/0009, apply 0001..0006, expect GREEN =="
mv -f "$M8" "$HOLD/" ; mv -f "$M9" "$HOLD/"
supabase stop --no-backup >/dev/null 2>&1 || true
supabase start
run_preflight | tee r0_local_pre0008.txt
assert_grep 'transaction_read_only=on'            r0_local_pre0008.txt
assert_grep 'fronteira enforçada'                 r0_local_pre0008.txt   # write probe rejected (25006)
assert_grep 'R0_VERDICT=GREEN'                    r0_local_pre0008.txt
# ledger must NOT contain the SG-8 targets in this state
ledger="$(awk '/^R0-LEDGER-START$/{f=1;next}/^R0-LEDGER-END$/{f=0}f' r0_local_pre0008.txt | sed '/^$/d')"
printf '%s\n' "$ledger" | grep -qx '20260620000008' && { echo "FAIL: 0008 in pre-0008 ledger"; exit 1; } || true
printf '%s\n' "$ledger" | grep -qx '20260620000009' && { echo "FAIL: 0009 in pre-0008 ledger"; exit 1; } || true
echo "PASS (A): GREEN in pre-0008 state; boundary enforced; ledger clean."

# restore + reset to FULL state
mv -f "$HOLD/$(basename "$M8")" "$M8" ; mv -f "$HOLD/$(basename "$M9")" "$M9"

echo "== (B) FULL state — apply ALL migrations (incl. 0008/0009), expect RED =="
supabase db reset
run_preflight | tee r0_local_full.txt
assert_grep 'transaction_read_only=on'            r0_local_full.txt
assert_grep 'fronteira enforçada'                 r0_local_full.txt
assert_grep 'R0_VERDICT=RED'                      r0_local_full.txt
echo "PASS (B): RED once SG-8 objects/ledger are present."

echo "ALL R0 LOCAL TESTS PASSED (pre-0008 GREEN + full RED; read-only boundary proven)."
