# SEC-0026 — Closeout A7 · rotação staged pós-run da `YOUTUBE_API_KEY` (E7a–E7f)

- **Task:** `task_close_a7_key_rotation` · **Action:** `audit_secrets` (closeout do checkpoint A7 do runbook SG-V7) · **Executor da rotação:** **Product Lead** (console GCP + Environment — atos humanos, dentro da própria alçada) · **Corroboração e compilação:** Product Orchestrator (read-only) · **Co-sign:** Security (matrix #8)
- **Data:** 2026-07-15
- **Gate:** fecha **A7** — a obrigação de **rotação pós-primeiro-run-relevante** da key de coleta, registrada em `SEC-0024 §3` (atestação E5d: "rotação devida após o primeiro run relevante") e no ledger A1–A8 do SG-V7. O primeiro run relevante materializou-se em 2026-07-15 (run `29446423135`, `run_id f0485de6` §7-passed).
- **Fontes vinculantes:** `SEC-0024` (E5b/c/d — postura da key pré-rotação) · `SEC-0022 §2` (precedente de atestação out-of-band com evidência privada fora do repo) · `SEC-0021 §4` (residual: application restriction N/A) · `DEC-0020` (políticas de alerta) · `docs/data/SG-V7-data-collect-001-first-collection-closeout.md` (A6).
- **Mandato:** RECORDS/AUDIT-ONLY, docs-only. **Evidência privada mantida fora do repositório** (precedente SEC-0022 §2); **nenhum valor de credencial foi registrado, transmitido a agentes ou colado em qualquer canal.** Este doc não altera código/workflow/marker/GCP/secrets/Environment e **não autoriza SG-6 nem qualquer dispatch**.

---

## 0. Veredito

✅ **A7 → GREEN (atestado pelo Product Lead; corroborado read-only pelo Orchestrator; co-sign Security).** Rotação **staged, sem downtime e sem exposição de valor**: key nova criada com as mesmas restrições, key antiga mantida ativa durante a transição, secret atualizado, key nova validada por chamada header-only, key antiga excluída **somente após** a validação, inventário final = **exatamente uma key ativa**.

⛔ **Este doc NÃO autoriza SG-6.** A fronteira seguinte (handoff A8 do `run_id` congelado ao 002) permanece **NO-GO** até ordem explícita do Product Lead.

## 1. Atestações E7a–E7f (Product Lead, evidência privada fora do repo)

| Label | Etapa staged | Fato atestado | Verificação |
|---|---|---|---|
| **E7a** | Key nova criada | Key nova no projeto `noxund-prod`; **API restriction = somente YouTube Data API v3**; **application restriction = N/A** (residual documentado, `SEC-0021 §4` — runners sem IP estável) | console GCP (privada) |
| **E7b** | Transição | Inventário com **exatamente 2 keys** durante a janela: a antiga (criada 2026-07-05) **ainda ativa** + a nova; nenhuma terceira | console GCP (privada) |
| **E7c** | Secret atualizado | `YOUTUBE_API_KEY` do Environment `youtube-collection` atualizado com o valor novo | console GitHub (privada) + **corroboração API em §2** |
| **E7d** | Validação sem exposição | Key nova validada por chamada `videos.list` **via header** (`X-Goog-Api-Key`, nunca em URL), **consumo de 1 unidade**; valor jamais exposto em histórico, log ou canal | execução local do Product Lead (privada) |
| **E7e** | Exclusão da antiga | Key anterior (de 2026-07-05) **excluída somente após** a validação da nova | console GCP (privada) |
| **E7f** | Inventário final | **Exatamente 1 key ativa** em `noxund-prod` (a nova), restrições confirmadas | console GCP (privada) |

## 2. Corroboração independente do Orchestrator (read-only, sem valor)

Verificações via API do GitHub (somente **nomes e timestamps** — valores inacessíveis por construção), baseline capturada **antes** da rotação (20:15:42Z) e re-verificada após a atestação (20:23:44Z):

| Fato | Antes (baseline) | Depois | Leitura |
|---|---|---|---|
| `YOUTUBE_API_KEY` `updated_at` | `2026-07-05T01:28:39Z` | **`2026-07-15T20:19:27Z`** | secret girou **dentro da janela do A7** — corrobora E7c |
| Set de secrets do Environment | `{YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}` | **idêntico** | nada adicionado/removido |
| `SUPABASE_DB_PASSWORD` `updated_at` | `2026-07-05T01:14:45Z` | **inalterado** | rotação não tocou o secret de banco |
| `main` | `07f58b4` | **inalterado** | zero commit durante o A7 |
| Workflow runs na janela | — | **zero** | rotação não disparou nem exigiu execução |

## 3. Não-afetados (verificado)

- **Políticas de alerta DEC-0020:** são por **projeto/quota** (key-agnósticas) — a rotação **não exige nenhuma reconfiguração**; a política legada de 30% permanece ativa e intocada (`DEC-0020`).
- **Residual `SEC-0021 §4`:** application restriction segue **N/A** por decisão registrada (runners do GitHub sem IP estável) — postura **inalterada** pela rotação.
- **Ledger de quota do dia:** 1.210 unid (coleta do run #3) + **1 unid** (validação E7d) ≈ 1.211 de 10.000 — nenhum threshold aproximado.
- **Pipelines:** ambos os workflows ociosos durante toda a janela; nenhum consumidor da key além do Environment (já atualizado).

## 4. Relógio de rotação (novo)

- Key anterior: criada 2026-07-05 (deadline antigo ≈ 2026-10-03 **+ obrigação pós-run relevante** — ambos satisfeitos por esta rotação).
- **Key nova: criada 2026-07-15 → próximo deadline de rotação ≈ 2026-10-13 (≤90d).**
- Gatilhos extraordinários permanecem vinculantes: troca de pessoal, suspeita de leak, ou novo run relevante conforme política (`SEC-0023 §8`, F1'-d).

## 5. Fronteira humana restante (NÃO tocada aqui)

- **SG-6 (002):** ⛔ NO-GO — consumirá o `run_id` congelado `f0485de6-0d34-41cf-ab48-d46e483aa558` sob novo ciclo humano completo, por ordem explícita.
- **Vetos de pé:** `0007` PARKED; Fase 9/RLS vetada; publish barrado até SG-8/P5-REPRO-01.

---

## Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_close_a7_key_rotation` · **Owners:** Product Lead (executor) + Security (co-sign), compilado pelo Product Orchestrator · **Data:** 2026-07-15 · **Prioridade:** P1

**Objetivo:** fechar A7 — rotação staged pós-run da `YOUTUBE_API_KEY` — com atestação E7a–E7f e corroboração independente sem exposição de valor.

**Resultado:** ✅ **GREEN.** Rotação staged completa (criar → transicionar → atualizar secret → validar header-only 1 unid → excluir antiga → inventário = 1 key). Corroboração API: secret girado às 2026-07-15T20:19:27Z, set de secrets idêntico, DB password e `main` intocados, zero runs na janela. Novo deadline ≈ 2026-10-13.

**Arquivos criados/alterados:** `docs/security/SEC-0026-a7-key-rotation-closeout.md` (este doc). **Nenhum outro arquivo tocado por esta tarefa.**

**Intocados (constraint):** código, testes, workflows, markers, GCP além dos atos humanos do Product Lead, migrations. Zero dispatch/coleta.

**Impacto no escopo:** postura de segurança da key **renovada** após o primeiro uso real; superfície e restrições idênticas; zero impacto em número, banco ou copy.

**Próximos passos:** SG-6 por ordem explícita (A8); próxima rotação ≈ 2026-10-13.

**Open decisions:** nenhuma nova.

---

## AgentResult

```json
{
  "task_id": "task_close_a7_key_rotation",
  "agent": "security_agent",
  "status": "completed",
  "summary": "A7 GREEN — rotacao staged pos-run da YOUTUBE_API_KEY concluida sem downtime e sem exposicao de valor (labels E7a-E7f, evidencia privada fora do repo per SEC-0022 par.2). E7a key nova em noxund-prod com API restriction = YouTube Data API v3 apenas e application restriction N/A (residual SEC-0021 par.4); E7b transicao com exatamente 2 keys ativas; E7c secret YOUTUBE_API_KEY do Environment youtube-collection atualizado — corroborado via API GitHub sem valor (updated_at 2026-07-05T01:28:39Z -> 2026-07-15T20:19:27Z, set de secrets identico, SUPABASE_DB_PASSWORD intocado); E7d validacao da key nova por videos.list header-only, 1 unidade; E7e key antiga (2026-07-05) excluida somente apos validacao; E7f inventario final = exatamente 1 key ativa. Nao-afetados: politicas DEC-0020 (key-agnosticas, legada 30% intocada), residual de application restriction, pipelines ociosos (zero runs na janela), main inalterado. Novo deadline de rotacao ~2026-10-13 (90d) + gatilhos extraordinarios vigentes. NAO autoriza SG-6.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0026-a7-key-rotation-closeout.md",
      "description": "Closeout A7: atestacoes E7a-E7f da rotacao staged, corroboracao read-only via API GitHub, nao-afetados, novo relogio de rotacao."
    }
  ],
  "errors": [],
  "cosign_verdict": "approve",
  "notes": [
    "Rotacao staged eliminou a janela de downtime: a key antiga permaneceu ativa ate a validacao positiva da nova.",
    "Corroboracao independente possivel sem nenhum acesso a valor: timestamps da API do GitHub + ausencia de runs na janela."
  ],
  "next_recommendation": {
    "target_agent": "product_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "A7 fechado. Ledger A1-A8 do SG-V7 completo ate A7 (A6 = closeout operacional, A7 = esta rotacao). Fronteira seguinte = A8/SG-6: handoff do run_id congelado f0485de6-0d34-41cf-ab48-d46e483aa558 ao youtube-collection (002) — NO-GO ate ordem explicita do Product Lead."
  }
}
```
