## DEC-0020 — OD-V2: thresholds finais de quota/alerta da trilha de vídeo `DATA-COLLECT-001`

- **Data:** 2026-07-14
- **Status:** **Registrada — decisão de Product Lead.** Fixa os números finais de F-1' (escalados em `SEC-0023 §4/§8` como OD-V2) e habilita o fechamento de `F1'-c`/`F1'-d` (registrado em `SEC-0024`). **Não** altera tese, escopo travado, código, workflow, arm marker, secrets nem Environment.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Coleta gated de vídeo (`DATA-COLLECT-001`) · quota/custo YouTube Data API v3 · alerting GCP
- **Relaciona:** `SEC-0023` (F-1', floors recomendados; OD-V1/OD-V2 escaladas ao Product Lead), `SG-V6-data-collect-001-pre-arm-attestation.md` (+ adendo §10), `SEC-0024` (closeout `F1'-c`/`F1'-d`), `SEC-0022` (F-1 do canal, perfil ~10 unid), PR #38 (cap/retry em código)

### Contexto

`SEC-0023 §4` re-escopou a quota da trilha de vídeo (perfil nominal **~1.010 unid/run** — `search.list` ~10 páginas × 100 unid + `videos.list` ~10 chamadas × 1 unid — ~100× o perfil de ~10 unid do canal) e recomendou floors de postura, deixando explícito que **os números finais eram decisão do Product Lead (OD-V2)**. O cap por-run e o budget de retry já estavam ratificados e vivos em código desde o PR #38. Restava fixar os thresholds de **alerting** e re-calibrar o lado GCP — condição `F1'-c` — e re-confirmar a restrição/rotação da key — condição `F1'-d` —, os dois únicos bloqueios de arm remanescentes (`SG-V6 §6`).

### Decisão (thresholds finais — OD-V2)

| Camada | Valor | Natureza | Onde vive |
|---|---|---|---|
| Perfil nominal por run | ~1.010 unid | descritivo (baseline de calibração; não é limite) | spec §2.5 |
| **Alerta de anomalia por run** | **≥ 1.500 unid** em janela **rolling de 30 min**, avaliação a cada **60 s** | detectivo | GCP Monitoring |
| Hard cap por run | 2.000 unid (retry surplus ≤ 500 **contido** no cap, não aditivo) | preventivo, fail-closed — **inalterado** | código (`video_collection.py`, PR #38) |
| **Alerta diário preventivo** | **≥ 5.000 unid** (50% de 10k) | detectivo | GCP Monitoring |
| **Alerta diário crítico** | **≥ 8.000 unid** (80% de 10k) | detectivo | GCP Monitoring |
| Quota diária do projeto | 10.000 unid (default, **confirmada** em 2026-07-14) | teto Google, fail-closed | GCP |

Ordenação de defesa em profundidade, coerente e sem conflito com o código:

```
1.010 nominal < 1.500 alerta/run < 2.000 cap < 3.000 legada (30%) < 5.000 preventivo < 8.000 crítico < 10.000 quota
```

Detalhe deliberado: nominal + retry surplus máximo (~1.510) **cruza** o threshold de 1.500 — uma run que exaure o budget de retry é anômala por definição e merece revisão humana, ainda que complete. **Zero mudança de código decorre desta DEC** (o cap 2.000/500 permanece como ratificado em 2026-07-06).

### Atos de configuração decorrentes (executados pelo Product Lead, 2026-07-14)

As **três políticas de alerta foram criadas no console GCP do projeto `noxund-prod` em 2026-07-14**, pelo próprio Product Lead, com canais de notificação **associados e verificados nas três**. Evidência privada mantida fora do repositório (precedente `SEC-0022 §2`).

**Correção de redação (vinculante):** formulações anteriores de "GCP intocado" referem-se **exclusivamente aos agentes** e aos mandatos docs-only dos respectivos documentos. O fechamento de `F1'-c` (E5a) **envolveu, por definição, modificação do GCP** — a criação das três políticas — como ato humano de configuração do Product Lead, dentro da sua própria alçada. Da mesma forma, onde `SEC-0023 §8`/`SG-V6` previam "re-confirmação" de alertas existentes, o fechamento real deu-se por **criação de políticas novas** nos thresholds desta DEC — requisito satisfeito em rigor igual ou superior ao previsto. Detalhe em `SEC-0024 §2` e `SG-V6 §10` (adendo).

### Política legada de 30% (3.000 unid)

A política de alerta legada da era do canal (`SEC-0022`), em 30% da quota diária, **permanece ativa** e **não deve ser alterada sem autorização separada do Product Lead**. Sem conflito: encaixa-se na ordenação como camada detectiva extra entre o cap (2.000) e o preventivo (5.000) e não dispara em runs nominais nem numa run isolada no cap.

### O que esta DEC NÃO autoriza

Arm marker (`video-collection.armed`), `F1'-f` (Sentry-scrub/canary), dispatch SG-V7, SG-6, merge de qualquer PR — todos permanecem **NO-GO**, cada um dependente de ordem explícita e separada do Product Lead.

### Reversibilidade

Alta. Thresholds de alerting são configuração detectiva — ajustáveis por nova decisão sem tocar código, schema ou dados. O cap preventivo em código só muda por novo PR revisado (Data/AI + DevOps + Security). Nenhuma coleta ocorreu; nenhum dado criado.
