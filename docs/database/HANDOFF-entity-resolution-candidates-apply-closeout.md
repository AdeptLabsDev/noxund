# Handoff — [DB] entity_resolution_candidates `run_migration` (Apply) · CLOSEOUT pós-apply · Database Agent

## 1. Identificação
- **Tarefa:** `task_entity_candidates_run_migration_closeout` · **Action:** `run_migration` (sensível/gated) — **closeout evidenciado (record-only, `no_db_mutation`)**
- **Owner agent:** Database (`database_agent`) · **Data:** 2026-06-29
- **Environment:** `production-db` · **Supersede:** estado design/`needs_review` de `HANDOFF-entity-resolution-candidates-design.md` (banner de resolução aplicado).
- **Migration aplicada:** `supabase/migrations/20260620000006_entity_resolution_candidates.sql` (forward-only, atômica) — extensão **aditiva** DEC-0014, versão corrigida pós DATA-ENTITY-F01.

## 2. Status — ✅ APLICADO E VERIFICADO (em CI), com evidência

O apply gated da extensão `entity_resolution_candidates` **já foi executado em CI a partir de `main`** (workflow dedicado `entity-db-apply.yml`, autorado por DevOps — o blocker do design anterior foi resolvido), com `guard`, `preflight`, `apply` e `verify` verdes. Este é o `completed` com **evidência real** (onboarding §5 — nada forjado).

**Record-only:** este closeout **não reaplicou** a migration, **não** rodou o rollback, **não** executou DDL/DML novo, **não tocou dado**. Apenas ratifica repo-side o run já aprovado e executado e emite a evidência canônica — fechando a convenção closeout+DEC das Fases 1–5 (precedente DEC-0010/0012).

### 2.1 Evidência do apply
| Item | Evidência |
|---|---|
| Run do pipeline | `entity-db-apply.yml` → https://github.com/AdeptLabsDev/noxund/actions/runs/28343949123 |
| Origem do run | branch **`main`** (SEC-F18 — dispatch restrito/least-privilege) |
| Confirmação de intenção | job `guard` (frase **`APPLY-ENTITY-CANDIDATES`**) → **success** |
| Pré-flight de escopo | `preflight` (`db push --dry-run`) → **success** — pendentes confirmados **== {20260620000006}** (0007 **não** entra) |
| Apply | `apply` (`supabase db push`, forward-only) → **success** — somente `20260620000006_entity_resolution_candidates.sql` |
| Verificação pós-apply | `verify` (`entity_resolution_candidates_post_apply_verify.sql`, `psql -v ON_ERROR_STOP=1`) → **success** |
| Saída do `verify` | `OK — entity_resolution_candidates post-apply verification PASSED (§4 structural + §5 empirical).` |
| Aprovação humana em runtime | required reviewer **AdeptLabsDev**, origem `main`, rollback de produção **não** executado |
| Escopo-negativa | **`0007`/producer_events NÃO aplicado** (parked); **Fase 9 / RLS Policies / VIEW pública NÃO tocada** |

> O job `verify` levanta exceção em qualquer divergência (job vermelho em falha). **Verde = todas as
> asserções §4/§5 seguraram** (incl. os probes **F01 non-blank** a/a′/b/c/d/d′). Os logs por-asserção
> vivem no run (URL acima) — fonte autoritativa. **Não** re-busquei o run ao vivo (sem `gh`/rede) →
> tomo o run de CI como evidência de registro, idêntico aos closeouts das Fases 4/5.

## 3. Ratificação repo-side (os 4 itens — conferidos)

