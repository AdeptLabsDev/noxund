# Handoff — `task_phase1_devops_configure_credentialed_env` · DevOps Agent

> **⚠️ Parcialmente superado por SEC-0005 → `HANDOFF-phase1-harden-apply-pipeline.md`.**
> O audit SEC-0005 bloqueou e mandou hardening. Mudou desde este handoff:
> **`SUPABASE_SERVICE_ROLE_KEY` NÃO é mais provisionada no CI** (SEC-F19) e há um **pré-flight
> runbook** (branch rule `= main` + rotação) com evidência exigida. Para os passos de
> Environment/secrets, siga **INFRA-0001 §2.1, §5, §7** e o handoff de hardening, não o §10
> abaixo. As actions agora estão **SHA-pinadas** (SEC-F17).

## 1. Identificação
- **Tarefa:** `task_phase1_devops_configure_credentialed_env` · **Action:** `configure_env` (sensível/gated)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-21
- **Prioridade:** P1 (high)
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` · região `us-east-1`

## 2. Objetivo
Prover um **ambiente credenciado e reprodutível** para aplicar a migration da Fase 1 (e as
próximas) **via CI, não no laptop** — desbloqueando o `MISSING_CREDENTIALED_CONNECTION`
nomeado no `HANDOFF-phase1-apply.md` §2/§7, **sem** violar o non-negotiable de secrets.

## 3. Critério de aceite (do payload)
1. `config.toml` linkado a `pwbkplzyzmortwjjpcbg`, sem nenhum secret versionado.
2. Pipeline de apply executável em CI, encapsulando o runbook atômico (ON_ERROR_STOP).
3. Referências de secret documentadas (nomes), valores só no cofre/CI.
4. Job de verificação estrutural (§4) + empírica (§5) plugado pós-apply.
5. Handoff confirmando ambiente pronto; `next_recommendation` rumo ao `run_migration` em CI.

## 4. Resultado
- [x] **Critério 1** — `supabase/config.toml` com `project_id = "pwbkplzyzmortwjjpcbg"`, zero secret.
- [x] **Critério 2** — `.github/workflows/phase1-db-apply.yml`: manual-only (`workflow_dispatch` + frase `APPLY-PHASE1`), gated por Environment `production-db`, roda runbook §3 Opção A (`supabase link` + `supabase db push`), atômico (a migration é `begin/commit`; falha → job vermelho).
- [x] **Critério 3** — `docs/infra/INFRA-0001-phase1-credentialed-env.md` §2: nomes das referências de secret (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_SERVICE_ROLE_KEY`) + coordenadas não-secretas. **Zero valor no repo.**
- [x] **Critério 4** — `supabase/tests/phase1_post_apply_verify.sql` plugado ao job `verify`; asserções §4 + §5 que **falham alto** (`ON_ERROR_STOP`).
- [~] **Critério 5** — ambiente **preparado**; readiness final **depende de ação humana out-of-band** (aprovar + popular o Environment). Por isso o resultado é `needs_review`, não `completed` — não posso confirmar "credenciado pronto" sem a evidência dos secrets, que não vejo nem devo ver (onboarding §5/§8.6).

**Como verificar (após o Environment ser populado):**
`Actions → Phase 1 · DB Apply (gated) → Run workflow → confirm: APPLY-PHASE1` → aprovar revisores → ver job `apply` verde e job `verify` verde.

## 5. Arquivos alterados
- `supabase/config.toml` — **criado**: link ao project_ref, sem secret.
- `.github/workflows/phase1-db-apply.yml` — **criado**: pipeline de apply gated + verificação.
- `supabase/tests/phase1_post_apply_verify.sql` — **criado**: asserções §4 + §5.
- `docs/infra/INFRA-0001-phase1-credentialed-env.md` — **criado**: spec de referências de secret + design do ambiente + gate.
- `.env.example` — **modificado**: pointer (nomes, sem valores) para as referências de CI/operador.

