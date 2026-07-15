# SEC-0024 — Closeout `F1'-c`/`F1'-d` · atestação out-of-band sob OD-V2 · trilha de vídeo `DATA-COLLECT-001`

- **Task:** `task_attest_f1c_f1d_out_of_band` · **Action:** `audit_secrets` (closeout dos dois bloqueios de arm) · **Agent:** `security_agent` · **Compilado por:** Product Orchestrator (parity documental)
- **Data:** 2026-07-14
- **Matriz:** `agent-review-matrix.md` **#8** (DevOps + Security — ambos encarnados por `User:AdeptLabsDev`, NOTE de `SEC-0022 §4`).
- **Gate:** fecha os itens **`F1'-c`** e **`F1'-d`** do checklist F-1' (`SEC-0023 §8`), os **únicos** bloqueios de arm pendentes desde `SG-V6 §6`.
- **Fontes vinculantes:** `DEC-0020` (OD-V2, thresholds finais) · `SEC-0023 §4/§8` (F-1') · `SG-V6-data-collect-001-pre-arm-attestation.md` (+ adendo §10) · `SEC-0022 §2` (precedente de atestação out-of-band) · `SEC-0021 §4` (residual IP-restriction aceito).
- **Mandato:** RECORDS/AUDIT-ONLY, docs-only. O agente executou **somente leitura** (repo + metadados da API do GitHub); os fatos de console GCP foram verificados e atestados **pelo Product Lead** (atos e evidências out-of-band, privados, fora do repo). **Zero valor de secret, zero UID de key, zero screenshot, nenhuma connection string.** Este doc **não cria `.armed`, não faz dispatch, não coleta, não autoriza execução**.

---

## 0. Veredito

✅ **`F1'-c` → GREEN. `F1'-d` → GREEN. Todos os bloqueios de arm do F-1' estão fechados.** Atestação do Product Lead (E5a–E5d, 2026-07-14) + audit read-only do `security_agent` convergem sem lacuna e sem conflito com OD-V2.

⛔ **Este doc NÃO arma nem autoriza run.** `.github/collection/video-collection.armed` permanece **ausente** (verificado vivo em 2026-07-14). O commit consciente do marker, o fechamento de `F1'-f` (pré-live) e o dispatch SG-V7 seguem na **fronteira humana**, cada um dependente de ordem explícita e separada.

**Calibração honesta:** o que é repo/API-verificável está marcado como tal (valores nunca expostos); os fatos de GCP são **PASS por atestação** do Product Lead, com evidência privada fora do repositório — mesmo regime de `SEC-0022 §2`.

## 1. E5a — `F1'-c` · alertas de quota nos thresholds OD-V2 → ✅ GREEN (atestado)

Atestado pelo Product Lead em **2026-07-14**, console GCP do projeto `noxund-prod`:

| Item | Estado atestado |
|---|---|
| Quota diária da YouTube Data API v3 | **10.000 unid** (default confirmado) |
| Alerta de anomalia por run | ativo — **≥ 1.500 unid** em janela **rolling 30 min**, avaliação a cada **60 s** |
| Alerta diário preventivo | ativo — **≥ 5.000 unid** |
| Alerta diário crítico | ativo — **≥ 8.000 unid** |
| Canais de notificação | **associados e verificados nas três políticas** |
| Política legada 30% (3.000 unid, era `SEC-0022`) | **permanece ativa** — intocável sem autorização separada (`DEC-0020`) |

Aproximação aceita por Security: a métrica de quota GCP não conhece "runs"; o alerta per-run é implementado por delta em janela rolling curta. Mitigantes: `concurrency` do workflow impede runs de vídeo paralelas; o canal (002) adiciona ~10 unid de ruído no máximo.

## 2. Correção de redação — o GCP FOI modificado no fechamento de E5a

`SEC-0023 §8` e `SG-V6` descreviam `F1'-c` como "alertas **re-confirmados**", implicando recalibração de políticas existentes. O fechamento real: **as três políticas foram CRIADAS em 2026-07-14** pelo Product Lead — a única política pré-existente era a legada de 30%, que permanece ativa. Portanto, durante o fechamento de E5a **o GCP foi modificado** (criação de políticas de alerting), por **ato humano de configuração do Product Lead, dentro da própria alçada** — não por agente. Formulações de "GCP intocado" em docs anteriores referem-se aos mandatos docs-only daqueles documentos e às ações de agentes, e permanecem verdadeiras nesse escopo. Requisito de `F1'-c` satisfeito em rigor **igual ou superior** ao previsto. Errata correspondente: `SG-V6 §10`.

## 3. E5b/E5c/E5d — `F1'-d` · restrição, inventário e rotação da key → ✅ GREEN (atestado)

Atestado pelo Product Lead em **2026-07-14**, console GCP (`noxund-prod`):

- **E5b — API-restriction:** a key ativa restrita **somente** à *YouTube Data API v3*. Application/IP restriction permanece **N/A** (runners GitHub sem IP de egress estático) — residual aceito de `SEC-0021 §4`, sem regressão.
- **E5c — Inventário:** inventário **ativo e excluído** verificado; existe **somente** a key `NOXUND_YOUTUBE_COLLECTION_KEY` (citada por **nome**, nunca valor/UID); **nenhuma** key adicional ou excluída identificada. Continuidade do provisionamento de `SEC-0022` corroborada do lado GitHub: secret `YOUTUBE_API_KEY` do Environment **inalterado desde 2026-07-05T01:28:39Z** (metadado de API; valor jamais lido).
- **E5d — Rotação:** criação da key confirmada em **2026-07-05T01:27:59Z** — 40 s antes do set do secret no Environment (timeline coerente com provisionamento único, sem key intermediária). Idade dentro da janela de 90 dias → **deadline de rotação ≈ 2026-10-03**, além de rotação devida **pós-run relevante**, troca de pessoal ou suspeita de leak — política reafirmada pelo Product Lead.

## 4. Audit read-only do `security_agent` (repo + API GitHub, 2026-07-14 — zero valor)

| Fato verificado | Estado | Como |
|---|---|---|
| Aritmética de quota consistente com OD-V2: cap 2.000 com projeção **antes** do gasto; retry surplus 500 **contido** no cap (não aditivo); `quotaExceeded`/`dailyLimitExceeded` terminal, nunca retentado | ✅ | código `video_collection.py` + testes §8.4/`QuotaCapAndRetryBudget` |
| Alerta ≥ 1.500 é GCP-side por design (não existe nem deve existir no código) | ✅ | comentário vinculante no próprio `video-collection.yml` |
| Secrets do Environment = exatamente `{YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}`; vars `{HOST, PORT, USER}`; sem `ACCESS_TOKEN`/service-role | ✅ | API (nomes/metadados) |
| Branch policy `main`-only; required reviewer `User:AdeptLabsDev` | ✅ | API |
| `video-collection.yml` runs = **0**; `youtube-collection.yml` runs = **0** | ✅ | API |
| `.github/collection/` em `main` contém **só** `youtube-collection.armed`; `video-collection.armed` **AUSENTE** | ✅ | API |

**Limite honesto do lado agente:** o GitHub prova que o valor do secret não muda desde 2026-07-05, mas não prova a identidade GCP da key nem o estado de restrição/alerting — exatamente o que as atestações E5a–E5d fecham.

## 5. Estado consolidado do F-1' (pós-closeout)

| # | Condição | Estado | Base |
|---|---|---|---|
| `F1'-a` | Cap por-run 2.000 fail-closed | ✅ GREEN | código (PR #38) |
| `F1'-b` | Retry ≤ 2/chamada; `quota*` terminal; surplus ≤ 500 | ✅ GREEN | código + testes §8.4 (PR #38) |
| **`F1'-c`** | Alertas OD-V2 no GCP + quota 10k + canais verificados | ✅ **GREEN — fechado aqui** | atestação E5a (`§1`) |
| **`F1'-d`** | API-restriction + inventário single-key + rotação válida | ✅ **GREEN — fechado aqui** | atestação E5b/c/d (`§3`) |
| `F1'-e` | Concurrency próprio, `cancel-in-progress: false` | ✅ GREEN | YAML (PR #40) |
| `F1'-f` | Sentry-scrub + canary §8.3 | ⏳ **pré-live** — bloqueia o **1º dispatch (SG-V7)**, não o arm | SG-V6 |
| `F1'-g` | F-2' audit_secrets do YAML | ✅ GREEN | PR #40 (+ `F2'-N1` no PR #39) |

## 6. O que permanece na fronteira humana (NÃO feito aqui, por design)

- **Arm marker `video-collection.armed`** — ausente (verificado 2026-07-14); criação é ato consciente do DevOps, **não autorizada** por este doc nem pela `DEC-0020`.
- **`F1'-f`** (Sentry-scrub desligado/redatado + canary §8.3) — devido antes do 1º run real.
- **SG-V7** — dispatch humano: `main` + `RUN-VIDEO-COLLECTION` + `I-UNDERSTAND-RAW-IS-IRREVERSIBLE` + required reviewer do Environment.
- **SG-6 (002)** — segue NO-GO até existir `run_id` de vídeo §7-passed. `youtube-collection` segue **ARMADO e OCIOSO** (0 runs), intocado.
- **Vetos de pé:** `0007`/producer_events PARKED; Fase 9/RLS VETADA; publish barrado até SG-8/P5-REPRO-01.
- **Rotação futura:** deadline ≈ **2026-10-03** (≤ 90d) e rotação pós-1º-run relevante — owner Security/DevOps, fora deste doc.

---

## 7. Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_attest_f1c_f1d_out_of_band` · **Owner:** Security (compilado pelo Product Orchestrator) · **Data:** 2026-07-14 · **Prioridade:** P1

**Objetivo:** fechar `F1'-c`/`F1'-d` — os dois únicos bloqueios de arm da trilha de vídeo — por atestação out-of-band sob OD-V2 (`DEC-0020`).

**Resultado:** ✅ **GREEN nos dois.** E5a–E5d atestados pelo Product Lead (2026-07-14, evidência privada fora do repo); audit read-only do agente sem lacunas nem conflito. Zero bloqueio de arm remanescente no F-1'; `F1'-f` segue como condição pré-live do SG-V7.

**Arquivos criados/alterados:** `docs/security/SEC-0024-sg-v6-f1c-f1d-closeout.md` (este doc) · `docs/product/decisions/DEC-0020-od-v2-quota-alert-thresholds.md` · `docs/data/SG-V6-data-collect-001-pre-arm-attestation.md` (adendo §10). **Nenhum outro arquivo tocado.**

**Intocados (constraint):** workflows, `.github/collection/*` (nenhum marker criado), código, testes, migrations (`0007` PARKED), secrets, Environment, GCP (pelos agentes). Zero merge/dispatch/coleta.

**Impacto no escopo:** MVP travado mantido. Fecha condição de segurança (matrix #8) sem tocar número, banco ou copy pública.

**Revisões:** [x] Security (este closeout) · [x] Product Lead (atestações E5a–E5d + DEC-0020) · [ ] Arm consciente do DevOps — fronteira humana, não autorizada.

**Próximos passos:** (1) decisão humana e separada do arm marker; (2) `F1'-f` antes do 1º dispatch; (3) SG-V7 humano → `run_id` §7-passed → SG-6.

**Open decisions:** nenhuma nova. Política legada 30% permanece ativa por decisão explícita (`DEC-0020`).

---

## AgentResult

```json
{
  "task_id": "task_attest_f1c_f1d_out_of_band",
  "agent": "security_agent",
  "status": "completed",
  "summary": "Closeout F1'-c/F1'-d sob OD-V2 (DEC-0020): ambos GREEN por atestacao out-of-band do Product Lead (E5a-E5d, 2026-07-14, evidencia privada fora do repo) + audit read-only do agente (repo/API GitHub, zero valor). E5a: quota diaria 10k confirmada; tres politicas CRIADAS em 2026-07-14 no noxund-prod (>=1500/run rolling 30min eval 60s; >=5000 preventivo; >=8000 critico), canais verificados; politica legada 30% permanece ativa (intocavel sem autorizacao separada). Correcao de redacao registrada: fechamento de E5a MODIFICOU o GCP (criacao de politicas, ato humano do Product Lead); 'GCP intocado' refere-se apenas a acoes de agentes. E5b: key restrita somente a YouTube Data API v3; IP-restriction N/A (residual SEC-0021 aceito). E5c: inventario ativo+excluido = somente NOXUND_YOUTUBE_COLLECTION_KEY (nome, nunca valor/UID); continuidade corroborada por secret do Environment inalterado desde 2026-07-05. E5d: key criada 2026-07-05T01:27:59Z, dentro de 90d (deadline rotacao ~2026-10-03); politica de rotacao reafirmada. Aritmetica de quota sem conflito: nominal ~1010 descritivo < 1500 alerta detectivo (GCP) < 2000 cap preventivo em codigo (surplus 500 contido) < 3000 legada < 5000 < 8000 < 10000. Zero bloqueio de arm restante; F1'-f segue pre-live (bloqueia SG-V7, nao o arm). Arm marker AUSENTE (verificado 2026-07-14); arm/dispatch/SG-6 NO-GO ate ordem explicita. Docs-only: zero secret/UID/screenshot; workflows/markers/codigo/GCP/secrets/Environment intocados pelos agentes.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0024-sg-v6-f1c-f1d-closeout.md",
      "description": "Closeout de F1'-c/F1'-d por atestacao out-of-band sob OD-V2. Registra E5a-E5d, correcao de redacao (GCP modificado no fechamento de E5a pelo Product Lead), audit read-only, estado consolidado do F-1' e fronteira humana restante."
    },
    {
      "type": "decision",
      "path": "docs/product/decisions/DEC-0020-od-v2-quota-alert-thresholds.md",
      "description": "OD-V2: thresholds finais (1500 rolling 30min/60s; 5000; 8000; quota 10k), politicas criadas 2026-07-14, politica legada 30% ativa, cap 2000/500 inalterado em codigo."
    }
  ],
  "errors": [],
  "cosign_verdict": "approve",
  "notes": [
    "Alerta per-run por delta em janela rolling e aproximacao aceita (metrica GCP nao conhece runs; concurrency impede paralelismo de video; canal = ~10 unid de ruido).",
    "Nominal+surplus max (~1510) cruza deliberadamente o alerta de 1500: exaurir o budget de retry e anomalo por definicao.",
    "Rotacao futura: deadline ~2026-10-03 (<=90d) + pos-run relevante — owner Security/DevOps."
  ],
  "next_recommendation": {
    "target_agent": "devops_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "F-1' sem bloqueios de arm (F1'-c/d GREEN, SEC-0024; thresholds DEC-0020). O proximo ato e humano e consciente: decisao separada do Product Lead/DevOps sobre o commit de .github/collection/video-collection.armed — NAO autorizada por este closeout. Depois: F1'-f (Sentry-scrub+canary) antes do 1o dispatch; SG-V7 humano multi-fator; SG-6 so com run_id de video par.7-passed. Nada roda ate cada ordem explicita."
  }
}
```
