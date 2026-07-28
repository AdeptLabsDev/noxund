#!/usr/bin/env bash
# ============================================================================
# NOXUND · SG-8 R0 — evaluate the read-only preflight OUTPUT (single source of
# truth for BOTH the workflow and the local/unit tests). Pure text processing:
# reads no DB, holds no secret, makes no network call.
# ----------------------------------------------------------------------------
# Args:
#   $1 psql_output_file  — captured stdout of sg8_r0_preflight_pre_0008.sql
#   $2 migrations_dir     — the checkout's supabase/migrations directory
#   $3 backup_ok           — 'true' iff operator backup evidence is complete
# Emits (stdout, sanitized — no URL/password/token by construction):
#   R0_TECHNICAL_DB_VERDICT=... · R0_LEDGER_SET_OK=... · R0_BACKUP_EVIDENCE_OK=...
#   R0_REMOTE_LEDGER=... · R0_DIGEST=<sha256> · R0_FINAL=GREEN|RED
# Exit: 0 iff R0_FINAL=GREEN, else 1 (usage/parse error → 2).
#
# DIGEST is a function of REMOTE DB STATE + checkout ledger set ONLY (canonical
# decision vector + ledger + ledger-set-ok + db-verdict). It EXCLUDES operator
# backup input and all volatile fields → identical across runs on the same state.
# FINAL verdict is GREEN xor RED (never "GREEN with notes"); backup gates FINAL,
# not the digest.
# ============================================================================
set -euo pipefail

out="${1:?usage: r0_evaluate.sh <psql_output> <migrations_dir> <backup_ok>}"
migdir="${2:?missing migrations_dir}"
backup_ok="${3:?missing backup_ok (true|false)}"

canon="$(awk '/^R0-CANON-START$/{f=1;next}/^R0-CANON-END$/{f=0}f' "$out" | sed '/^$/d')"
ledger="$(awk '/^R0-LEDGER-START$/{f=1;next}/^R0-LEDGER-END$/{f=0}f' "$out" | sed '/^$/d')"
db_verdict="$(grep -oE 'R0_VERDICT=(GREEN|RED)' "$out" | head -1 | cut -d= -f2 || true)"
[ -n "$db_verdict" ] || { echo "::error::no R0_VERDICT in $out — preflight incomplete"; exit 2; }
[ -n "$canon" ]      || { echo "::error::no R0-CANON block in $out"; exit 2; }

checkout_versions="$(for fx in "$migdir"/*.sql; do [ -e "$fx" ] || continue; b="$(basename "$fx")"; echo "${b%%_*}"; done \
                       | grep -E '^[0-9]{14}$' | sort -u || true)"
remote_versions="$(printf '%s\n' "$ledger" | grep -E '^[0-9]{14}$' | sort -u || true)"

# --- ledger-set checks (deterministic: repo checkout vs remote ledger) ---
v0008_absent=true; v0009_absent=true
printf '%s\n' "$remote_versions" | grep -qx '20260620000008' && v0008_absent=false || true
printf '%s\n' "$remote_versions" | grep -qx '20260620000009' && v0009_absent=false || true
unknown_remote="$(comm -23 <(printf '%s\n' "$remote_versions") <(printf '%s\n' "$checkout_versions") || true)"
missing_remote="$(comm -13 <(printf '%s\n' "$remote_versions") <(printf '%s\n' "$checkout_versions") \
                    | grep -vxE '20260620000008|20260620000009' || true)"

ledger_set_ok=true; reasons=""
[ "$v0008_absent" = true ] || { ledger_set_ok=false; reasons+="0008-in-ledger; "; }
[ "$v0009_absent" = true ] || { ledger_set_ok=false; reasons+="0009-in-ledger; "; }
[ -z "$unknown_remote" ]   || { ledger_set_ok=false; reasons+="unknown-remote:[${unknown_remote//$'\n'/,}]; "; }
[ -z "$missing_remote" ]   || { ledger_set_ok=false; reasons+="pending-outside-0008-0009:[${missing_remote//$'\n'/,}]; "; }

# --- deterministic digest (DB state + ledger set only; NOT backup, NOT volatile) ---
canon_norm="$(printf '%s\n' "$canon" | sort)"
ledger_join="$(printf '%s\n' "$remote_versions" | paste -sd, - || true)"
digest="$(printf 'CANON\n%s\nLEDGER=%s\nLEDGER_SET_OK=%s\nDB_VERDICT=%s\n' \
            "$canon_norm" "$ledger_join" "$ledger_set_ok" "$db_verdict" | sha256sum | cut -d' ' -f1)"

# --- final verdict (fail-closed; backup RED-default) ---
final=RED
if [ "$db_verdict" = GREEN ] && [ "$ledger_set_ok" = true ] && [ "$backup_ok" = true ]; then
  final=GREEN
fi

echo "R0_TECHNICAL_DB_VERDICT=$db_verdict"
echo "R0_LEDGER_SET_OK=$ledger_set_ok${reasons:+ ($reasons)}"
echo "R0_BACKUP_EVIDENCE_OK=$backup_ok"
echo "R0_REMOTE_LEDGER=${ledger_join:-<none>}"
echo "R0_DIGEST=$digest"
echo "R0_FINAL=$final"

[ "$final" = GREEN ] && exit 0 || exit 1
