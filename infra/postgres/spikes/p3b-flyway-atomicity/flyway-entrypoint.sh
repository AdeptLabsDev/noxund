#!/usr/bin/env bash
# =============================================================================
# NOXUND P3B — Flyway entrypoint wrapper. TWO jobs, one choke point:
#
#   1) EXECUTABLE SENTINEL — refuse clean / repair / baseline / undo. Every Flyway
#      invocation in this spike passes through here, so these commands cannot run.
#
#   2) SECRET INJECTION — read the migrator password from the Compose secret at
#      exec time ONLY: never printed, never persisted, symlink + insecure perms
#      refused. Exported to FLYWAY_PASSWORD for the immediate flyway child only
#      (never in Compose, never in `docker inspect` config, never in Git).
#
# NO `set -x` — would leak the secret.
# =============================================================================
set -euo pipefail

# --- 1. sentinel: forbidden subcommands ---
for a in "$@"; do
  case "$a" in
    clean|repair|baseline|undo)
      echo "P3B SENTINEL: forbidden Flyway command '$a' — clean/repair/baseline/undo are prohibited." >&2
      exit 90
      ;;
  esac
done

# --- 2. secret injection ---
SECRET="/run/secrets/noxund_migrator_password"
[ -e "$SECRET" ]  || { echo "P3B FATAL: secret missing: $SECRET" >&2; exit 91; }
[ ! -L "$SECRET" ] || { echo "P3B FATAL: secret is a symlink (refused): $SECRET" >&2; exit 92; }
[ -f "$SECRET" ]  || { echo "P3B FATAL: secret is not a regular file: $SECRET" >&2; exit 93; }
# Insecure-perms guard. On real POSIX filesystems (Linux / CI — where the future
# runner will actually live) reject group/other-writable, fail-closed. On 9p /
# virtiofs / drvfs bind mounts (Docker Desktop on Windows/macOS) the in-container
# mode bits are a translation artifact (always shown 0777) and are NOT a real
# signal — there the ACL boundary is the host secret dir (created 0700, file 0600
# by harness/gen-secrets.sh), so the perm-bit check is deferred, not skipped blindly.
FSTYPE="$(stat -f -c '%T' "$SECRET" 2>/dev/null || echo unknown)"
case "$FSTYPE" in
  9p|v9fs|virtiofs|drvfs|cifs|smbfs|smb2|fuseblk|unknown)
    echo "P3B note: secret on '${FSTYPE}' bind mount — perm bits are host-translated; relying on host ACL (0600/0700)." >&2
    ;;
  *)
    if [ -n "$(find "$SECRET" -perm /022 2>/dev/null)" ]; then
      echo "P3B FATAL: insecure secret perms (group/other-writable) on ${FSTYPE}: $SECRET" >&2
      exit 94
    fi
    ;;
esac

FLYWAY_PASSWORD="$(cat "$SECRET")"
export FLYWAY_PASSWORD
unset SECRET

exec /flyway/flyway "$@"
