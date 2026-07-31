#!/usr/bin/env bash
# =============================================================================
# NOXUND — PG-EXIT-P2 reproducible local-stack test (versioned).
# Drives the COMMITTED scripts through every P2 assertion + negative, on a
# throwaway ext4 copy under a UNIQUE Compose project — so it works from a
# /mnt/c (NTFS) checkout, keeps the repo working tree untouched, and NEVER
# removes the developer's normal `noxund-local` volume. Callable by P6 CI
# without rewrite (no GitHub workflow here).
#
#   Cleanup (trap): down -v of the TEST projects only + remove the temp dir.
#   NEVER `docker volume prune`. Strictly local (no remote daemon).
# =============================================================================
set -uo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
INFRA_SRC="$(cd "${SELF}/.." && pwd)"                 # infra/postgres
WORK="$(mktemp -d)"; DST="${WORK}/infra/postgres"
PN="noxund-p2test-$$"; PN2="noxund-p2iso-$$"
F=0; ok(){ echo "PASS  $1"; }; no(){ echo "FAIL  $1"; F=$((F+1)); }

# throwaway copy (excludes .local-secrets + tests); gets real POSIX perms on ext4/tmpfs.
mkdir -p "${DST}"
cp -r "${INFRA_SRC}/compose.local.yml" "${INFRA_SRC}/.env.example" "${INFRA_SRC}/README.md" \
      "${INFRA_SRC}/init" "${INFRA_SRC}/init-entrypoint.sh" "${INFRA_SRC}/scripts" "${DST}/"
