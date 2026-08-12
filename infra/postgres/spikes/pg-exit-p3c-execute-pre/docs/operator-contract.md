# Operator contract — PG-EXIT-P3C-EXECUTE-PRE — PROVISIONING HOLD

There is no approved execution procedure. The rejected R0 command sequence was
removed because its client service lacked Python/Psycopg and attempted a runtime
package installation on an internal no-egress network.

## Invariants a future gate must uphold

- Disposable project name matching exactly `^noxund-p3c-[0-9]+$`.
- Explicit `--project` on every Compose operation.
- Exact target: `PGHOST=postgres`, `PGPORT=5432` and
  `PGDATABASE=noxund_p3c_spike`.
- PostgreSQL server version exactly 15.18 plus a verified disposable-spike
  bootstrap marker.
- No ambient, remote or arbitrary target.
- No published database port; internal-only no-egress network.
- Client and PostgreSQL images already local and pinned by immutable digest.
- `--pull never` for every creation/run command.
- No Docker socket.
- Source mounted read-only, secret files mounted read-only and evidence mounted
  read-write.
- No package installation or index access during the executable gate.
- No password in argv, logs, evidence or exception text.
- Project-label verification before project-scoped teardown; never global prune.

## No executable procedure

Do not invoke Docker or Compose from this tree. There is intentionally no
client service and no substitute host-runtime command. A later provisioning
unit must produce and independently review the immutable client digest and
offline dependency closure before a command can be documented.

See `PG-EXIT-P3C-EXECUTE-PRE-PROVISION.md`.

## Verdict status

R0 verdict semantics remain rejected and are explicitly inside this HOLD. No
uppercase or free-form observation may determine success. The future corrected
evaluator must use typed observations, executable validators and a closed result
enum, with every missing or unknown observation failing the gate.

RBF-01 through RBF-04 remain OPEN. Nothing in this document is READY FOR
EXECUTION.