| # | Item | Veredito | Evidência (no repo) |
|---|---|---|---|
| 1 | Migration aplicada **==** a autorada | ✅ | A migration/verify/rollback aplicados vivem no commit **`9a1ac52`** (`infra(entity-resolution): … gated apply (DEC-0014)`, branch `db/entity-resolution-candidates-apply` + `origin/`). Os 3 artefatos do meu working tree são **byte-idênticos** ao commit aplicado — confirmado por **sha256** do conteúdo (zero CRLF nos dois lados; identidade real de bytes), não só por nome. |
| 2 | Linha final do `verify` **verbatim** | ✅ | working tree e `9a1ac52`: `OK — entity_resolution_candidates post-apply verification PASSED (§4 structural + §5 empirical).` — idênticas. |
| 3 | Forward-only / atômica / **aditiva** | ✅ | `begin` (L44) … `commit` (L134); **zero** `drop/truncate/delete from` executável; **único** `alter table` é `enable row level security` na tabela **nova** (L127). **ZERO ALTER** de tabela aplicada/congelada; **`public.video_artist_method` NÃO recriado** (reusado da Fase 5). |
| 4 | Nada downstream destravado | ✅ | `grep -i "create policy\|create view"` → as ocorrências são **comentário** (default-deny puro: `enable rls` L127 + `revoke` L132). **Fase 9 vetada intacta** (SEC-0001 §0). |

## 4. Inventário estrutural ratificado (line cites contra o arquivo aplicado)
- **1 tabela NOVA:** `entity_resolution_candidates` (L64). **1 enum novo:** `entity_candidate_status` (L53); **reusa** `public.video_artist_method` (Fase 5 — não recriado).
- **3 FK, todas `ON DELETE RESTRICT`:** `run_id → report_runs` (L66), `artist_id → artists` (L69, nullable), composta nomeada `entity_resolution_candidates_raw_video_fk (run_id, video_id) → raw_youtube_videos` (L79).
- **4 CHECK:** `llm_prompt_chk` (L81), `reviewed_at_chk` (L84), **`resolver_version_nonblank_chk`** (L89, `btrim<>''` — F01), **`prompt_version_nonblank_chk`** (L93, `IS NULL OR btrim<>''` — F01). Todos **storage-only** (zero número/threshold).
- **4 índices:** dedup **UNIQUE+PARTIAL** `pending_uidx (run_id, video_id) WHERE status='pending'` (L101); fila parcial `pending_queue_idx` (L106); `run_status_idx` (L111); parcial `artist_idx WHERE artist_id IS NOT NULL` (L115).
- **0 trigger** (staging mutável por design). **RLS-on** (L127) + **`revoke` anon/authenticated** (L132) — default-deny.

## 5. O que o `verify` provou em banco (autoritativo)
- **§4 estrutural:** tabela; enum novo + `video_artist_method` reusado; colunas + NOT NULL/nullable corretos; `status` default `pending`; FK composta nomeada → raw (colunas+RESTRICT); FK→report_runs/→artists; **todas as FK RESTRICT**; **4 CHECK** (incl. os 2 non-blank F01); 4 índices; dedup **UNIQUE+PARTIAL**; **ZERO trigger** (mutável); RLS-on; **zero policies**.
- **§5 empírico (probes revertidos, 2 caminhos de role onde aplicável):** **proveniência** (vídeo ausente/de outro run → `foreign_key_violation`; coerente + `artist_id` null aceitos) · **status default** = pending · **mutabilidade** (UPDATE pending→rejected aceito — prova positiva, sem fingir imutabilidade) · **dedup** (2º pendente mesmo (run,vídeo) → `unique_violation`; após resolver, novo pendente aceito) · **prompt CHECK** · **reviewed_at CHECK** · **DATA-ENTITY-F01** (`resolver_version=''`/`'   '` → `check_violation`; `prompt_version=''` → `check_violation`; non-blank/`null`-regex/`llm` non-blank → aceitos) · **default-deny** (anon/authenticated → `insufficient_privilege`). **Efeito colateral nulo** (probes em transações revertidas; helpers `pg_temp` da sessão).

## 6. Definition of Done (database-agent.md) — checada
- [x] Migration **aplica** (evidência §2.1) e **reverte** (rollback declarado — §8, não executado).
- [x] **Aditiva sem regressão:** zero ALTER de tabela aplicada; `video_artist_method` intacto; `0007` parked.
- [x] **Proveniência** até o raw por FK composta RESTRICT; candidato não-aprovado fora de `artists`/`video_artist_mappings`.
- [x] **Determinismo:** versões non-blank (F01) garantem replay rastreável; fila de nomes, **zero número**.
- [x] RLS testada — RLS-on + default-deny `anon`/`authenticated`.
- [x] Revisões acionadas — Database (autor), Security (**SEC-0017**, sem re-review após F01), Data/AI (**re-review F01 levantado**).
- [x] Handoff preenchido (este documento).