chmod +x "${DST}"/scripts/* "${DST}"/init/*.sh "${DST}"/init-entrypoint.sh

# Supabase sentinel at the FRONT of PATH: any invocation logs + fails.
BIN="${WORK}/bin"; mkdir -p "${BIN}"
printf '#!/usr/bin/env bash\necho "SUPABASE-INVOKED $*" >> "%s/supabase-calls.log"\nexit 97\n' "${WORK}" > "${BIN}/supabase"
chmod +x "${BIN}/supabase"; export PATH="${BIN}:${PATH}"

export COMPOSE_PROJECT_NAME="${PN}"
source "${DST}/scripts/_common.sh"     # dc(), psql_admin(), check_catalog_contract(), etc. (uses $PN)
set +e                                 # _common.sh enables -e; the harness must survive expected-fail probes

cleanup(){
  set +e; unset DOCKER_HOST DOCKER_CONTEXT
  COMPOSE_PROJECT_NAME="${PN}"  docker compose -f "${DST}/compose.local.yml" --project-directory "${DST}" down -v --remove-orphans >/dev/null 2>&1
  COMPOSE_PROJECT_NAME="${PN2}" docker compose -f "${DST}/compose.local.yml" --project-directory "${DST}" down -v --remove-orphans >/dev/null 2>&1
  rm -rf "${WORK}"
}
trap cleanup EXIT

echo "== P2 reproducible test (project ${PN}) =="
assert_local_docker && ok "T00 strictly-local docker context"
COMPOSE_PROJECT_NAME="${PN}" docker compose -f "${DST}/compose.local.yml" --project-directory "${DST}" down -v --remove-orphans >/dev/null 2>&1 || true

# ---- filesystem/precondition negatives ----
bash "${DST}/scripts/prepare-local" >/dev/null
mv "${DST}/.local-secrets/noxund_app_password" "${WORK}/app.bak"
if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "T01 secret absent"; else ok "T01 secret absent -> refused"; fi
[ -z "$(container_id)" ] && ok "T01b no container created" || no "T01b container created"
mv "${WORK}/app.bak" "${DST}/.local-secrets/noxund_app_password"

chmod 644 "${DST}/.local-secrets/noxund_app_password"
if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "T02 insecure perms"; else ok "T02 insecure perms -> refused"; fi
chmod 600 "${DST}/.local-secrets/noxund_app_password"

mv "${DST}/.local-secrets/noxund_app_password" "${WORK}/app.real"
ln -s "${WORK}/app.real" "${DST}/.local-secrets/noxund_app_password"
if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "T03 symlink secret"; else ok "T03 symlink secret -> refused"; fi
rm -f "${DST}/.local-secrets/noxund_app_password"; mv "${WORK}/app.real" "${DST}/.local-secrets/noxund_app_password"

# ---- happy path + DIGEST #1 ----
if bash "${DST}/scripts/start-local" >/tmp/start1 2>&1; then ok "T10 start-local happy"; else no "T10 start-local"; cat /tmp/start1; fi
V1="$(bash "${DST}/scripts/verify-local" | tee /tmp/v1 | grep -c '^PASS')"
D1="$(grep -o 'STRUCT_DIGEST=[0-9a-f]*' /tmp/v1 | cut -d= -f2)"
grep -q '== verify-local: 0 failure' /tmp/v1 && ok "T11 verify-local 0 failures (${V1} PASS)" || no "T11 verify-local had failures"
echo "DIGEST_1=${D1}"

# ---- privileged DRIFT negatives (start must fail AND not auto-repair) ----
neg(){ local d="$1" mut="$2" present="$3" revert="$4"
  psql_admin -c "${mut}" >/dev/null 2>&1
  if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "${d} (start SUCCEEDED despite drift)"
  else local n; n="$(psql_admin -tAc "${present}" 2>/dev/null)"
       if [ "${n:-0}" -gt 0 ] 2>/dev/null; then ok "${d} -> refused, not auto-repaired"; else no "${d} (drift was auto-repaired!)"; fi
  fi
  psql_admin -c "${revert}" >/dev/null 2>&1
}
neg "T12 GRANT owner TO app" \
  "grant noxund_owner to noxund_app" \
  "select count(*) from pg_auth_members a join pg_roles m on m.oid=a.member join pg_roles g on g.oid=a.roleid where m.rolname='noxund_app' and g.rolname='noxund_owner'" \
  "revoke noxund_owner from noxund_app"
neg "T13 external role member of owner" \
  "create role evil_ext nologin nosuperuser; grant noxund_owner to evil_ext" \
  "select count(*) from pg_auth_members a join pg_roles m on m.oid=a.member where m.rolname='evil_ext'" \
  "revoke noxund_owner from evil_ext; drop role evil_ext"
neg "T14 admin_option=true on migrator->owner" \
  "grant noxund_owner to noxund_migrator with admin option" \
  "select count(*) from pg_auth_members a join pg_roles m on m.oid=a.member join pg_roles g on g.oid=a.roleid where m.rolname='noxund_migrator' and g.rolname='noxund_owner' and a.admin_option" \
  "revoke admin option for noxund_owner from noxund_migrator"
neg "T15 schema owner divergence" \
  "alter schema public owner to postgres" \
  "select count(*) from pg_namespace where nspname='public' and nspowner<>'noxund_owner'::regrole" \
  "alter schema public owner to noxund_owner"

# after reverts the contract must be pristine again (proves reverts were exact)
if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then ok "T16 contract restored after reverts"; else no "T16 contract not restored"; cat /tmp/o; fi
DR="$(bash "${DST}/scripts/verify-local" | grep -o 'STRUCT_DIGEST=[0-9a-f]*' | cut -d= -f2)"
[ "${DR}" = "${D1}" ] && ok "T16b digest back to #1 after reverts" || no "T16b digest drift after reverts (${DR})"

# ---- persistence (down/up) ----
psql_admin -c "create table noxund_bootstrap._persist(x int); insert into noxund_bootstrap._persist values (42);" >/dev/null
bash "${DST}/scripts/stop-local" >/dev/null 2>&1
[ -n "$(volume_name)" ] && ok "T20 volume kept after stop" || no "T20 volume gone after stop"
bash "${DST}/scripts/start-local" >/dev/null 2>&1
[ "$(psql_admin -tAc 'select x from noxund_bootstrap._persist')" = "42" ] && ok "T21 row survived down/up" || no "T21 probe lost"
psql_admin -c "drop table noxund_bootstrap._persist" >/dev/null

# ---- project isolation (distinct volumes) ----
bash "${DST}/scripts/stop-local" >/dev/null 2>&1
COMPOSE_PROJECT_NAME="${PN2}" docker compose -f "${DST}/compose.local.yml" --project-directory "${DST}" create >/dev/null 2>&1 || true
if docker volume ls -q | grep -q "^${PN2}_pgdata$" && docker volume ls -q | grep -q "^${PN}_pgdata$"; then ok "T30 distinct project-scoped volumes"; else no "T30 volume isolation"; fi
COMPOSE_PROJECT_NAME="${PN2}" docker compose -f "${DST}/compose.local.yml" --project-directory "${DST}" down -v --remove-orphans >/dev/null 2>&1 || true

# ---- port occupied (service down) ----
python3 -c "import socket,time;s=socket.socket();s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('127.0.0.1',5433));s.listen(1);time.sleep(25)" & LPID=$!; sleep 1
if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "T40 port occupied"; else ok "T40 port occupied -> refused"; fi
kill "${LPID}" 2>/dev/null || true; wait "${LPID}" 2>/dev/null
for _ in $(seq 1 15); do port_open 127.0.0.1 5433 || break; sleep 1; done   # let the port actually free
[ -n "$(volume_name)" ] && ok "T40b volume untouched by refused start" || no "T40b volume affected"

# ---- no marker (fail-closed, no repair) ----
bash "${DST}/scripts/start-local" >/dev/null 2>&1
if [ -z "$(container_id)" ]; then no "T50 setup: container failed to start (cannot exercise no-marker)"; else
  psql_admin -c "drop schema noxund_bootstrap cascade" >/dev/null
  bash "${DST}/scripts/stop-local" >/dev/null 2>&1
  if bash "${DST}/scripts/start-local" >/tmp/o 2>&1; then no "T50 no marker"; else ok "T50 no marker -> refused"; fi
fi

# ---- reset under a simulated REMOTE context: must touch nothing ----
volb="$(volume_name)"
if DOCKER_HOST="tcp://192.0.2.1:2375" bash "${DST}/scripts/reset-local" RESET-NOXUND-LOCAL >/tmp/o 2>&1; then no "T60 reset under remote (it ran!)"; else ok "T60 reset refused under remote context"; fi
[ "$(volume_name)" = "${volb}" ] && [ -n "${volb}" ] && ok "T60b volume untouched by refused reset" || no "T60b volume changed under refused reset"

# ---- real reset -> reinit -> DIGEST #2 == #1 ----
bash "${DST}/scripts/reset-local" RESET-NOXUND-LOCAL >/dev/null 2>&1
bash "${DST}/scripts/start-local" >/dev/null 2>&1 && ok "T70 reinit start" || no "T70 reinit start"
D2="$(bash "${DST}/scripts/verify-local" | grep -o 'STRUCT_DIGEST=[0-9a-f]*' | cut -d= -f2)"
echo "DIGEST_2=${D2}"
[ "${D2}" = "${D1}" ] && ok "T71 structural digest reproducible (D2==D1)" || no "T71 digest not reproducible (${D2})"

# ---- Supabase CLI was NEVER invoked by the stack ----
if [ -s "${WORK}/supabase-calls.log" ]; then no "T80 Supabase CLI was invoked"; cat "${WORK}/supabase-calls.log"; else ok "T80 Supabase CLI never invoked (sentinel clean)"; fi

echo "== VERSIONS =="; docker --version; docker compose version | head -1; psql --version
psql_admin -c "select version()" 2>/dev/null | sed -n '3p'

echo "== p2-local-stack-test: ${F} failure(s) =="
[ "${F}" -eq 0 ] || exit 1
echo "P2-TEST-GREEN digest=${D1}"
