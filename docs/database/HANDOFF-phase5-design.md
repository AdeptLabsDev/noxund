> ✅ **RESOLVIDO / APLICADO — não leia este documento como `needs_review`.**
> O ciclo de re-reviews (DATA-AI-0005→0006→**0007** aprovado · Security **SEC-0014** · pipeline **SEC-0015**)
> foi fechado e a migration **foi aplicada em produção** (CI run `28311371393`, origem `main`, reviewer
> AdeptLabsDev; PR #6 → `6d842b1`; **DEC-0012**). As revisões ⏳ do §10 abaixo estão **superadas**.
> **Fonte canônica de status:** [`HANDOFF-phase5-apply-closeout.md`](HANDOFF-phase5-apply-closeout.md).
> Este documento permanece como registro de **design** (decisões de integridade + mapa achado→correção).

# Handoff — [DB] Fase 5 Design (Computed Metrics + Resolução + Relatório) · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase5_design_schema_fix_v3` (2ª iteração) · **Action:** `design_schema` (não-sensível; apply gated)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-27
- **Natureza:** **correção pós RE-veto Data/AI** (DATA-AI-0006 · achados DATA-RR-F5-03A/05A/06A/01A) — follow-on das correções da 1ª iteração (DATA-AI-0005 · DATA-F5-01..07). Re-autoria de DDL + verify + rollback ANTES de qualquer apply. Nenhum DDL aplicado; nenhum Score/hash/número gerado.
- **Predecessoras:** Fase 2 (`rubric_versions`), Fase 3 (`report_runs`/`artists`), Fase 4 (`raw_youtube_*`) — DEC-0010/0009/0011.
- **Fontes:** `DATA-AI-0006-phase5-rereview.md` (re-veto) · `DATA-AI-REVIEW-phase5-computed-metrics-reports.md` (1º veto) · `migration-plan.md §Fase 5` · `04_…§5–§7` · `03_…§5–§10` (metodologia/shape de evidência) · `mvp-data-model.md` Grupos D/E · `DATA-AI-0001` (chave + OD-DB-06/07) · `SEC-0001` (SEC-D03/F01/F03/F13/F15) · padrão Fases 1–4.

## 2. Objetivo
Fechar **holisticamente** o modelo de integridade da Fase 5: 1ª iteração endereçou DATA-F5-01..07; esta 2ª fecha os **follow-on** DATA-RR-F5-03A/05A/06A/01A (cada correção pontual gerou um novo caminho — o freeze criou o bypass da junction; o NOT NULL admitiu `{}`). **Sem regredir** o aprovado e **sem** freeze global nas COMPUTED. Princípio anti-bypass: **todo guard valida OLD e NEW separadamente**; a evidência é **estrutural** (não só `NOT NULL`). Apply permanece gated; a **prova canônica de 2 rodadas (P5-REPRO-01)** é precondição do data-engine/primeiro publish — **não** deste apply (§12).

## 3. Mapa achado → correção (DATA-F5-01..07)
| Achado (severidade) | Correção no DDL | Prova no verify |
|---|---|---|
| **F5-01** Snapshot aceita INSERT pós-publish; UPDATE move item p/ publicado (crítico) | `report_items_snapshot_guard` agora **BEFORE INSERT OR UPDATE OR DELETE**, validando o pai de **NEW** (INSERT/UPDATE) **e** de **OLD** (UPDATE/DELETE). `reports_snapshot_guard` cobre INSERT (entrada só por `draft`). | §5/F5-01 (2 role-paths): INSERT em report publicado **falha**; mover item draft→publicado **falha**; INSERT/UPDATE em draft **OK**. §4: bit INSERT no `tgtype` dos guards. |
| **F5-02** OD-DB-06 não garante coerência report→metric (crítico) | Report **congela** `(rubric_version, rubric_hash)` (NOT NULL + FK). Duas **FKs compostas**: item↔report `(report_id,run_id,rubric_version,rubric_hash)` e item↔metric `(artist_metric_id,run_id,artist_id,rubric_version,rubric_hash)`. Alvos: `reports_identity_key`, `artist_metrics_identity_key`. | §5/F5-02: item coerente **aceito**; metric de outro **run / artista / rubric** e item com rubric divergente do report → **rejeitados** separadamente. |
| **F5-03** Métrica publicada continua mutável (crítico) | Trigger **CONDICIONAL** `artist_metrics_published_guard` (SECURITY DEFINER): bloqueia UPDATE/DELETE **só** se a métrica alimenta item de report `published`/`archived`. Idem `artist_metric_videos_published_guard` p/ o conjunto de inputs. **Sem** freeze global. | §5/F5-03 (2 role-paths): tamper na métrica publicada **bloqueado**; recompute de métrica **não-publicada OK**; inputs da publicada **invioláveis**. |
| **F5-04** Proveniência até raw só lógica (alto) | Removido `computed_from_video_ids text[]`. Nova tabela normalizada **`artist_metric_videos`** com FK composta a `artist_metrics(id,run_id)` **e** a `raw_youtube_videos(run_id,video_id)`. `report_items.example_video_id` ganha FK composta `(run_id,example_video_id)→raw`. Todas RESTRICT. | §5/F5-04: input/Example com vídeo **inexistente** ou **de outro run** → rejeitados; coerente **aceito**; Example `null` aceito (opcional). |
| **F5-05** Métrica/Item sem evidência de auditoria (alto) | `artist_metrics.metrics_detail_json` **NOT NULL**; `report_items.selection_reason_json` **NOT NULL**. DDL permanece storage-only (não valida thresholds). | §5/F5-05: evidência ausente → `not_null_violation`; fixture completo **aceito**. §4: `is_nullable='NO'`. |
| **F5-06** Versões pré-scoring não fecham o rebuild (alto) | `channel_eligibility.rule_version` **NOT NULL**; `video_artist_mappings.resolver_version` **NOT NULL**. Decisões humanas seguem replayable em `audit_events` (Fase 1). | §5/F5-06: versão ausente → `not_null_violation`; com versão **aceito**. §4: `is_nullable='NO'`. |
| **F5-07** Verify procura FK não nomeada; falta assertion de não-freeze (alto) | FK **nomeada** `report_items_artist_metric_fk`. | §4: FK identificada por **nome E** por colunas/alvo/`RESTRICT`; assertion estrutural **+** empírica de **ausência de freeze global** nas 3 COMPUTED. |

## 3b. Mapa achado → correção (2ª iteração — DATA-AI-0006 · follow-on)
| Achado (severidade) | Correção no DDL | Prova no verify |
|---|---|---|
| **F5-03A** UPDATE da junction contorna o freeze: `coalesce(OLD,NEW)` deixava OLD vencer e o destino publicado não era checado (crítico) | `artist_metric_videos_published_guard` reescrito: valida **OLD (origem)** em UPDATE/DELETE **E NEW (destino)** em INSERT/UPDATE, **separadamente** (sem coalesce). Mover input de métrica não-publicada → publicada bloqueado. `artist_metrics_published_guard` ganha checagem defensiva de **NEW** (id PK imutável, mas explícita). | §5/F5-03A (2 role-paths): `UPDATE artist_metric_videos SET artist_metric_id=<publicada>` → **restrict_violation** (postgres **e** service_role). |
| **F5-05A** `{}` passa NOT NULL mas não é auditoria (alto) | Contrato **ESTRUTURAL** por CHECK: `artist_metrics_detail_complete_chk` e `report_items_reason_complete_chk` chamam funções **IMMUTABLE** (`artist_metrics_detail_complete`/`report_item_reason_complete`) que exigem **presença/não-vazio** das chaves do shape mínimo (§3c). **Storage-only**: zero número/threshold. Evidência da métrica publicada fica imutável pelo guard condicional. | §5/F5-05A: `{}` e seção ausente → **check_violation**; `NULL` → `not_null_violation`; fixture completo **aceito**; `UPDATE metrics_detail_json` de métrica publicada → **restrict_violation** (congelada). §4: CHECKs presentes; validadores IMMUTABLE + `search_path` fixo. |
| **F5-06A** versões/overrides efetivos não chegavam à métrica publicada (vivem em tabelas mutáveis) (alto) | O shape exige `versions.{rubric_version,rubric_hash,resolver_version,rule_version}` **não-vazios** e `overrides[]` em que **cada** elemento preserva a **chave natural** `run_id` + (`video_id`\|`channel_id`) — replay não depende só de `audit_events` por UUID. | §5/F5-06A: detalhe sem `versions` → **check_violation**; override sem chave natural → **check_violation**; override com chave natural → **aceito**. |
| **F5-01A** verify incompleto no 2º role-path (médio) | — (já estava no DDL) | §5/F5-01A: mover `report_items` draft→published agora provado **também** como `service_role`. |
| **Nota FK count** report_items.artist_id tinha FK inline **e** nomeada (DDL=17 vs handoff=16) | Removida a FK **inline** duplicada; fica só `report_items_artist_fk` (nomeada, RESTRICT). | §4: assert `report_items` tem **exatamente 1** FK → `artists`. DDL e handoff agora declaram **16 FKs**. |

> **§3c. Contrato de evidência (shape mínimo Data/AI — storage-only, só presença/não-vazio):**
> `metrics_detail_json` (artist_metrics): `components` (não-vazio) · `normalization` · `videos.accepted` (≥1) + `videos.rejected` · `velocity.inputs` + `velocity.median` · `competition.eligible_channel_ids` + `competition.count` · `versions.{rubric_version,rubric_hash,resolver_version,rule_version}` (não-vazios) · `overrides[]` (cada elemento com `run_id` + `video_id`\|`channel_id`).
> `selection_reason_json` (report_items): `candidates` (≥1) · `top3` (≥1) · `tiebreak` · `selected_example.video_id` (não-vazio).
> Os CHECKs validam **só estrutura** — nunca valor/threshold/número. O data-engine (Data/AI) é o owner do conteúdo; o publish rejeita `{}`/seções ausentes porque o CHECK é sempre-ativo (toda linha já nasce completa).

## 4. Diff de schema (forward migration)
`supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`:

```text
  enums: video_artist_method, report_status, competition_level (inalterados)
  video_artist_mappings  + resolver_version text NOT NULL            (F5-06)
  channel_eligibility    rule_version text NOT NULL                  (F5-06; era nullable)
  artist_metrics         - computed_from_video_ids text[]            (F5-04: removido)
                         metrics_detail_json jsonb NOT NULL          (F5-05; era nullable)
                         + unique artist_metrics_identity_key (id,run_id,artist_id,rubric_version,rubric_hash)  (F5-02 alvo de FK)
                         + unique artist_metrics_id_run_key (id,run_id)                                          (F5-04 alvo de FK)
                         + CHECK artist_metrics_detail_complete_chk (artist_metrics_detail_complete(metrics_detail_json))  (F5-05A/06A)
+ table artist_metric_videos(artist_metric_id, run_id, video_id, created_at)                                    (F5-04)
                         pk (artist_metric_id, video_id);
                         FK (artist_metric_id,run_id)→artist_metrics(id,run_id) RESTRICT;
                         FK (run_id,video_id)→raw_youtube_videos(run_id,video_id) RESTRICT
  reports                + rubric_version/rubric_hash text NOT NULL  (F5-02)
                         + FK reports_rubric_fk (rubric_version,rubric_hash)→rubric_versions RESTRICT
                         + unique reports_identity_key (id,run_id,rubric_version,rubric_hash)  (F5-02 alvo de FK)
  report_items           + run_id, rubric_version, rubric_hash (NOT NULL)   (F5-02/F5-04)
                         selection_reason_json jsonb NOT NULL        (F5-05; era nullable)
                         artist_id: FK inline duplicada REMOVIDA — fica só a nomeada (nota FK count)
                         FK report_items_report_fk (report_id,run_id,rubric_version,rubric_hash)→reports RESTRICT
                         FK report_items_artist_metric_fk (artist_metric_id,run_id,artist_id,rubric_version,rubric_hash)→artist_metrics RESTRICT  (F5-02/F5-07)
                         FK report_items_artist_fk (artist_id)→artists RESTRICT   (ÚNICA FK de artist_id)
                         FK report_items_example_raw_fk (run_id,example_video_id)→raw_youtube_videos RESTRICT  (F5-04)
                         + CHECK report_items_reason_complete_chk (report_item_reason_complete(selection_reason_json))  (F5-05A)
+ function artist_metrics_detail_complete(jsonb)   IMMUTABLE search_path=''   (F5-05A/06A validador estrutural)
+ function report_item_reason_complete(jsonb)      IMMUTABLE search_path=''   (F5-05A validador estrutural)
+ function artist_metrics_published_guard()        SECURITY DEFINER search_path=''   (F5-03 condicional; defesa OLD≠NEW)
+ function artist_metric_videos_published_guard()  SECURITY DEFINER search_path=''   (F5-03A: valida OLD origem E NEW destino)
~ function report_items_snapshot_guard()           SECURITY DEFINER  — INSERT/UPDATE/DELETE (F5-01)
~ function reports_snapshot_guard()                — INSERT (entrada=draft) + UPDATE/DELETE (F5-01)
~ function report_snapshot_no_truncate()           — mensagem genérica (reusada por reports/report_items/junction)
+ trigger artist_metrics_published_guard (before update/delete, row)
+ trigger artist_metric_videos_published_guard (before insert/update/delete, row) + artist_metric_videos_no_truncate
~ trigger reports_snapshot_guard / report_items_snapshot_guard → before INSERT OR UPDATE OR DELETE
  enable row level security (as 6)  + revoke all from anon, authenticated (as 6)
  TOTAL: 16 FKs (sem a inline duplicada), todas ON DELETE RESTRICT
```

## 5. Decisões de integridade (e por quê)
- **Coerência declarativa por FK composta, não por trigger.** A coerência report→item→metric (mesmo `run_id`/`artist_id`/`rubric_version`/`rubric_hash`) é enforçada por **duas FKs compostas** ancoradas em chaves de identidade (`reports_identity_key`, `artist_metrics_identity_key`). Transitivamente: `metric.run = item.run = report.run`; `metric.rubric = item.rubric = report.rubric`; `metric.artist = item.artist`. Constraint > trigger: sempre aplicada, sem bypass, sem SQL. `artist_metric_id` passa a apontar a métrica **exata** do snapshot.
- **Freeze CONDICIONAL preserva "computed reconstruível".** As 3 COMPUTED (`video_artist_mappings`, `channel_eligibility`, `artist_metrics`) **não** recebem freeze global. `video_artist_mappings`/`channel_eligibility` têm **zero** trigger. `artist_metrics` tem **só** o guard condicional que bloqueia mutação **quando** a linha alimenta report publicado/archived — métrica não-publicada segue recompute-livre. A reconstrução de uma métrica **já publicada** apoia-se no próprio registro congelado (Score + `metrics_detail_json` + `artist_metric_videos`) + raw imutável + rubric append-only — **não** no estado atual de mappings/eligibility (por isso estes não precisam de freeze).
- **Proveniência referencial (sem array sem FK).** `computed_from_video_ids text[]` (referência só lógica) foi substituído pela tabela normalizada `artist_metric_videos`: cada input **existe** no raw **e** pertence ao **mesmo run** da métrica (FK composta dupla). `example_video_id` valida-se contra o raw por FK composta (MATCH SIMPLE → opcional, mas referencial quando presente). Fecha "nenhum número sem rastro até `raw_youtube_videos`".
- **Proteção de TRUNCATE por classe.** `reports`/`report_items` e o leaf `artist_metric_videos` têm `no_truncate` (statement-level) — não impede recompute por-linha, só barra o wipe catastrófico de linhagem congelável. `artist_metrics` **não** precisa: é referenciada por FK de `report_items`/`artist_metric_videos`, então `TRUNCATE` exigiria CASCADE que esbarra no `no_truncate` de `report_items`. `video_artist_mappings`/`channel_eligibility` ficam livres (reconstruíveis).
- **Guards anti-bypass: OLD e NEW validados SEPARADAMENTE (F5-03A).** O `coalesce(OLD,NEW)` da 1ª iteração deixava OLD vencer no UPDATE da junction → mover um input de métrica não-publicada para uma publicada escapava à checagem do destino. Agora **cada** guard valida a **origem (OLD)** em UPDATE/DELETE e o **destino (NEW)** em INSERT/UPDATE, em ramos independentes. Princípio: nenhuma operação de "mover" pode aterrissar sobre linhagem publicada sem disparar o freeze.
- **Evidência ESTRUTURAL, não só NOT NULL (F5-05A/06A).** `metrics_detail_json`/`selection_reason_json` continuam `NOT NULL`, **mais** um CHECK que chama um validador **IMMUTABLE** exigindo presença/não-vazio das chaves do shape mínimo (§3c) — `{}` e seções ausentes são rejeitados no banco. Os validadores são **storage-only**: checam só **estrutura** (presença/tipo/não-vazio/chave-natural dos overrides), **nunca valor/threshold/número**. O cálculo e os thresholds seguem 100% no data-engine (Data/AI). A evidência da métrica **publicada** é congelada pelo guard condicional (UPDATE bloqueado) → permanece idêntica após publish.
- **SECURITY DEFINER nos 3 guards cross-table (SEC-F15).** `report_items_snapshot_guard`, `artist_metrics_published_guard` e `artist_metric_videos_published_guard` precisam **ler** `reports`/`report_items`, mas o escritor legítimo (`service_role`) não detém `SELECT` nelas. DEFINER (+ `search_path=''` + refs `public.*` + sem SQL dinâmico/entrada de usuário) faz o lookup rodar como owner → decisão correta p/ qualquer caller, sem vetor de escalonamento. Os **validadores** de evidência NÃO são DEFINER (são puros/IMMUTABLE, sem acesso a tabela). **Security ratifica no #3.**
- **DDL é só ARMAZENAMENTO (preservado).** Zero CHECK de **faixa/threshold** de Score/Velocity/Signals/Competition, zero generated column, zero trigger/expressão de cálculo. Os CHECKs de evidência são **estruturais** (presença de chaves), não numéricos — não recalculam nem validam valor. O §4 do verify assert que os **únicos** CHECKs nas 6 tabelas são `reports_published_at_chk` + os 2 de evidência.
- **Rebuild canônico (F5-06/06A).** Entrada determinística do rebuild = **raw imutável + rubric `(version,hash)` + `resolver_version` + `rule_version` + decisões humanas replayable**. Agora as **versões efetivas** e os **overrides** (com a **chave natural** `(run_id, video_id)`/`(run_id, channel_id)`) são **obrigatórios DENTRO de `metrics_detail_json`** (CHECK), congelados junto com a métrica publicada — não dependem de tabela mutável nem só de `audit_events` por UUID polimórfico. `audit_events` continua sendo o log de overrides, mas a chave natural vive também na evidência congelada.

## 6. Verify §4/§5 (`phase5_post_apply_verify.sql`, fail-closed, 2 role-paths)
- **§4 estrutural:** 6 tabelas; 3 enums; colunas mandatórias + **`is_nullable='NO'`** (F5-05/F5-06); **5 funções de guard** `search_path`-pinned + **2 validadores IMMUTABLE** `search_path`-pinned (F5-05A); **3 guards SECURITY DEFINER**; **2 CHECKs de evidência** presentes (F5-05A); 7 triggers; **bit INSERT** nos 3 guards relevantes (report_items/reports/junction); 6 índices de unicidade; 3 chaves de identidade; **10 FKs nomeadas críticas**; `report_items_artist_metric_fk` **por nome E por colunas/alvo/RESTRICT** (F5-07); **report_items com exatamente 1 FK→artists** (nota FK count); **todas as FKs das 6 RESTRICT**; **únicos CHECKs = published_at + 2 de evidência** (storage-only); **ausência de freeze global** nas 3 COMPUTED; RLS-on nas 6; **zero policies**.
- **§5 empírico (probes revertidos, `ON_ERROR_STOP=1`; fixtures de evidência completos via `pg_temp.p5_detail()/p5_reason()`):** F5-01 + **F5-01A** (freeze cobre INSERT/move/UPDATE/DELETE, **move draft→published nos 2 role-paths**) · máquina de estados (entrada=draft; published→draft bloqueado; →archived OK) · F5-02 (coerente aceito, 4 mismatches rejeitados) · F5-03 + **F5-03A** (tamper/DELETE publicado bloqueado; **UPDATE de evidência publicada bloqueado**; **mover input não-publicado→publicado bloqueado nos 2 role-paths**; recompute não-publicado OK; inputs publicados invioláveis) · F5-04 (input/Example inexistente e outro-run rejeitados; coerente/`null` aceitos) · **F5-05A** (`{}`→check_violation; `NULL`→not_null; seção ausente→check_violation; fixture completo aceito) · **F5-06A** (override sem chave natural→check_violation; com chave natural aceito) · F5-06 working-set (rule/resolver `NOT NULL`) · unicidade (incl. junction PK) · FK de rubric · proveniência mappings→raw · **F5-07 não-freeze empírico** · default-deny nas 6.

## 7. Itens aprovados preservados (sem regressão)
- Storage-only (zero fórmula/generated/CHECK de **faixa/threshold**; nenhum número validado no banco). Os CHECKs agora existentes são: `reports_published_at_chk` (estado) + 2 de evidência **estrutural** (presença de chaves) — verify §4 prova que não há outros.
- `unique(run_id, artist_id, rubric_hash)` (DATA-AI-0001) intacto.
- FK composta `(rubric_version, rubric_hash)→rubric_versions` RESTRICT.
- FK composta `(run_id, source_id)→raw` em mappings/eligibility RESTRICT.
- Migration atômica (`begin/commit`); rollback filhos→pais.
- **Zero `CREATE POLICY`** executável (Fase 9 vetada — SEC-0001 §0).
- **Sem trigger de imutabilidade GLOBAL** nas 3 COMPUTED (seguem recalculáveis).

## 8. Rollback
`supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql` — ajustado aos novos objetos: triggers → funções → tabelas (`report_items`/`artist_metric_videos` → `reports` → `artist_metrics` → `channel_eligibility` → `video_artist_mappings`) → enums. Fora de `migrations/`. **Ressalva:** publicado é congelado e o computed (com `artist_metric_videos`) é a cadeia de proveniência; rollback só p/ run(s) descartável(is). `DROP TABLE` é DDL (não dispara freeze).

## 9. Validação executada
- Estrutural: revisão linha a linha; verify reescrito em paridade com Fases 1–4; contagem conferida (6 tabelas, 3 enums, **7 funções** = 5 guards + 2 validadores, 7 triggers, **16 FKs RESTRICT** (sem a inline duplicada), 3 chaves de identidade, **3 CHECKs** = published_at + 2 evidência, 0 policies); ordem de drop conferida (validadores caem após as tabelas que os usam em CHECK).
- **Anti-bypass conferido (orientação holística):** revisitei TODOS os guards — junction valida OLD/NEW separadamente; artist_metrics com defesa NEW; snapshot guards já validavam OLD+NEW. Validadores de evidência são NULL-safe (presença antes do typeof; `jsonb_array_length` só após confirmar `array`) e retornam boolean definido (um CHECK que avaliasse NULL passaria).
- **Não executado:** nenhum apply (sem Postgres/Docker conectado; apply é gated). A prova empírica roda no job `verify` pós-apply (fail-closed). Nota de apply: as FKs compostas até o raw apontam para os **índices únicos** de Fase 4 (`raw_youtube_videos`/`channel`) — alvos válidos de FK; se o alvo faltasse, o **próprio apply** (CI gated) falharia antes do verify.

## 10. Revisões necessárias (⏳, nunca assumidas como ok) — ANTES de qualquer `run_migration`
- [x] **Database** — autor (este handoff, correção pós-veto).
- [ ] **Data/AI** — **re-review `validate_reproducibility`** (matrix #4/#5): confirmar que DATA-F5-01..07 estão fechados (coerência report→metric; linhagem publicada inviolável com recompute livre no não-publicado; proveniência referencial até raw; evidência obrigatória; versões de rebuild) e que **não** houve freeze global em COMPUTED. **Gate de veto — reaberto.**
- [ ] **Security** — **matrix #3** (`review_rls`): 4 guards (3 SECURITY DEFINER) abaixo do service_role (SEC-D03/F01/F15); RLS default-deny + revoke (SEC-F13); **zero policy** (Fase 9 sob veto SEC-0001 §0); colunas internas (`score_value`/json) sem exposição — VIEW pública só na Fase 9 (SEC-F03).
- [ ] **Backend** — consumo de `artist_metric_id`/snapshot público nos endpoints sem auto-expandir escopo (leitura por VIEW na Fase 9).

## 11. Próximos passos / `next_recommendation`
1. **Data/AI reexecuta `validate_reproducibility`** (re-review) sobre o SQL/verify corrigidos — confirmar DATA-RR-F5-03A/05A/06A/01A fechados + não-regressões. Ajustes, se houver, voltam ao Database (autor). **Gate de veto — reaberto.**
2. Só com aprovação Data/AI → **Security #3** (`review_rls`) → **Backend** (consumo de `artist_metric_id`).
3. Por último, **task gated separada** de `run_migration` (humano + required reviewers; pipeline `phase5-db-apply.yml` a definir por DevOps; verify fail-closed), espelhando Fases 1–4.
4. Segue **Fase 6** (`producer_events`, append-only) na ordem do `migration-plan.md`.
- **Vetos que continuam de pé:** Fase 9 — RLS Policies + **VIEW pública de `report_items` (SEC-F03)** (SEC-0001 §0). Esta autoria **não** os destrava.

## 12. Precondição de PUBLISH (não bloqueia este apply) — P5-REPRO-01
**P5-REPRO-01 é gate do `services/data-engine` (hoje placeholder) ANTES da liberação do pipeline / primeiro publish — NÃO do migration apply.** O verify SQL exercita **constraints**, não os seis agentes do pipeline; inserts SQL hardcoded **não** substituem a prova do data-engine. A prova canônica exige, no repo, **teste + fixture + comando fail-closed no CI** que:
1. execute **2 rodadas** sobre o **mesmo** raw + rubric `(version,hash)` + `resolver_version`/`rule_version` + decisões replayable;
2. ordene a projeção canônica por **report / rank / artista**;
3. compare **byte-a-byte** os campos de negócio/evidências, **excluindo** UUIDs e timestamps operacionais (`id`, `created_at`, `published_at`);
4. **falhe** em qualquer divergência de valor, ordem ou evidência.

O DDL desta fase **habilita** a prova (versões/overrides com chave natural congelados na evidência; proveniência referencial até o raw; linhagem publicada inviolável), mas a execução é responsabilidade do data-engine. **Rastrear P5-REPRO-01 fora deste apply** (owner: Data/AI + Backend/DevOps no pipeline).
