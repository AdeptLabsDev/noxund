# Handoff — [DB] Fase 4 `run_migration` (Apply) · CLOSEOUT pós-apply · Database Agent

## 1. Identificação
- **Tarefa:** `task_phase4_run_migration_closeout` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only)**
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-06-27
- **Environment:** `production-db` · **Supersede:** estado `needs_review` de `HANDOFF-phase4-design.md` (banner de resolução aplicado).
- **Migration aplicada:** `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (forward-only, atômica).

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

O apply gated da Fase 4 **já foi executado em CI a partir de `main`** pelo Product Lead, com `guard`,
`apply` e `verify` verdes. Este é o `completed` com **evidência real** (onboarding §5 — nada forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback, **não**
executou DDL/DML novo, **não tocou o raw**. Apenas ratifica repo-side o run já aprovado e executado
e emite a evidência canônica — fechando a lacuna de proveniência OD-PROV-02 (lição da Fase 2).

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | `phase4-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28277270507 |
| Origem do run | branch **`main`** (SEC-F18 — origem reconfirmada pelo reviewer) |
| Confirmação de intenção | job `guard` (`APPLY-PHASE4`) → **success** |
| Apply | job `apply` (`supabase db push`, forward-only) → **success** |
| Verificação pós-apply | job `verify` (`phase4_post_apply_verify.sql`, `psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — Phase 4 post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev**, origem `main`, rollback de produção **não** executado |

> O job `verify` levanta exceção em qualquer divergência (job vermelho em falha). **Verde =
> todas as asserções §4/§5 seguraram.** Os logs por-asserção vivem no run (URL acima) — fonte
> autoritativa. Confirmei repo-side que a **linha final do verify bate VERBATIM** com a evidência
> (`phase4_post_apply_verify.sql` L281) e que a migration referenciada é a que autorei. Não
> re-busquei o run ao vivo (sem `gh`/rede); tomo o run de CI como evidência de registro.

## 3. Ratificação repo-side (os 4 itens da tarefa — conferidos linha a linha)

| # | Item | Veredito | Evidência (no repo) |
|---|---|---|---|
| 1 | Migration aplicada **==** a autorada; forward-only, atômica | ✅ | `20260620000004_phase4_raw_youtube_snapshots.sql`: `begin` (L37) … `commit` (L188); só `create`/`enable rls`/`revoke`/`comment` — **zero** drop/delete/truncate. |
| 2 | Linha final do `verify` **verbatim** | ✅ | L281: `OK — Phase 4 post-apply verification PASSED (§4 structural + §5 empirical).` — idêntica ao `verify_final` da evidência. |
| 3 | 3 tabelas raw + 2 funções + 6 triggers + 3 CHECK SEC-F08 + 3 FK→report_runs | ✅ | Tabelas: `_search_pages` (L72), `_videos` (L97), `_channels` (L128). Funções: `raw_youtube_immutable()` (L46), `raw_youtube_no_truncate()` (L57). Triggers (L151/154/158/161/165/168). CHECK `*_no_request_context` (L80/L109/L138). FK `references public.report_runs (id) on delete restrict` (L74/L99/L130). |
| 4 | Nada downstream destravado — veto Fase 9 (RLS Policies, SEC-0001 §0) de pé | ✅ | `grep "create policy"` na migration → **NONE** (default-deny puro; `enable row level security` + `revoke` apenas). Nenhuma policy adicionada. |

## 4. Gate board do `run_migration` Fase 4 — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| DDL + verify aprovados pelo Security (matrix #3, `review_rls`) | **SEC-0012** — "✅ LIBERADO, sem bloqueio" | ✅ |
| Data/AI #4 (imutabilidade/reprodutibilidade do raw, `validate_reproducibility`) | **DATA-AI-0004** — "Aprovado, sem veto metodológico" | ✅ |
| Pipeline de apply auditada (matrix #8, `audit_secrets`) | **SEC-0013** — "✅ sem bloqueio; espelho da Fase 3 endurecida" | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28277270507` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28277270507` | ✅ guard·apply·verify success |

## 5. O que o `verify` provou em banco (autoritativo)
- **§4 estrutural:** 3 tabelas raw; 2 funções de imutabilidade com `search_path` pinado; 6 triggers
  (2/tabela); 3 índices de unicidade lógica; 3 FK → `report_runs`; 3 CHECK SEC-F08; RLS-on nas 3.
- **§5 empírico (raw SAGRADO, nos 2 caminhos de role):**
  - `UPDATE`/`DELETE`/`TRUNCATE` nas 3 tabelas como **grant-holder (`postgres`)** → bloqueado pelo
    **trigger** (`restrict_violation`) — prova positiva de que a imutabilidade é o trigger, não a
    ausência de grant (SEC-F22).
  - Mesmas operações como **`service_role`** → bloqueado por trigger **OU** grant
    (`restrict_violation`/`insufficient_privilege`, SEC-F21) — sem falso-negativo (lição DEC-0009
    embutida **antes** do apply, ao contrário do hotfix da Fase 3).
  - **SEC-F08:** corpo de resposta limpo **ACEITO**; envelope de request (`config`/`request`/`key`)
    **REJEITADO** (`check_violation`) — scrub provado no schema.
  - **Unicidade lógica** `(run_id, video_id)` → `unique_violation`. **Default-deny:**
    `anon`/`authenticated` → `insufficient_privilege` nas 3.
  - **Efeito colateral nulo:** as únicas escritas do `verify` são probes em transações revertidas.

## 6. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado — §8, não executado).
- [x] Raw **sem rota de update** — imutabilidade total provada em banco (§5).
- [x] RLS testada — RLS-on nas 3 + default-deny `anon`/`authenticated` (§5).
- [x] Revisões acionadas — Security #3 (SEC-0012), Data/AI #4 (DATA-AI-0004), pipeline #8 (SEC-0013), reviewer em runtime.
- [x] Handoff preenchido (este documento).

## 7. Arquivos
- `docs/database/HANDOFF-phase4-apply-closeout.md` — **criado** (este closeout evidenciado).
- `docs/database/HANDOFF-phase4-design.md` — **modificado**: banner de resolução apontando para este closeout (evita leitura stale do estado `needs_review`/revisões ⏳).
- **Nenhuma mudança de código/SQL.** Migration, rollback e `verify` já versionados; o apply ocorreu em CI.

## 8. Rollback (rede de segurança — NÃO executado)
- `supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql` permanece declarado e
  reversível. **Não** foi aplicado. **Raw sagrado:** em produção raw não se apaga; o rollback só é
  admissível para run(s) descartável(is). `rollback_producao` = **NÃO executado** (confirma a evidência).

## 9. Carry-forward (não-bloqueante — registrado, não é gate deste closeout)
- **SEC-F23 (de SEC-0012):** o scrub autoritativo do payload e a higiene de log (SEC-F08/SEC-F10) são
  gate de **pipeline** (Data/AI + Backend + DevOps) quando a coleta real for ligada — **não** de schema.
  O CHECK top-level já entregue é defesa-em-profundidade suficiente na camada de banco; o extrair-só-o-body
  e o scrub de logs ficam para as fases de coleta/handlers. Sem trava sobre este apply.

## 10. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 3 tabelas RAW (`04_ §4`); **zero** marketplace/Fase 2 (`04_ §12`).
- **Não-negociáveis provados em banco:** **raw imutável** (trigger abaixo do service_role),
  **default-deny** (anon/authenticated), **proveniência** por `run_id`, **rastreabilidade** até
  `raw_youtube_videos`, **secrets fora de repo/log/payload** (SEC-F08 no schema; SEC-0013 confirma pipeline limpa).

## 11. Próximos passos
1. **Product Orchestrator (`record_decision`):** registrar **DEC-0011-phase4-apply-completed** no decision
   log (run `28277270507`, origem `main`, reviewer AdeptLabsDev; gate board §4 fechado).
2. **Fundação seguinte:** Fase 5 — Computed Metrics + Resolução + Relatório (`video_artist_mappings`,
   `channel_eligibility`, `artist_metrics`, depois `reports`, `report_items`), na ordem do
   `migration-plan.md` (owner `database_agent`; depende de OD-DB-06/07 já fechados; Data/AI + Backend no laço).
3. **Veto que continua de pé:** Fase 9 — RLS Policies (SEC-0001 §0). Este apply **não** o destrava.

## 12. Open decisions / bloqueios
- **Nenhum bloqueio.** `task_phase4_run_migration_closeout` transiciona → **`completed`**.
- Gates sensíveis downstream (Fase 5+, RLS da Fase 9) permanecem **intactos** e exigem suas próprias revisões.