## 7. Gate board do `run_migration` entity_resolution_candidates — TODOS FECHADOS
| Gate | Fonte | Estado |
|---|---|---|
| Database (schema) — autoria + mitigação F01 | `HANDOFF-entity-resolution-candidates-design.md` | ✅ |
| Security & Privacy (matrix #3 — RLS/PII/SEC-F08) | **SEC-0017** (superfície inalterada por F01 → sem re-review) | ✅ |
| Data/AI (integridade da fila + replay) | veto **DATA-ENTITY-F01** → **levantado** no re-review pós-mitigação | ✅ |
| Workflow gated dedicado | `entity-db-apply.yml` (DevOps; commit `9a1ac52`) | ✅ |
| Required reviewers em CI (origem `main`, SEC-F18) | run `28343949123` | ✅ AdeptLabsDev |
| Apply forward-only + verify §4/§5 fail-closed | run `28343949123` | ✅ guard·preflight·apply·verify success |

## 8. Rollback (rede de segurança — NÃO executado)
`supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql` permanece declarado e reversível: drop tabela (índices/constraints/FKs caem junto) → drop enum novo. **NUNCA** dropa `public.video_artist_method` (Fase 5, reusado). **Não** foi aplicado (`rollback_production` = NÃO executado — confirma a evidência; o contrato do workflow só dispara rollback se o verify falhar, o que não ocorreu). Baixo risco (fila mutável; decisões já tomadas sobrevivem em `audit_events`/`overrides[]`).

## 9. Impacto no escopo / não-negociáveis
- **MVP travado?** Sim. 1 tabela **aditiva** de staging da única zona de IA; **zero** marketplace/Fase 2; **zero** ALTER de tabela aplicada.
- **Não-negociáveis provados em banco no run:** **aditivo-não-destrutivo**, **proveniência** até raw (FK composta RESTRICT), **IA não gera número** (fila de nomes; versões non-blank garantem replay), **default-deny vivo** (RLS-on + zero policy), candidato não-aprovado **fora** de `artists`/`video_artist_mappings`, replay/override em `audit_events`/`metrics_detail_json.overrides[]`, **Fase 9 vetada** intacta.

## 10. Carry-forward (não-bloqueante — registrado, não é gate deste apply)
- **`data_agent`** re-alinha `DATA-ENTITY-001` ao schema final aplicado e retoma a implementação: resolver/fixtures (regex-first + LLM fallback restrito) → Channel Filter → scoring → **P5-REPRO-01** (gate do data-engine antes do 1º publish — não deste apply).
- **`producer_events` (Fase 6, ts `0007`)** segue **parked em design** até a captura de eventos virar gargalo (DEC-0013).

## 11. Arquivos
- `docs/database/HANDOFF-entity-resolution-candidates-apply-closeout.md` — **criado** (este closeout evidenciado).
- `docs/database/HANDOFF-entity-resolution-candidates-design.md` — **modificado**: banner de resolução (design → **APLICADO E VERIFICADO em CI**).
- `docs/product/decisions/DEC-0015-entity-candidates-apply-completed.md` — **registrado** (convenção closeout+DEC; referencia/fecha DEC-0014; matrix #10 confirmada pelo Product Orchestrator).
- **Nenhuma mudança de código/SQL.** Migration, rollback, verify e workflow já versionados (commit `9a1ac52`) e aplicados em CI.

## 12. Próximos passos / open decisions
- **Nenhum bloqueio.** `task_entity_candidates_run_migration_closeout` transiciona → **`completed`**.
- **Decisão registrada:** **DEC-0015**-entity-candidates-apply-completed (run `28343949123`, origem `main`, reviewer AdeptLabsDev; gate board §7 fechado; fecha DEC-0014).
- **Sequência de schema:** Fase 1 (DEC-0008) → 2 (DEC-0010) → 3 (DEC-0009) → 4 (DEC-0011) → 5 (DEC-0012) → **entity_resolution_candidates (DEC-0015)**; Fase 6 `producer_events` (`0007`) parked.
- **Veto que continua de pé:** Fase 9 — RLS Policies + VIEW pública (SEC-0001 §0). Este apply **não** o destrava.
