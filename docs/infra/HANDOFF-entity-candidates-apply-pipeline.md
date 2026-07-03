# Handoff — `task_entity_candidates_author_apply_workflow` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_entity_candidates_author_apply_workflow` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-28
- **Prioridade:** P1 (high)
- **Escopo:** Extensão aditiva **DEC-0014** — `entity_resolution_candidates` (fila de revisão da Entity Resolution). Migration `20260620000006`.
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`
- **Desbloqueia:** `database_agent` `run_migration` (estava **BLOCKED**: workflow gated dedicado ausente + sem capacidade de execução no sandbox; apply é via CI disparado por humano + required reviewers).

## 2. Objetivo
Autorar `.github/workflows/entity-db-apply.yml` — mirror **fiel e endurecido** de `phase5-db-apply.yml`,
parametrizado para a DEC-0014, **garantindo que o apply alcance SOMENTE a migration 0006** e **nunca**
0007/`producer_events`. **Nenhum apply** — `run_migration` segue gated/humano. **Não destrava a Fase 9.**

## 3. Critério de aceite (do payload)
1. Mirror fiel + SHA-pinned de phase5 (manual-only, `guard→apply→verify`, Environment `production-db` + required reviewers, SEC-F18 dispatch-de-`main`, `ON_ERROR_STOP=1`, service-role não usado, `begin/commit` atômico).
2. Parametrizar p/ DEC-0014: confirm phrase + concurrency group **distintos**; job `verify` roda `entity_resolution_candidates_post_apply_verify.sql`.
3. **GARANTIR escopo de apply = SOMENTE `20260620000006`**, nunca 0007 — declarar o mecanismo (só 0006 em `main`; 0007 parked) + **preflight fail-closed** que aborta se pendentes != {0006}.
4. Reusar o Environment `production-db` existente (sem secrets/vars novos; sem `configure_env`).
5. Documentar o caminho de landing em `main` (revisado, sem push direto; 0007 excluído) e sinalizar à Security qualquer desvio do template phase5 (matrix #8).
6. Não destravar Fase 9 e não autorar nada que aplique 0007.

## 4. Resultado
- [x] **Critério 1 — mirror fiel.** Mesma espinha de phase5: `on: workflow_dispatch` único (zero `push`/`schedule`); job `guard` (frase) → `apply` (`needs: guard`) → `verify` (`needs: apply`), `apply`+`verify` em `environment: production-db`; **3 actions SHA-pinadas** (checkout `34e1148…` v4.3.1 ×2, setup-cli `ab05898…` v1.7.1 — **mesmas SHAs** de phase4/5); `permissions: contents: read`; URL via session pooler **mascarada** (`::add-mask::`, `jq @uri`); **service-role não usado** (SEC-F19); SEC-F18 (Environment restrito a `main`); `db push` atômico (migration `begin/commit`).
- [x] **Critério 2 — parametrização DEC-0014.** `name: Entity Resolution Candidates · DB Apply (gated) — DEC-0014`; confirm phrase **`APPLY-ENTITY-CANDIDATES`** (distinta de `APPLY-PHASE5`); `concurrency.group: entity-db-apply` (distinto); job `verify` → `supabase/tests/entity_resolution_candidates_post_apply_verify.sql`.
- [x] **Critério 3 — escopo SOMENTE 0006 + preflight fail-closed.** Ver §5 (mecanismo) e §6 (preflight). Step dedicado **"Preflight — assert apply scope is EXACTLY {0006}"** roda **antes** do apply real e aborta sem aplicar se a condição falhar.
- [x] **Critério 4 — reúso de Environment.** `production-db` existente: mesmos `secrets.SUPABASE_DB_PASSWORD`/`SUPABASE_ACCESS_TOKEN` + `vars.SUPABASE_DB_HOST`/`PORT`/`USER` + required reviewers. **Zero** secret/var novo; **zero** `configure_env`.
- [x] **Critério 5 — landing + sinalização Security.** Ver §7 (governança/landing) e §10 (revisões). Mirror fiel ⇒ herda governança SEC-0014/phase5; **nenhum desvio** de template introduzido (sem novas permissions/secrets/triggers, sem gate relaxado, sem `on:push/schedule`).
- [x] **Critério 6 — não destrava Fase 9, não aplica 0007.** Workflow toca **zero** `create policy`/`create view`; o preflight **proíbe** ativamente 0007. A migration 0006 é aditiva (DEC-0014 §3): só CREATE de tabela/enum/índices, zero ALTER de tabela aplicada/congelada.

**Como verificar (paridade + higiene + escopo):**
`grep -nE 'uses:.*@(v[0-9]+|main|master|latest)' .github/workflows/entity-db-apply.yml` → vazio ·
`grep -n 'APPLY-ENTITY-CANDIDATES' .github/workflows/entity-db-apply.yml` → presente ·
`grep -nE 'on:\s*$|push:|schedule:' …` → só `on:` (workflow_dispatch) ·
o job `verify` aponta para `…/entity_resolution_candidates_post_apply_verify.sql`.

## 5. Mecanismo de escopo (declarado explicitamente)
`supabase db push` aplica **TODAS** as migrations pendentes. Com 0006 e 0007 ambas não-aplicadas, um
mirror cego aplicaria 0007 — **violando** a condição humana "producer_events/0007 não tocada" e o gate
de apply da Fase 6. Mecanismo escolhido, em **duas camadas**:

1. **Disciplina de landing (primária):** **só 0006** (migration + verify + rollback) **e este workflow**
   chegam a `main` pelo caminho revisado (sem push direto — global rules §7). **0007 permanece
   PARKED/uncommitted** → ausente do checkout de CI → `db push` só enxerga 0006 como pendente
   (0001–0005 já trackeadas/aplicadas).
2. **Preflight fail-closed (defesa em profundidade):** mesmo que (1) falhe, o job **prova** que o
   conjunto a aplicar é **exatamente `{20260620000006}`** e **aborta sem aplicar** caso contrário.

## 6. Preflight fail-closed (step "assert apply scope is EXACTLY {0006}")
Roda **após** `link` e **antes** do `db push` real. **Duas asserções**, ambas abortam (`exit 1`, no apply):

- **(A) Guarda de checkout (file-level):** itera `supabase/migrations/*.sql`; como os nomes são
  timestamps de 14 dígitos zero-padded, comparação lexical == numérica. **Aborta** se existir qualquer
  migration **mais nova que 0006** (pega 0007/`producer_events` vazando para `main`); **aborta** se 0006
  **não** estiver presente. Independe de versão da CLI.
- **(B) Guarda de verdade-remota (`db push --dry-run`):** enumera o que o `db push` **realmente**
  aplicaria; exige que o conjunto pendente seja **exatamente `{20260620000006}`**. Pega *baseline drift*
  (ex.: um 0005 não-aplicado que tornaria >1 migration pendente). `--dry-run` **nunca** aplica nada;
  `grep` tolerante a zero-match (`|| true` implícito via captura) ⇒ conjunto vazio também aborta.

As duas camadas são complementares: (A) pega "0007 entrou no `main`"; (B) pega "remoto não está no
baseline esperado". Qualquer divergência ⇒ **nenhum apply**.

## 7. Governança / landing em `main`
- **Caminho revisado, sem push direto** (global rules §7): `0006` (migration + verify + rollback) **+**
  `entity-db-apply.yml` chegam a `main` por PR revisado. **0007/`producer_events` NÃO entra neste commit**
  (segue parked/uncommitted — DEC-0014 §sequenciamento: 0006 aplica independente e à frente da Fase 6).
- **Herança de governança:** mirror fiel ⇒ herda a postura SEC-0014/phase5 (manual-only, Environment
  gated, SHA-pin, verify fail-closed, forward-only). **Nenhum desvio** de template foi introduzido.
- **Gatilho de Security (matrix #8):** caso uma iteração futura **desvie** do template phase5 (novas
  `permissions`/secrets/triggers, gate relaxado, `on:push`/`schedule`), **vai a Security review** antes
  de mergear. Esta autoria **não** desvia.

## 8. Arquivos alterados
- `.github/workflows/entity-db-apply.yml` — **criado**: pipeline de apply gated dedicado da DEC-0014, escopo SOMENTE 0006.

**Intocados (constraint):** `supabase/migrations/20260620000006_entity_resolution_candidates.sql`,
`supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql`,
`supabase/tests/entity_resolution_candidates_post_apply_verify.sql`,
**e `…0007_phase6_producer_events.*` (permanece PARKED — não tocado, não commitado por esta tarefa).**

## 9. Impacto no escopo
- **MVP travado?** Sim. Só pipeline de apply; nada de Fase 2-produto/marketplace; stack inalterada.
- **Non-negotiable?** Reforça: **IA nunca gera número** (0006 é fila de NOMES, zero Score — apply não introduz cálculo); **proveniência** até `raw_youtube_videos` (FK composta RESTRICT, provada no verify); **default-deny** (RLS + revoke, 2 role-paths); **secrets fora de repo/log** (URL mascarada, SEC-F19); supply chain (SHA-pin, SEC-F17). **Nenhum apply**; zero secret novo.
- **Aditivo, não destrutivo (DEC-0014 §3):** o apply de 0006 não faz ALTER de nenhuma tabela aplicada/congelada da Fase 5; reusa o enum `public.video_artist_method`.

## 10. Validação executada
- **Estrutural (grep, evidenciado):** 3 SHA-pins (idênticas a phase4/5) / 0 tag mutável / 0 valor de secret / 0 `SERVICE_ROLE_KEY`; `on:` só `workflow_dispatch` (0 `push`/`schedule`); wiring `APPLY-ENTITY-CANDIDATES`, `entity-db-apply`, `production-db`, `::add-mask::`, verify→`entity_resolution_candidates_post_apply_verify.sql`, `ON_ERROR_STOP=1` confirmados. As referências a `0007`/`producer_events` no arquivo estão **todas** no racional do cabeçalho e no **preflight de exclusão** — nenhuma em caminho de apply.
- **Apply:** **não executado** (constraint + sem capacidade no sandbox). A validação funcional (preflight + verify) roda no 1º dispatch gated, pós-landing de 0006 em `main` + Environment.

> Nota de paridade: `supabase/setup-cli` mantém `version: latest` (versão **da CLI**, não tag de action — a action está SHA-pinada), idêntico às Fases 1–5. O preflight usa `db push --dry-run` (flag estável da CLI) — se indisponível, o step **falha fechado** (nunca aplica).

## 11. Revisões necessárias
- [ ] ⏳ **Security — `audit_secrets` / desvio de template (matrix #8)** sobre este pipeline. Mirror **fiel** ⇒ revisão de **delta** mínima vs. phase5 já aprovada: parametrização (frase/concurrency/verify-target) + **o step de preflight novo** (lógica de escopo, sem secret, sem permissão nova). **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).

## 12. Quadro de gates residual do `run_migration` (entity_resolution_candidates / 0006)
| Gate | Estado |
|---|---|
| Database `design_schema` (0006 aditiva) | ✅ autorado |
| Security #3 `review_rls` (RLS/PII da fila) | ✅ baixado (SEC-0017) |
| Data/AI (integridade da fila / coerência com replay) | ✅ baixado |
| **Pipeline de apply gated dedicado (DevOps, matrix #8)** | ✅ **entregue aqui** |
| Security `audit_secrets` / desvio de template (matrix #8) | ⏳ recomendada (delta + preflight) — `next_recommendation` |
| Landing de `main`: PR revisado com **só 0006** (0007 excluído; sem push direto) | ⏳ |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (como nas Fases 1–5) |
| Apply de 0007/`producer_events` (Fase 6) | ⛔ **PARKED — fora de escopo; preflight proíbe** |
| Fase 9 — RLS Policies + VIEW pública (SEC-F03) | ⛔ **veto à parte de pé** (SEC-0001 §0) — **não tocado aqui** |

## 13. Próximos passos
1. **Security (`audit_secrets`):** revisar o pipeline (delta vs. phase5 + lógica do preflight) → baixar/condicionar.
2. **Landing em `main`** (PR revisado; nunca push direto): **só 0006** (migration + verify + rollback) + `entity-db-apply.yml`. **0007 NÃO entra** neste commit.
3. **Database (`run_migration`, gated):** dispara `entity-db-apply.yml` → digita `APPLY-ENTITY-CANDIDATES` → preflight prova escopo {0006} → required reviewers aprovam → apply atômico + verify §4/§5.
4. **`data_agent`** re-alinha `DATA-ENTITY-001` ao schema final e retoma o engine (Fase 6 `producer_events` segue na ordem do `migration-plan.md`, com apply próprio).

## 14. Open decisions / bloqueios
- **Nenhum bloqueio de DevOps.** O desbloqueio do `run_migration` (workflow gated dedicado) está entregue.
  Os gates restantes (Security do pipeline, landing de `main` só-0006, humano + reviewers) são downstream
  e **intactos**. **0007/`producer_events` permanece parked** e é **ativamente proibido** pelo preflight;
  os vetos da Fase 9 permanecem de pé e fora do escopo. **Nenhum secret/credencial novo** foi necessário —
  Environment `production-db` reusado; sem retorno ao Orchestrator.

---

### `next_recommendation` (AgentResult)
```json
{
  "status": "completed",
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Matrix #8 (Deploy/ambiente -> DevOps+Security): entity-db-apply.yml autorado como mirror FIEL e SHA-pinned de phase5-db-apply.yml, parametrizado p/ DEC-0014, reusando o Environment production-db (zero secret novo). Delta a auditar: parametrizacao (frase/concurrency/verify-target) + o step de PREFLIGHT fail-closed que garante apply = SOMENTE 20260620000006 e proibe 0007/producer_events. Apos audit + landing de SO 0006 em main (sem push direto, 0007 parked), o humano dispara o run_migration gated e os required reviewers aprovam. Apply segue barrado; Fase 9 nao destravada; 0007 nao aplicado.",
    "evidence": {
      "file": ".github/workflows/entity-db-apply.yml",
      "hygiene": "3 SHA-pins (mesmas do phase4/5); 0 tag mutavel; 0 valor de secret; 0 SERVICE_ROLE_KEY; on: workflow_dispatch only",
      "scope_control": "preflight fail-closed em 2 camadas (checkout file-guard: nenhuma migration > 0006; db push --dry-run: pendentes == {20260620000006}) + disciplina de landing (so 0006 em main; 0007 parked)",
      "env_reuse": "production-db existente; zero configure_env; zero secret/var novo",
      "untouched": ["migration_0006", "rollback_0006", "verify_0006", "migration_0007_parked"]
    }
  }
}
```
