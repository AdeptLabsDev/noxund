# Handoff — `task_devops_configure_env_youtube_collection` · DevOps/Infra Agent

## 1. Identificação
- **Tarefa:** `task_devops_configure_env_youtube_collection` · **Action:** `configure_env` (SENSÍVEL/humano-gated)
- **Owner agent:** DevOps/Infra (`devops_agent`) · **Co-assina:** Security (matrix #8)
- **Data:** 2026-07-02 · **Prioridade:** P1 (high)
- **Gate:** **SG-4** de DEC-0018 / SEC-0020 (`next_recommendation` da auditoria SEC-0020 apontava para esta task).
- **Estado:** **PREPARAÇÃO DE SG-4 CONCLUÍDA — DESARMADO.** Este handoff é o **registro companion de SG-4 (#27, docs-only)**: plano de provisionamento + F-1 + OQ-2 + checklist de pré-arm. O **hardening F-3 do YAML já landou via #21** (commit `3ef6ff8`); este registro apenas o **referencia**, não edita o workflow. **Zero secret provisionado, zero valor de secret, `.armed` NÃO committado, zero dispatch, zero coleta.** A execução sensível (injeção da key, arm, dispatch) é a **fronteira humana** (SG-6) e **não** foi cruzada.

## 2. Objetivo
Preparar SG-4 (`configure_env`) do gated `youtube-collection.yml`: **design + plano de provisionamento** e o **registro companion** de SG-4, sem provisionar a key real, sem armar, sem dispatch. O **hardening F-3** do YAML landou via **#21** (commit `3ef6ff8`), fora deste registro. Co-assinatura de Security.

## 3. Critério de aceite (do payload) → resultado

| Critério | Estado | Evidência |
|---|---|---|
| **F-3** — mover `${{ inputs.confirm/acknowledge_irreversible/run_id }}` + `${{ github.ref }}` do guard para `env:` e referenciar como `"$VAR"` (padrão `collect`/`verify`), **antes de qualquer arm** | ✅ (landou via **#21**) | `youtube-collection.yml` L101–153: 3 steps do guard com bloco `env:`; grep confirma **zero `${{ }}` em `run:` do guard**. Casa a mitigação exigida em SEC-0020 §4. Commit `3ef6ff8` (PR **#21**); **não editado por #27**. |
| **F-1** — key restrita à YouTube Data API v3 + alerta de quota + rotação (plano; valor real é ato humano SG-6) | ✅ (plano) | `INFRA-0002 §4` — restrição de API, alerta de quota (contexto de custo ≤~10 un/run), gatilhos de rotação. Valor **não** injetado. |
| **OQ-2** — confirmar ausência de `FORCE RLS` + postura `postgres`/DB-password (least-privilege, sem `SUPABASE_ACCESS_TOKEN`) com Database + Security | ✅ | `INFRA-0002 §5` — verificado em repo (migration L177–186; zero `FORCE RLS`); Database (`HANDOFF-channel-data-collection-review §2.5`) + Security (SEC-0019/SEC-0020 §7) ratificaram. |
| **security_review** — Security co-assina SG-4 (herda SEC-0020; audita protection rules/secret handling do Environment) | ⏳ | **Acionado** via `next_recommendation`. Item 6 do checklist de pré-arm. |
| **gated_pipeline** — Environment dedicado `youtube-collection`: required reviewers (DevOps+Security), branch rule `main`-only **antes** dos secrets, deployment protection | ✅ (plano) | `INFRA-0002 §2–§3` — nomes de secret/var, ordem de setup SEC-F18 (branch rule `main` **1º** → reviewers → secrets). |
| **human_gate** — aprovação humana explícita é pré-condição de QUALQUER coleta real (SG-6 dispatch) | ✅ | `INFRA-0002 §3/§6/§7` — duas camadas humanas; arm marker committado só após checklist verde; dispatch é ato humano separado. |

## 4. Arquivos alterados

**Editado por #27 (este registro):** nenhum arquivo de código — **#27 é docs-only** (o registro companion de SG-4).

**F-3 do YAML — landou via #21 (fora de #27), listado aqui só para proveniência:**
- `.github/workflows/youtube-collection.yml` — **F-3** (commit `3ef6ff8`, PR **#21**): os 3 steps do `guard` passam `inputs.confirm`, `inputs.acknowledge_irreversible`, `inputs.run_id` e `github.ref` por `env:` e referenciam como `"$VAR"`. Guard permanece **desarmado**; nenhuma outra mudança de comportamento. **Não tocado por #27.**

**Criado por #27:**
- `docs/infra/INFRA-0002-youtube-collection-env.md` — contrato de `configure_env`/arm: artefatos versionados, referências de secret/var (nomes), ordem de setup (SEC-F18), plano F-1, confirmação OQ-2, **checklist de pré-arm** (§6).
- `docs/infra/HANDOFF-configure-env-youtube-collection.md` — este handoff.

**Intocado (constraint):** nenhum secret/Environment provisionado; `.github/collection/youtube-collection.armed` **NÃO** criado; `services/data-engine/*` inalterado (collector é SG-5); `supabase/migrations/*` (zero ALTER); `0007`/producer_events (**PARKED**); Fase 9/RLS (**VETADA**).

## 5. Revisões necessárias
- [x] **DevOps** — este registro #27 (plano de provisionamento + companion SG-4, docs-only, desarmado). O **F-3** foi revisado e mergeado no seu próprio PR (**#21**).
- [ ] ⏳ **Security co-assina SG-4 (BLOQUEANTE do arm).** Auditar: protection rules do Environment `youtube-collection` (branch rule `main`-only **antes** dos secrets, required reviewers DevOps+Security), secret handling (`YOUTUBE_API_KEY` + `SUPABASE_DB_PASSWORD` only; sem `ACCESS_TOKEN`/service-role), F-1 (restrição/quota/rotação), OQ-2 (sem `FORCE RLS`). Herda SEC-0020 para o YAML. **Acionada** via `next_recommendation`.

## 6. Próximos passos (gate residual — nada roda até verde + dispatch humano)
1. **Security co-sign de SG-4** (protection rules + secret handling do Environment).
2. **Humano/Product Lead (out-of-band):** provisionar Environment na ordem SEC-F18 (§3), injetar valores de secret, aplicar F-1 no console GCP (§4) — evidência exigida.
3. **Data/AI (SG-5):** collector `channel_collection.py` + testes §8.1–§8.6 + `channel_data_post_collection_verify.sql`.
4. **DevOps:** com o **checklist de pré-arm (§6 do INFRA-0002) todo verde**, committar `.github/collection/youtube-collection.armed` (ato consciente).
5. **Humano (SG-6):** dispatch de `main` + frase + acknowledge + required reviewers aprovam.
6. **Gate §7 pós-run (SG-7)** → **P5-REPRO-01 (SG-8)** antes do 1º publish.

## 7. AgentResult

> Envelope canônico de `result-schema.ts` (7 campos: `task_id`, `agent`, `status`, `summary`, `artifacts`, `errors`, `next_recommendation`). `configure_env` é ação **SENSÍVEL** + `requires_human_approval: true` → o runtime **não auto-executa**; o status contratual é `needs_review` (a execução real de provisionamento/arm/dispatch é a fronteira humana). O handler de `configure_env` no runtime é um `planningHandler` (foundation executor): produz plano/handoff, **nunca provisiona secret** — exatamente o escopo desta entrega.

> **Erratum de proveniência (registrado em #27):** o envelope abaixo foi emitido durante a preparação de SG-4 e descreve o **F-3** como "APLICADO ... ao `youtube-collection.yml`" e lista esse arquivo como artefato. Na landing real, o **hardening F-3 landou via #21** (commit `3ef6ff8`, branch `sec/collection-guard-f3-hardening`); **#27 é o registro companion de SG-4 (docs-only)** e **não edita** o workflow. O artefato `youtube-collection.yml` no envelope reflete a mudança de **#21**, não uma edição de #27. Envelope mantido **verbatim** como registrado.

```json
{
  "task_id": "task_devops_configure_env_youtube_collection",
  "agent": "devops_agent",
  "status": "needs_review",
  "summary": "Esta tarefa exige aprovação humana antes da execução (configure_env é ação SENSÍVEL + requires_human_approval). PREPARAÇÃO de SG-4 CONCLUÍDA e DESARMADA (foundation executor: plano/handoff, zero provisionamento). F-3 APLICADO ao youtube-collection.yml: os 3 steps do guard passam inputs.confirm/acknowledge_irreversible/run_id e github.ref por env: e referenciam como \"$VAR\" (mesmo padrão de collect/verify); grep confirma ZERO ${{ }} em run: do guard — casa a mitigação exigida em SEC-0020 §4; guard permanece desarmado. Entregue INFRA-0002 (contrato de configure_env/arm): secret/var por NOME (YOUTUBE_API_KEY + SUPABASE_DB_PASSWORD only; SEM SUPABASE_ACCESS_TOKEN -> incapaz de db push; SEM service-role, SEC-F19), ordem de setup SEC-F18 (branch rule main 1o -> required reviewers DevOps+Security -> então secrets), plano F-1 (restrição YouTube Data API v3 + alerta de quota + rotação pós-run/pessoal/<=90d/leak), confirmação OQ-2 (verificado em repo: migration L177-186, ZERO FORCE RLS; Database e Security ratificaram caminho postgres/DB-password) e CHECKLIST DE PRE-ARM. NÃO provisionei secret real, NÃO injetei valor, NÃO criei .github/collection/youtube-collection.armed, NÃO dispatch, NÃO coleta, NÃO publish. Injeção da key + arm + dispatch = fronteira humana (SG-6); Security ainda deve co-assinar SG-4. Fase 9 VETADA; 0007 PARKED; publish barrado até P5-REPRO-01.",
  "artifacts": [
    {
      "type": "config",
      "path": ".github/workflows/youtube-collection.yml",
      "description": "F-3 hardening: env:-indireção nos 3 steps do guard (inputs.confirm/acknowledge_irreversible/run_id + github.ref via env, usados como \"$VAR\"). Guard desarmado; nenhuma outra mudança de comportamento."
    },
    {
      "type": "runbook",
      "path": "docs/infra/INFRA-0002-youtube-collection-env.md",
      "description": "Contrato de configure_env/arm do Environment youtube-collection: artefatos versionados, secret/var por nome, ordem SEC-F18, plano F-1, confirmação OQ-2, checklist de pré-arm. Plano, não execução."
    },
    {
      "type": "handoff",
      "path": "docs/infra/HANDOFF-configure-env-youtube-collection.md",
      "description": "Este handoff — critério de aceite -> resultado, arquivos, revisões, próximos passos, este AgentResult."
    }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "SG-4 preparado por DevOps (F-3 aplicado no YAML desarmado; INFRA-0002 com plano de Environment + F-1 + OQ-2 confirmado + checklist de pré-arm). Próximo gate = Security CO-ASSINAR SG-4: auditar as protection rules do Environment youtube-collection (branch rule main-only ANTES dos secrets; required reviewers DevOps+Security) e o secret handling (YOUTUBE_API_KEY + SUPABASE_DB_PASSWORD only; sem ACCESS_TOKEN/service-role; F-1 restrição/quota/rotação). Herda SEC-0020 para o YAML. Em paralelo, SG-5 (Data/AI: collector + testes §8 + verify SQL) é pré-condição do arm — o preflight do guard checa a existência dos 4 arquivos. Só com o checklist de pré-arm (INFRA-0002 §6) TODO verde o DevOps commita o arm marker; a injeção dos valores de secret + F-1 no console GCP + o dispatch permanecem a fronteira humana (SG-6, requires_human_approval). Nada roda até lá. Fase 9 VETADA; 0007 PARKED; publish barrado até P5-REPRO-01."
  }
}
```