## 6. Impacto no escopo
- **Mantém o MVP travado?** Sim. Nenhuma infra de Fase 2 (sem Redis/Celery/FastAPI persistente). Só CI + Supabase config — dentro do que o DevOps owns.
- **Toca non-negotiable?** Toca a fronteira de **secrets** — e a respeita: zero secret em payload/repo/log; valores só no cofre/CI, out-of-band (global rule #10 / onboarding §8.6).
- **Toca número/banco/auth/copy pública?** Prepara o ambiente para um **apply de banco** (não aplica). Aciona a revisão de ambiente (matrix #8).

## 7. Validação executada
- **Apply:** **não executado** — by design (`configure_env` só prepara; hard-constraint do payload). Nenhuma conexão credenciada foi usada deste ambiente.
- **Lint estrutural dos artefatos:** revisão manual do YAML/SQL/TOML. A validação funcional real (runbook + §4/§5) roda no **primeiro dispatch** do workflow, após o Environment ser populado.

## 8. Riscos
- **Conectividade IPv4/IPv6:** runners do GitHub são IPv4; mitigado usando o **session pooler** (host/porta como `vars.*`), evitando o host direto IPv6-only.
- **Vazamento de secret em log:** mitigado — secrets só via `secrets.*`, URL construída com `::add-mask::`; nada ecoado.
- **Pin de actions:** `@v4`/`@v1` (tags de major). Follow-up de SHA-pin registrado para a revisão de Security (INFRA-0001 §5).
- **Merge:** estes artefatos **não** podem ir por push direto na `main` (global rule #12) — devem entrar por **branch + PR** com a revisão DevOps+Security.

## 9. Revisões necessárias
- [ ] ⏳ **Security (DevOps + Security, matrix #8)** — mudança de ambiente: validar zero-leak de secret, manejo de secret no CI, least-privilege das referências, e os testes negativos do `verify`. **Acionada** via `next_recommendation = security_agent:audit_secrets`. **Não** assumida como ok.
- [x] **DevOps** — esta entrega (autor).
- [ ] **QA/DevOps** — rodar §4 + §5 e anexar a saída como apply log real (pós-apply).
- **Database + Security do SQL (matrix #3):** já satisfeito por `SEC-0004` (veto técnico baixado) + `DEC-0006` (gate humano da migration).

> **Nota de governança (por que insiro a revisão de Security antes do `run_migration`):**
> o critério #5 pede `next_recommendation = database_agent:run_migration`. Mudança de ambiente
> dispara **DevOps + Security obrigatório** (matrix #8) + minhas Required Reviews + global rule
> #11 — binding e acima de um critério que os pulasse. Então o **próximo passo imediato** é a
> revisão de Security desta mudança de ambiente; o `run_migration` em CI é o passo que segue
> **assim que** (a) o Security baixar e (b) o humano popular/aprovar o Environment. SEC-0004 §4
> já pediu essa coordenação DevOps/Security no provisionamento.

## 10. Próximos passos
1. **Product Lead (out-of-band):** aprovar `configure_env` e criar o Environment `production-db` — popular **secrets** (§2.1) + **variables** (§2.2) do INFRA-0001; configurar required reviewers = DevOps + Security.
2. **Security (`audit_secrets`):** revisar esta mudança de ambiente (zero-leak, CI secret handling, least-privilege, SHA-pin) → baixar/condicionar.
3. **Database (`run_migration`, gated):** disparar `phase1-db-apply.yml` a partir do CI → aplica a Fase 1 → `verify` roda §4/§5.
4. **QA/DevOps:** anexar a saída do `verify` como apply log real.
5. **Merge:** landar estes artefatos via **branch + PR** (não push na `main`).

## 11. Open decisions / bloqueios
- **Gate humano (sensível):** `configure_env` exige aprovação humana **e** o Product Lead fornecer os **valores** dos secrets out-of-band ao Environment. Até lá, ambiente **preparado**, não **ativo**.
- **Bloqueio nomeado removido (parcial):** os artefatos que faltavam para o `MISSING_CREDENTIALED_CONNECTION` (config + link + pipeline + referências) **existem**; resta a credencial real no cofre/CI (alçada humana, por desenho).
