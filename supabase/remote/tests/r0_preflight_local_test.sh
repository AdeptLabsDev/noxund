#!/usr/bin/env bash
# ============================================================================
# NOXUND · SG-8 R0 preflight — LOCAL disposable-DB integration test (NO remote).
# ----------------------------------------------------------------------------
# Exercises the FULL path (SQL + r0_evaluate.sh) against a DISPOSABLE LOCAL
# Supabase stack — the parts that need a real PostgreSQL 15 + Supabase roles:
#   (A) PRE-0008  — 0008/0009 relocated out so `supabase start` applies ONLY
#       0001..0006; ledger lacks 0008/0009, no SG-8 object exists → GREEN
#       (with backup evidence) and RED (backup default).
#   (B) FULL      — all migrations applied → RED.
#   boundary      — transaction_read_only=on; write-probe SQLSTATE 25006 caught
#                   without aborting the rest; digest identical ×2 on same state.
#
# The DB-FREE runner-side logic (unrelated-pending → RED, unknown-remote → RED,
# digest determinism, backup RED-default, sanitized output) is proven WITHOUT
# Docker by supabase/remote/tests/r0_evaluate_unit_test.sh.
#
# Requires: docker + PINNED supabase CLI (config.toml) + psql (PG15). Talks ONLY
# to loopback 127.0.0.1:54322. NO `supabase link`, NO remote token, NO prod URL/
# password. Applies NOTHING to any remote. Restores relocated files + stops the
# stack on exit; the working tree ends clean.
# ============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; cd "$ROOT"

DBURL="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
SQL="supabase/remote/sg8_r0_preflight_pre_0008.sql"
EVAL="supabase/remote/r0_evaluate.sh"
MIGDIR="supabase/migrations"
M8="$MIGDIR/20260620000008_sg8_reconciliation_session.sql"
M9="$MIGDIR/20260620000009_sg8_runtime_identity_grants_rls.sql"
HOLD="$(mktemp -d)"

cleanup() {
  [ -f "$HOLD/$(basename "$M8")" ] && mv -f "$HOLD/$(basename "$M8")" "$M8" || true
  [ -f "$HOLD/$(basename "$M9")" ] && mv -f "$HOLD/$(basename "$M9")" "$M9" || true
  supabase stop --no-backup >/dev/null 2>&1 || true
  rm -rf "$HOLD" || true
  # remove os transcripts .txt gerados na raiz do repo (higiene: working tree limpa)
  rm -f "$ROOT/r0_local_pre0008.txt" "$ROOT/r0_local_pre0008_b.txt" "$ROOT/r0_local_full.txt" || true
  # working tree must end clean (relocations undone)
  if ! git diff --quiet -- "$MIGDIR"; then echo "HYGIENE FAIL: migrations dir dirty after test"; fi
}
trap cleanup EXIT

run_preflight() { # $1 = output file
  # 2>&1 → stderr (NOTICE/erros) também entra no transcript; `set -o pipefail` (topo)
  # garante que uma FALHA do psql (exit != 0) propaga pelo pipe — um `tee` bem-sucedido
  # NUNCA mascara falha de SQL. As provas de fronteira são os MARCADORES MÁQUINA em
  # stdout (R0_ASSERT|...), não as frases de RAISE NOTICE (que o psql envia a stderr).
  psql "$DBURL" -v ON_ERROR_STOP=1 -v expected_ref=LOCAL -v expected_host=LOCAL -f "$SQL" 2>&1 | tee "$1"
}
final_backup()  { bash "$EVAL" "$1" "$MIGDIR" "$2" | grep -oE 'R0_FINAL=(GREEN|RED)' | cut -d= -f2 || true; }
digest_of()     { bash "$EVAL" "$1" "$MIGDIR" true | grep -oE 'R0_DIGEST=[0-9a-f]{64}' | cut -d= -f2 || true; }
assert_grep()   { grep -qE "$1" "$2" || { echo "FAIL: expected /$1/ in $2"; exit 1; }; }
# assert_marker: whole-line FIXED-string match on a machine marker (o '|' é literal,
# nunca alternância de regex). Consome exatamente os marcadores R0_ASSERT|... do SQL.
assert_marker() { grep -Fxq "$1" "$2" || { echo "FAIL: expected machine marker [$1] in $2"; exit 1; }; }

echo "== (A) PRE-0008 — relocate 0008/0009, apply 0001..0006 =="
mv -f "$M8" "$HOLD/"; mv -f "$M9" "$HOLD/"
supabase stop --no-backup >/dev/null 2>&1 || true
supabase start
run_preflight r0_local_pre0008.txt
# Provas de FRONTEIRA via MARCADORES MÁQUINA (stdout), emitidos só após validação:
assert_marker 'R0_ASSERT|transaction_read_only|on'   r0_local_pre0008.txt  # txn READ ONLY confirmada
assert_marker 'R0_ASSERT|write_probe_sqlstate|25006' r0_local_pre0008.txt  # write-probe caught c/ EXATAMENTE 25006
assert_marker 'R0_ASSERT|readonly_boundary|enforced' r0_local_pre0008.txt  # fronteira só após as duas provas
assert_grep   'R0_VERDICT=GREEN'                     r0_local_pre0008.txt  # DB-side GREEN (SELECT, stdout)
# restore files BEFORE evaluate so the checkout migration set is complete for the ledger comparison
mv -f "$HOLD/$(basename "$M8")" "$M8"; mv -f "$HOLD/$(basename "$M9")" "$M9"
[ "$(final_backup r0_local_pre0008.txt true)"  = GREEN ] && echo "PASS A1: FINAL GREEN with backup evidence" || { echo "FAIL A1"; exit 1; }
[ "$(final_backup r0_local_pre0008.txt false)" = RED   ] && echo "PASS A2: FINAL RED when backup evidence absent (RED-default)" || { echo "FAIL A2"; exit 1; }
# digest identical ×2 on the SAME state
run_preflight r0_local_pre0008_b.txt >/dev/null
d1="$(digest_of r0_local_pre0008.txt)"; d2="$(digest_of r0_local_pre0008_b.txt)"
[ -n "$d1" ] && [ "$d1" = "$d2" ] && echo "PASS A3: digest identical ×2 ($d1)" || { echo "FAIL A3: $d1 vs $d2"; exit 1; }

echo "== (B) FULL — apply ALL migrations (incl. 0008/0009) =="
supabase db reset
run_preflight r0_local_full.txt
assert_marker 'R0_ASSERT|transaction_read_only|on'   r0_local_full.txt
assert_marker 'R0_ASSERT|write_probe_sqlstate|25006' r0_local_full.txt
assert_marker 'R0_ASSERT|readonly_boundary|enforced' r0_local_full.txt
assert_grep   'R0_VERDICT=RED'                        r0_local_full.txt     # SG-8 objetos presentes ⇒ RED
[ "$(final_backup r0_local_full.txt true)" = RED ] && echo "PASS B1: FINAL RED once SG-8 present" || { echo "FAIL B1"; exit 1; }

echo "ALL R0 LOCAL INTEGRATION TESTS PASSED (pre-0008 GREEN/backup-gate/digest×2 + full RED; boundary proven)."
