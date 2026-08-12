#!/usr/bin/env bash
# =============================================================================
# secret-scan.sh — scan the harness subtree for accidentally-committed secrets,
# using ONLY tools already present (git + grep). No installation. Read-only.
# Intended to be run against the written diff before any commit (future gate).
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Patterns that must NEVER appear in tracked files. Ephemeral secrets live under
# .ephemeral/ (gitignored) and evidence/ (gitignored) and are excluded.
PATTERNS='(BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY|password\s*=\s*["'"'"'][^"'"'"']+|PGPASSWORD=|AKIA[0-9A-Z]{16}|xox[baprs]-|-----BEGIN|secret_key\s*[:=])'

echo "secret-scan: scanning ${HERE} (excluding .ephemeral/, evidence/, __pycache__/)"
HITS="$(grep -RInE --binary-files=without-match \
  --exclude-dir=.ephemeral --exclude-dir=evidence --exclude-dir=__pycache__ \
  --exclude='*.pqtrace' \
  "${PATTERNS}" "${HERE}" 2>/dev/null || true)"

# Allow documented, non-secret example placeholders (none expected).
if [[ -n "${HITS}" ]]; then
  echo "POTENTIAL SECRETS FOUND:" >&2
  echo "${HITS}" >&2
  exit 1
fi
echo "secret-scan: clean (no secret patterns in tracked harness files)"
