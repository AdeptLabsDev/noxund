#!/usr/bin/env bash
# P3B — generate the two disposable spike secrets (gitignored, 0600, NO trailing
# newline so psql and the JDBC/scram path see byte-identical values). Idempotent:
# never overwrites an existing secret within the same run window.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDIR="$HERE/.local-secrets"
mkdir -p "$SDIR"
chmod 700 "$SDIR" 2>/dev/null || true

gen(){ LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 40; }

for name in postgres_password noxund_migrator_password; do
  f="$SDIR/$name"
  if [ ! -s "$f" ]; then
    printf '%s' "$(gen)" > "$f"
  fi
  chmod 600 "$f" 2>/dev/null || true
done
echo "P3B secrets ready in $SDIR (0600, gitignored)."
