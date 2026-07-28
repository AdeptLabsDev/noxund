#!/usr/bin/env bash
# ============================================================================
# NOXUND · SG-8 R0 — DB-FREE unit test for r0_evaluate.sh.
# Proves the RUNNER-SIDE logic with SYNTHETIC psql-output fixtures (no Docker,
# no DB, no network): ledger-set determinism, unrelated-pending → RED, unknown
# remote → RED, 0008/0009-in-ledger → RED, backup RED-default, digest identical
# ×2 on the same state, sanitized output. The Docker-backed supabase integration
# (transaction_read_only / write-probe 25006 / real object GREEN·RED) is covered
# separately by r0_preflight_local_test.sh.
# ============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; cd "$ROOT"
EVAL="supabase/remote/r0_evaluate.sh"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { echo "  PASS: $1"; pass=$((pass+1)); }
bad() { echo "  FAIL: $1"; fail=$((fail+1)); }

# ---- fixtures --------------------------------------------------------------
mk_migdir() { # $1=dir  $2..=extra 14-digit versions
  local d="$1"; shift; mkdir -p "$d"
  for v in 20260620000001 20260620000002 20260620000003 20260620000004 20260620000005 20260620000006 "$@"; do
    : > "$d/${v}_x.sql"
  done
}
mk_output() { # $1=file  $2=db_verdict  $3..=ledger versions
  local f="$1" verdict="$2"; shift 2
  {
    echo "== §1 identity (host/port here would be non-secret) =="
    echo "R0-CANON-START"
    printf '%s\n' "pg_major=15" "pg_major_ok=true" "tables_absent=true" "writer_absent=true" \
                  "uuid_present=true" "uuid_no_shadowing=true" "acl_uuid_public_execute=true" \
                  "ledger_present=true" "env_ref_ok=true" | sort
    echo "R0-CANON-END"
    echo "R0-LEDGER-START"; for v in "$@"; do echo "$v"; done; echo "R0-LEDGER-END"
    echo "R0_VERDICT=$verdict"
  } > "$f"
}

run_eval() { bash "$EVAL" "$1" "$2" "$3"; }           # out migdir backup_ok
final_of() { run_eval "$@" 2>/dev/null | grep -oE 'R0_FINAL=(GREEN|RED)' | cut -d= -f2 || true; }
digest_of(){ run_eval "$@" 2>/dev/null | grep -oE 'R0_DIGEST=[0-9a-f]{64}' | cut -d= -f2 || true; }

MIG="$WORK/mig"; mk_migdir "$MIG"                                  # 0001..0006

# T1 — GREEN: pre-0008 state (ledger 0001..0006), backup complete
mk_output "$WORK/green.txt" GREEN 20260620000001 20260620000002 20260620000003 20260620000004 20260620000005 20260620000006
[ "$(final_of "$WORK/green.txt" "$MIG" true)" = GREEN ] && ok "T1 GREEN (pre-0008 + backup ok)" || bad "T1 expected GREEN"

# T2 — backup RED-default: same technical GREEN but backup_ok=false ⇒ RED
[ "$(final_of "$WORK/green.txt" "$MIG" false)" = RED ] && ok "T2 backup missing ⇒ RED (no TECHNICAL_GREEN authorization)" || bad "T2 expected RED"

# T3 — 0008 present in ledger ⇒ RED
mk_output "$WORK/l8.txt" GREEN 20260620000001 20260620000006 20260620000008
[ "$(final_of "$WORK/l8.txt" "$MIG" true)" = RED ] && ok "T3 0008-in-ledger ⇒ RED" || bad "T3 expected RED"

# T4 — unrelated PENDING migration in checkout but not ledger ⇒ RED
MIG7="$WORK/mig7"; mk_migdir "$MIG7" 20260620000007                # adds unrelated 0007 to checkout
mk_output "$WORK/l6.txt" GREEN 20260620000001 20260620000002 20260620000003 20260620000004 20260620000005 20260620000006
[ "$(final_of "$WORK/l6.txt" "$MIG7" true)" = RED ] && ok "T4 unrelated pending (0007) ⇒ RED" || bad "T4 expected RED"

# T5 — unknown REMOTE version (in ledger, not in checkout) ⇒ RED
mk_output "$WORK/lu.txt" GREEN 20260620000001 20260620000006 20269999999999
[ "$(final_of "$WORK/lu.txt" "$MIG" true)" = RED ] && ok "T5 unknown-remote ⇒ RED" || bad "T5 expected RED"

# T6 — DB-side RED (e.g., object present) ⇒ RED regardless of ledger/backup
mk_output "$WORK/dbred.txt" RED 20260620000001 20260620000006
[ "$(final_of "$WORK/dbred.txt" "$MIG" true)" = RED ] && ok "T6 db_verdict=RED ⇒ RED" || bad "T6 expected RED"

# T7 — digest determinism: identical inputs ⇒ identical digest (×2)
d1="$(digest_of "$WORK/green.txt" "$MIG" true)"; d2="$(digest_of "$WORK/green.txt" "$MIG" true)"
[ -n "$d1" ] && [ "$d1" = "$d2" ] && ok "T7 digest identical ×2 ($d1)" || bad "T7 digest not stable ($d1 vs $d2)"

# T8 — digest ignores backup input (state-only): backup true vs false ⇒ same digest
d3="$(digest_of "$WORK/green.txt" "$MIG" false)"
[ "$d1" = "$d3" ] && ok "T8 digest independent of backup input" || bad "T8 digest changed with backup ($d1 vs $d3)"

# T9 — sanitized: evaluate output carries no URL/password/token
out="$(run_eval "$WORK/green.txt" "$MIG" true || true)"
echo "$out" | grep -qiE 'postgres(ql)?://|password|sslmode|token|@.*:.*@' && bad "T9 output not sanitized" || ok "T9 output sanitized (no URL/password/token)"

echo ""
echo "r0_evaluate unit: PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ] || exit 1
