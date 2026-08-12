# Expected outcomes (NOT observed) — PG-EXIT-P3C-EXECUTE-PRE

These are **expected** outcomes for a future authorized run. Nothing here has
been executed; no cell is a `PASS`/`GREEN`/`verified` observation. Source of
truth: `harness/expected_matrix.json`.

| ID | Group | Expected SQLSTATE | Expected result | Classification |
|----|-------|-------------------|-----------------|----------------|
| A01 | A | 42601 | multi-command rejected at Parse; rollback | PASS |
| A02 | A | — (tag CREATE TABLE) | non-DO tag rejected; rollback | PASS |
| A03 | A | 2D000 | COMMIT-in-DO rejected; rollback | PASS |
| A04 | A | 2D000 | ROLLBACK-in-DO rejected; rollback | PASS |
| A05 | A | 2D000 | dynamic tx-control rejected | PASS |
| A06 | A | — (tag BEGIN) | lone BEGIN rejected by tag guard | PASS |
| A07 | A | — (tag SAVEPOINT) | lone SAVEPOINT rejected by tag guard | PASS |
| A08 | A | — | trace shows Parse/Bind/Execute | PASS |
| A09 | A | — | default cursor uses simple protocol (control) | CONTROL |
| B01 | B | — | fresh conn, commit, closed | PASS |
| B02 | B | — | fresh conn, fail, closed, no reconnect | PASS |
| B03 | B | — | PID/XID stable | PASS |
| B04 | B | — | synchronous_commit reasserted to on | PASS |
| B05 | B | — | encoding/date GUCs reasserted | PASS |
| B06 | B | — | no temp/LISTEN/prepared carryover | PASS |
| C01 | C | 42501 | RESET ROLE + ledger INSERT denied | PASS |
| C02 | C | 42501 | SET ROLE noxund_ledger denied | PASS |
| C03 | C | 42501 | direct ledger UPDATE denied | PASS |
| C04 | C | 42501 | function replace/alter/drop denied | PASS |
| C05 | C | 42501 | CREATE in ledger schema denied | PASS |
| C06 | C | 42501 | PUBLIC has no ledger access | PASS |
| C07 | C | — | membership = only owner→migrator | PASS |
| C08 | C | — | accessors read-only, no lock | PASS |
| D01 | D | P0001/23505 | one child commits, one rejected | PASS |
| D02 | D | P0001/23505 | serialized w/o client advisory lock | PASS |
| D03 | D | P0001/23505 | serialized despite different keys | PASS |
| D04 | D | P0001 | FOR UPDATE wait/re-read/loser reject | PASS |
| D05 | D | 23505 | predecessor uniqueness enforced | PASS |
| D06 | D | — | ordinals 1,2 contiguous | PASS |
| D07 | D | — | no sequence backs the ordinal | PASS |
| D08 | D | — | order by ordinal, not clock | PASS |
| D09 | D | — | top-level XID stable across subtx | PASS |
| D10 | D | — | legit append after aborted subtx | PASS |
| D11 | D | — | head/ordinal preserved after restore | PASS |
| E01 | E | — | search_path poison has no effect | PASS |
| E02 | E | — | pg_temp Trojan clock has no effect | PASS |
| E03 | E | — | pg_temp shadow of xid fn has no effect | PASS |
| E04 | E | 42501 | direct underlying-table access denied | PASS |
| F01 | F | — | direct append MAY commit | ACCEPTED_TM_A_LIMITATION |
| F02 | F | 23505 | two rows in one tx rejected | PASS |
| F03 | F | 42501 | direct history mutation denied | PASS |
| G01 | G | — (exit 137) | kill before artifact: clean rollback | PASS |
| G02 | G | — (exit 137) | kill after DDL: no orphaned DDL | PASS |
| G03 | G | — (exit 137) | kill after ledger: no surviving row | PASS |
