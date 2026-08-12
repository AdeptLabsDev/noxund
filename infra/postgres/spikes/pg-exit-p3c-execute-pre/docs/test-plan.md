# PG-EXIT-P3C-EXECUTE-PRE — test plan (A–G ↔ files) — IMPLEMENTED, NOT EXECUTED

Authoritative machine-readable matrix: `harness/expected_matrix.json` (loaded/validated by `harness/cases.py`). Every cell there is an **expected** outcome for a future run, not an observed result.

## Group A — transport & artifact
| ID | Threat | Concrete code / fixture |
|----|--------|-------------------------|
| A01 | multi-command artifact | `fixtures/attacks/A01_multi_command.sql` → runner PQexecParams (Parse rejects >1) |
| A02 | non-DO command tag | `fixtures/attacks/A02_non_do_ddl.sql` → runner tag guard |
| A03 | COMMIT inside DO | `fixtures/attacks/A03_internal_commit.do.sql` |
| A04 | ROLLBACK inside DO | `fixtures/attacks/A04_internal_rollback.do.sql` |
| A05 | dynamic tx-control | `fixtures/attacks/A05_dynamic_txctl.do.sql` |
| A06 | lone BEGIN (INTRANS) | `fixtures/attacks/A06_begin_only.sql` |
| A07 | lone SAVEPOINT | `fixtures/attacks/A07_savepoint_only.sql` |
| A08 | Parse/Bind/Execute trace | `runner/pq_transport.enable_trace` + `harness.run_pre_gate.h_trace_parse_bind_execute` |
| A09 | control: default cursor = simple protocol | `harness.run_pre_gate.h_control_default_cursor_multistmt` |

## Group B — connection & session
| ID | Threat | Code |
|----|--------|------|
| B01 | fresh conn + close (success) | `h_lifecycle_success` + `runner.apply_one_migration` step 22 |
| B02 | close on failure | `h_lifecycle_failure` |
| B03 | PID/XID stability | `h_pid_xid_stability` + runner steps 5/6/12/13 |
| B04 | synchronous_commit weakened | `fixtures/attacks/B01_synchronous_commit_off.do.sql` + `session_state.assert_synchronous_commit_durable` |
| B05 | encoding/date GUC mutation | `fixtures/attacks/B03_guc_mutation.do.sql` + `session_state.reassert_baseline` |
| B06 | temp/LISTEN/prepared carryover | `fixtures/attacks/B02_temp_and_notify.do.sql` + `h_carryover_prevention` |

## Group C — role & privilege boundary
| ID | Threat | Code |
|----|--------|------|
| C01 | RESET ROLE + ledger INSERT | `fixtures/attacks/C01_reset_role_ledger_insert.do.sql` |
| C02 | SET ROLE noxund_ledger | `fixtures/attacks/C02_set_role_ledger.do.sql` |
| C03 | direct ledger UPDATE | `fixtures/attacks/C03_direct_ledger_update.do.sql` |
| C04 | replace/alter/drop function | `fixtures/attacks/C04_replace_record_fn.do.sql` |
| C05 | CREATE in ledger schema | `fixtures/attacks/C05_ledger_schema_create.do.sql` |
| C06 | PUBLIC privileges absent | `h_public_privileges_absent` |
| C07 | membership/ACL inventory | `h_acl_inventory` |
| C08 | accessors read-only/non-locking | `h_accessors_readonly` |

## Group D — linearity & authority
| ID | Threat | Code |
|----|--------|------|
| D01 | concurrent children | `harness/concurrency.py` + `h_concurrent_children` |
| D02 | omit advisory lock | `h_concurrent_no_advisory` |
| D03 | different advisory keys | `h_concurrent_diff_keys` |
| D04 | FOR UPDATE wait/re-read | `h_for_update_wait_reread` |
| D05 | predecessor uniqueness | `h_predecessor_uniqueness` |
| D06 | contiguous ordinal | `h_ordinal_contiguity` (V001,V002) |
| D07 | no sequence authority | `h_no_sequence_authority` |
| D08 | clock reversal | `h_clock_reversal` |
| D09 | top-level XID in subtx | `h_top_xid_subtx` |
| D10 | aborted-subtx unique release | `h_aborted_subtx_release` |
| D11 | backup/restore state | `h_backup_restore_state` |

## Group E — SECURITY DEFINER hardening
| ID | Threat | Code |
|----|--------|------|
| E01 | search_path poison | `fixtures/attacks/E01_search_path_poison.do.sql` |
| E02 | pg_temp Trojan clock | `fixtures/attacks/E02_pg_temp_trojan_clock.do.sql` |
| E03 | pg_temp shadow of xid fn | `fixtures/attacks/E03_operator_shadow.do.sql` |
| E04 | underlying tables denied | `h_underlying_table_denied` |

## Group F — accepted TM-A limitation
| ID | Threat | Code |
|----|--------|------|
| F01 | direct principal append (accepted) | `fixtures/attacks/F01_direct_principal_append.sql` |
| F02 | two rows in one tx (REJECT-if) | `fixtures/attacks/F02_direct_second_row_same_tx.sql` |
| F03 | direct history mutation (REJECT-if) | `fixtures/attacks/F03_direct_history_update.sql` |

## Group G — process-death boundaries
| ID | Threat | Code |
|----|--------|------|
| G01 | kill before artifact | `h_kill` + `fault_injection.FaultPoint.BEFORE_ARTIFACT` |
| G02 | kill after DDL, before ledger | `fault_injection.FaultPoint.AFTER_DDL_BEFORE_LEDGER` |
| G03 | kill after ledger, before COMMIT | `fault_injection.FaultPoint.AFTER_LEDGER_BEFORE_COMMIT` |
