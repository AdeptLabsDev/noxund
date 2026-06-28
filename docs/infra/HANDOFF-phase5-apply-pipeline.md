# Handoff — `task_phase5_devops_apply_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase5_devops_apply_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-27
- **Prioridade:** P1 (high)
- **Fase:** 5 — Computed Metrics + Resolução + Relatório (`video_artist_mappings`, `channel_eligibility`, `artist_metrics`, `artist_metric_videos`, `reports`, `report_items`)
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Predecessoras liberadas:** Data/AI re-review `validate_reproducibility` (DATA-AI-0006 · DATA-RR-F5-03A/05A/06A/01A) ✅ · Security #3 `review_rls` (**SEC-0014** — APROVADO, sem bloqueio) ✅ · Backend BE-0002 (contrato de consumo de `artist_metric_id`) ✅ completed.

## 2. Objetivo
Autorar a **pipeline de apply GATED da Fase 5** (`phase5-db-apply.yml`), espelhando integralmente o
hardening aprovado das Fases 1–4. **Nenhum apply** — o `run_migration` segue gated/humano (decisão
subsequente do Orchestrator). **Não toquei** a migration, o rollback nem o verify (já autorados pela
Database e liberados por Data/AI + Security #3). **Não destravo a Fase 9.**

## 3. Critério de aceite (do payload)
1. `phase5-db-apply.yml` espelhando phase4: `workflow_dispatch` + `confirm = APPLY-PHASE5`, job `guard`, job `apply` no Environment `production-db` (required reviewers DevOps+Security), job `verify`.
2. Hardening preservado: actions SHA-pinned (SEC-F17), DB URL mascarada, secrets só do Environment (nunca ecoados/versionados), service-role não usado (SEC-F19), Environment restrito a `main` (SEC-F18).
3. Apply atômico forward-only (`db push` da migration pendente da Fase 5; **sem rollback em produção** — HANDOFF §8); verify fail-closed (`ON_ERROR_STOP=1`) rodando `phase5_post_apply_verify.sql` com prova nos 2 role-paths (DEC-0009).
4. A autoria NÃO aplica nada; `run_migration` permanece gated (humano + required reviewers em runtime); Fase 9 não destravada.
5. `next_recommendation`: `security_agent:audit_secrets` (#8 delta) sobre o novo pipeline → depois `run_migration` gated por último; se houver achado de secret/credencial, volta ao DevOps.

## 4. Resultado
- [x] **Critério 1 — estrutura espelhada.** `on: workflow_dispatch` único (zero `push`/`schedule`); job `guard` aborta com `exit 1` se `inputs.confirm != "APPLY-PHASE5"`; job `apply` (`needs: guard`) e job `verify` (`needs: apply`) ambos em `environment: production-db`; `concurrency.group: phase5-db-apply`, `cancel-in-progress: false`.
- [x] **Critério 2 — hardening preservado.** **3 actions SHA-pinadas** (checkout `34e1148…` v4.3.1 ×2, setup-cli `ab05898…` v1.7.1 — **mesmas SHAs** do phase4); URL via session pooler **mascarada** (`::add-mask::`), senha URL-encoded (`jq @uri`); secrets/vars lidos **só** do Environment `production-db` (`secrets.*`/`vars.*`), nunca ecoados nem escritos em arquivo versionado; `permissions: contents: read`; **service-role key não referenciada** (SEC-F19); Environment restrito a `main` (SEC-F18, deployment-branch rule).
- [x] **Critério 3 — apply atômico forward-only + verify fail-closed.** `supabase db push --db-url "$SUPABASE_DB_URL"` aplica só a migration pendente da Fase 5 (Fases 1–4 já trackeadas); migration `begin/commit` ⇒ atômica (erro ⇒ exit ≠ 0 ⇒ job falha, sem estado parcial). **Rollback NÃO roda no pipeline** (HANDOFF §8: publicado é congelado; computed é a cadeia de proveniência; rollback só p/ runs descartáveis). Job `verify` roda `psql … -v ON_ERROR_STOP=1 -f supabase/tests/phase5_post_apply_verify.sql` → §4 estrutural + §5 empírico, com paridade de errcode nos 2 role-paths (DEC-0009) e os probes F5-03A/05A/06A/01A.
- [x] **Critério 4 — não aplica nada.** Autoria de YAML apenas; `run_migration` permanece gated (humano + required reviewers em runtime). **Zero** `create policy` / `create view` tocados — Fase 9 segue vetada (SEC-0001 §0).
- [x] **Critério 5 — este handoff** + `next_recommendation` → Security `audit_secrets` (§ AgentResult).

**Como verificar (paridade + higiene):**
`grep -nE 'uses:.*@(v[0-9]+|main|master|latest)' .github/workflows/phase5-db-apply.yml` → vazio ·
`grep -n 'APPLY-PHASE5' .github/workflows/phase5-db-apply.yml` → presente (description + guard) ·
o job `verify` aponta para `supabase/tests/phase5_post_apply_verify.sql`.

## 5. Arquivos alterados
- `.github/workflows/phase5-db-apply.yml` — **criado**: pipeline de apply gated da Fase 5.

**Intocados (constraint):** `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`,
`supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql`,
`supabase/tests/phase5_post_apply_verify.sql`. `git status` confirma só o workflow novo.

## 6. Diferenças vs. Fase 4 (paridade consciente)
- **Frase:** `APPLY-PHASE5` (não `APPLY-PHASE4`); `concurrency.group: phase5-db-apply`.
- **Objetos aplicados (delta comentado no YAML):** **6 tabelas** + **3 enums** + **7 funções** (5 guards de trigger + 2 validadores de evidência IMMUTABLE) + **7 triggers** + **16 FKs** todas `ON DELETE RESTRICT` + **2 CHECKs de evidência estrutural** + `reports_published_at_chk` + RLS-enable/revoke nas 6 + **ZERO policy / ZERO VIEW** (Fase 9 vetada). (Fase 4: 3 tabelas raw / 2 funções / 6 triggers / 3 CHECKs SEC-F08 / 3 FKs.)
- **Verify (delta DEC-0009 + follow-on, já autorado pela Database):** caminho **grant-holder** asserta `restrict_violation`/`foreign_key_violation`/`check_violation`/`not_null_violation` (prova positiva, SEC-F22); caminho **service_role** tolera `… OR insufficient_privilege` (SEC-F21). Inclui os probes **F5-03A** (move input não-publicado→publicado bloqueado nos 2 paths), **F5-05A** (`{}`/seção ausente → `check_violation`), **F5-06A** (versões/overrides com chave natural obrigatórios), **F5-01A** (move draft→published no 2º role-path). **Eu não autorei o SQL — apenas o wiring fail-closed casa com ele** (confirmado contra SEC-0014 §6).
- **`db push`:** aplica só o pendente (Fases 1–4 já trackeadas) = a migration da Fase 5.
- **Rollback:** **nunca** no caminho de apply — publicado é congelado e o computed é a cadeia de proveniência (HANDOFF §8).

## 7. Impacto no escopo
- **MVP travado?** Sim. Só pipeline de apply; nada de Fase 2-produto/marketplace; stack inalterada.
- **Non-negotiable?** Reforça: **número sai de código determinístico, nunca de IA** (DDL storage-only — apply não introduz cálculo); **snapshot congelado** + **linhagem publicada inviolável** (provados no verify, abaixo do service_role); **proveniência referencial até o raw**; **secrets fora de repo/log/payload** (URL mascarada, SEC-F19); supply chain (SHA-pin, SEC-F17). **Nenhum apply**; zero secret no repo/log.
- **Pontos fortes preservados:** `contents: read`, manual-only + frase, required reviewers, Environment restrito a `main`, URL mascarada, apply atômico forward-only, verify fail-closed nos 2 role-paths.

## 8. Validação executada
- **Estrutural (grep, evidenciado):**
  - SHA-pins presentes: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (×2), `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1` → **3 pins** (idênticas ao phase4).
  - Tag mutável (`@v*`/`@main`/`@master`/`@latest` em `uses:`): **0 matches**.
  - `SERVICE_ROLE_KEY`/`service_role_key`/`SUPABASE_SERVICE`: **0 matches**.
  - Valor literal de secret (`eyJ…`, URL postgres literal, `AIza…`, `sb_secret`, senha inline): **0 matches** — só indireções `${{ secrets.* }}`.
  - Wiring confirmado: `APPLY-PHASE5` (description + guard), `environment: production-db` (apply+verify), `::add-mask::`, `db push --db-url`, verify→`phase5_post_apply_verify.sql`, `ON_ERROR_STOP=1`.
- **Apply:** **não executado** (constraint). A validação funcional do verify roda no 1º dispatch gated, pós-merge + Environment.

> Nota de paridade: `supabase/setup-cli` mantém `version: latest` (versão **da CLI**, não tag de action — a action está SHA-pinada), idêntico às Fases 1–4.

## 9. Riscos
- **Alvos de FK até o raw (Fase 4) devem existir no remoto:** as FKs compostas da Fase 5 apontam para os índices únicos `raw_youtube_videos (run_id, video_id)` / `raw_youtube_channels (run_id, channel_id)` (Fase 4) e `rubric_versions (version, hash)` (Fase 2). Se o ambiente não tiver as Fases 1–4 aplicadas, o **próprio `db push`** (atômico) falha **antes** do verify — sinal a investigar, não estado parcial. (Sequência de apply 1→5 é precondição operacional.)
- **Imutabilidade/freeze nos 2 role-paths:** o verify assume o threat model SEC-0014 (service_role retém grants; trigger barra abaixo dele). Divergência de grants num ambiente faz o verify sinalizar — sem falso-negativo silencioso.
- **Drift de versão de actions:** SHA-pin congela; re-pinar conscientemente a cada bump (mesmas SHAs das Fases 1–4 — re-pin coordenado).
- **Merge:** sem push direto na `main` (global rule #12) — PR + revisão.
- **Fora deste apply:** **P5-REPRO-01** (prova canônica de 2 rodadas) é gate do `services/data-engine`/primeiro publish, **não** do migration apply (HANDOFF §12). Não bloqueia esta autoria.

## 10. Revisões necessárias
- [ ] ⏳ **Security — `audit_secrets` (matrix #8)** sobre esta pipeline de apply da Fase 5. Revisão de **delta** sobre as Fases 1–4 já aprovadas (mesmos patterns endurecidos; só muda frase/concurrency/objetos/verify-target). SEC-0014 §6 já listou este pipeline como `⏳ ainda não autorada/auditada` — agora autorada, segue para auditoria. **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).

## 11. Quadro de gates residual do `run_migration` (Fase 5)
| Gate | Estado |
|---|---|
| Data/AI #4/#5 (`validate_reproducibility` re-review — DATA-RR-F5-03A/05A/06A/01A) | ✅ baixado (AgentResult; backfill DATA-AI-0007 recomendado) |
| Security `review_rls` do SQL + verify (matrix #3) — **SEC-0014** | ✅ baixado (APROVADO, sem bloqueio) |
| Backend — consumo de `artist_metric_id`/snapshot (BE-0002) | ✅ completed |
| **Pipeline de apply gated de paridade (DevOps, matrix #8)** | ✅ **entregue aqui** |
| Security `audit_secrets` da pipeline (matrix #8) | ⏳ recomendada (delta) — `next_recommendation` |
| PR revisado + merge na `main` (sem push direto) | ⏳ |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (como nas Fases 1–4) |
| Fase 9 — RLS Policies + VIEW pública de `report_items` (SEC-F03) | ⛔ **veto à parte de pé** (SEC-0001 §0) — **não tocado aqui** |
| P5-REPRO-01 (prova de 2 rodadas) | ⏳ gate do data-engine/publish — fora deste apply |

## 12. Próximos passos
1. **Security (`audit_secrets`):** revisar a pipeline da Fase 5 (delta vs. Fases 1–4) → baixar/condicionar. Se houver achado de secret/credencial, **volta ao DevOps**.
2. **Merge do PR** (branch + revisão; nunca push na `main`).
3. **Database (`run_migration`, gated):** dispara `phase5-db-apply.yml` → digita `APPLY-PHASE5` → required reviewers aprovam → apply atômico + verify §4/§5 fail-closed (2 role-paths).
4. Segue **Fase 6** (`producer_events`, append-only) na ordem do `migration-plan.md`.

## 13. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** A paridade exigida está entregue. Os gates restantes
  (Security `audit_secrets` da pipeline, humano + reviewers) são downstream e **intactos**;
  os vetos da Fase 9 (RLS Policies + VIEW pública de `report_items`) permanecem de pé e fora do
  escopo desta tarefa. Nenhum secret/credencial novo foi necessário — não houve retorno ao Orchestrator.

---

### `next_recommendation` (AgentResult)
```json
{
  "status": "completed",
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Matrix #8 (Deploy/ambiente -> DevOps+Security): pipeline de apply gated da Fase 5 autorada (phase5-db-apply.yml), espelhando o hardening aprovado das Fases 1-4. Revisao de delta de secrets/supply-chain (SEC-0014 §6 ja listava o pipeline como pendente) destrava o gate humano do run_migration. Se houver achado de secret/credencial, volta ao DevOps. Apply segue barrado; Fase 9 nao destravada.",
    "evidence": {
      "file": ".github/workflows/phase5-db-apply.yml",
      "hygiene": "3 SHA-pins (mesmas do phase4); 0 tag mutavel; 0 valor de secret; 0 SERVICE_ROLE_KEY",
      "parity": "workflow_dispatch only + APPLY-PHASE5 + production-db + URL mascarada + push atomico forward-only + verify->phase5_post_apply_verify.sql (ON_ERROR_STOP=1, 2 role-paths DEC-0009, probes F5-03A/05A/06A/01A)",
      "untouched": ["migration", "rollback", "verify"]
    }
  }
}
```
