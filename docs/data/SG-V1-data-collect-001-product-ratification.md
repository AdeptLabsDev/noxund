# SG-V1 — DATA-COLLECT-001 Product Ratification (Video Collection Track)

## 1. Identificação

- **Documento:** Ratificação de produto/design (SG-V1) — **não** é DEC, **não** autoriza coleta.
- **Trilha:** `DATA-COLLECT-001` — coleta de vídeo upstream (`search.list → raw_youtube_search_pages`, `videos.list → raw_youtube_videos`).
- **Gate:** SG-V1 (ratificação Product Orchestrator dos parâmetros de produto + topologia de criação de `run_id`).
- **Owner:** Product Orchestrator (co-lead de produto).
- **Data:** 2026-07-05
- **Natureza:** DESIGN-ONLY — zero código, zero workflow, zero migration, zero testes, zero verify, zero API, zero secret, zero dispatch, zero coleta.
- **Fontes vinculantes:** `docs/data/DATA-COLLECT-001-youtube-collection-spec.md` §1–§3/§7/§9; `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md` §2.1; `docs/data/HANDOFF-data-collect-001-video-track.md` (em `main`, PR #34).

## 2. Objetivo

Registrar formalmente a **ratificação de produto** do SG-V1: congelar os parâmetros de coleta, confirmar a topologia de criação de `run_id` (001 cria; 002 reutiliza) e emitir o veredito **GO** para avançar a revisão/design de SG-V2 (Security) e SG-V3 (Database) em paralelo, mantendo SG-6 (Channel Data) **NO-GO** e as decisões OD-V1/OD-V2 abertas para Security/DevOps.

## 3. Tabela SG-V1 de ratificação

| Item de produto | Valor vinculante (spec) | Âncora | Veredito |
|---|---|---|---|
| **Vertical** | `Chicago Drill` — vertical única | §1 | ✅ **RATIFICADO** |
| **Keyword / `q`** | `chicago drill type beat` — literal exato, sem trim/aspas/expansão/sinônimo/termo extra | §1 | ✅ **RATIFICADO** |
| **Janela temporal** | `window_days = 30`; `window_end` fixado 1×; `window_start = window_end − 30d`; mesmos bounds UTC em todas as páginas | §1 / §2 | ✅ **RATIFICADO** |
| **`target_video_count`** | `≈ 500` (alvo aproximado) com **teto rígido de 500** — no máx. os primeiros 500 `video_id` únicos em ordem estável | §1 / §2 | ✅ **RATIFICADO** |
| **`source_exhausted`** | < 500 **apenas** por esgotamento natural da fonte; finalizar como `source_exhausted`; volume real vai a **review Product Orchestrator + Data/AI**; **nunca** ampliar janela/query nem mascarar erro | §3.2.7 / §7 | ✅ **RATIFICADO** |
| **Fonte** | YouTube Data API v3 (`search.list` + `videos.list`); sem fonte alternativa/scraping | §1 | ✅ **RATIFICADO** |
| **Topologia de `run_id`** | 001 **gera** UUID antes da 1ª chamada → é `report_runs.id` → run_id comum de Search+Video Data. **001 CRIA a run.** | §2 | ✅ **RATIFICADO** |
| **Reutilização por 002** | Channel Data / `youtube-collection` **não cria** run_id; **reutiliza** o mesmo `report_runs.id` da run de 001, **§7-passed** | 002 §2.1 | ✅ **RATIFICADO** |
| **Recoleta** | = **novo run_id** para a run inteira; nunca recoleta isolada sobre run_id existente | §2 | ✅ **RATIFICADO** |
| **Ciclo de vida** | `created` → `collecting` (antes da 1ª API) → finalização única grava `collected_video_count` após §7; identidade de coleta imutável | §2 | ✅ **RATIFICADO** |

## 4. Parâmetros recomendados (congelados para v1)

```
vertical            = Chicago Drill              (única)
keyword / q         = "chicago drill type beat"  (literal, sem alteração)
window_days         = 30                          (window_end fixo 1×; start = end − 30d; UTC)
target_video_count  = 500                         (alvo aproximado; teto rígido de 500)
source              = YouTube Data API v3         (search.list + videos.list)
stop_reasons        = { target_reached | source_exhausted }   (erro nunca é parada válida)
run_id owner        = DATA-COLLECT-001            (cria); DATA-COLLECT-002 apenas reutiliza (§7-passed)
recoleta            = novo run_id (run inteira)
```

Recomendação: manter todos os parâmetros **exatamente como travados na spec**. Nenhuma alteração de produto é desejável ou necessária para v1 — qualquer mudança de keyword/janela/volume/vertical/fonte seria **Stop Condition** (§1).

## 5. Decisões de Product ratificadas (fecham no SG-V1)

1. **Parâmetros de coleta congelados** (vertical / keyword literal / janela 30d / ~500 com teto rígido / fonte) — sem desvio.
2. **`~500` é alvo aproximado com teto rígido de 500;** volume menor por `source_exhausted` é **resultado de produto aceitável** apenas como **esgotamento natural**, condicionado ao loop de review **Product Orchestrator + Data/AI** do volume real. Product **não** pressionará ampliar janela/query para "chegar a 500".
3. **Topologia de criação de run confirmada:** **DATA-COLLECT-001 é o único produtor de `run_id`**; **DATA-COLLECT-002 / `youtube-collection` é consumidor puro** do mesmo `run_id`, exigindo-o **§7-passed**. Governança: o dispatch de 002 só pode consumir um `run_id` de vídeo **congelado e §7-passed** produzido por 001 — nunca um UUID fabricado ou de run `failed`/`collecting`.
4. **Recoleta = novo `run_id`** para a run inteira (Search + Video Data + Channel Data); nunca recoleta isolada sobre um run_id existente.
5. **Modelo de reprodutibilidade aceito** (§9): "reprodutível" = reprocessar o **mesmo raw congelado**; `order=relevance` não promete o mesmo conjunto numa chamada futura. O valor de produto está no snapshot ancorado, não na repetibilidade da API.

## 6. Decisões ainda abertas (fora do mandato de Product — vão a Security/DevOps)

| ID | Decisão | Dono | Estado |
|---|---|---|---|
| **OD-V1** | Environment **reutilizado** (`youtube-collection`, mesma `YOUTUBE_API_KEY`/reviewers) **vs. dedicado** para o estágio de vídeo. A chave é a mesma (mesmo projeto Google); workflow/arm/reviewers podem ser separados. | Security + DevOps | ⬜ **OPEN DECISION** |
| **OD-V2** | **Quota cap por-run + retry budget + threshold do F-1'** para ~1010 unid/run (`search.list` ≈ 100 unid/página × ~10 + `videos.list` ≈ 10) + alerta de quota + API-restriction reconfirmada. | Security (F-1') + DevOps (configure_env) | ⬜ **OPEN DECISION** |

Ambas são **pré-condição de execução**, não de design: não bloqueiam SG-V2/SG-V3 (revisão/design); bloqueiam o dispatch real (SG-V7).

## 7. Riscos de produto (nível SG-V1)

| # | Risco de produto | Postura ratificada |
|---|---|---|
| **P-R1** | Amostra menor que 500 por `source_exhausted` → 1º relatório com base amostral reduzida. | Aceito com loop de review de volume; sem alargamento de params (Stop Condition). |
| **P-R2** | Representatividade — 1 keyword + 1 vertical pode não cobrir toda a cena "Chicago Drill". | Aceito para v1; multi-keyword/multi-vertical é Fase 2 (fora de escopo). |
| **P-R3** | Snapshot é time-anchored (janela relativa ao `window_end` do run). Uma run hoje ≠ uma run futura. | Timing do dispatch fica com Product no SG-V7; não altera SG-V1. |
| **P-R4** | Expectativa de reprodutibilidade mal-entendida (achar que a API re-entrega o mesmo conjunto). | Modelo §9 ratificado: repro = reprocessar o mesmo raw. |
| **P-R5** | Uso indevido do `run_id` (dispatch de 002 sobre run_id inválido). | Governança: 002 só consome run_id §7-passed de 001; fail-closed no gate §7. |

## 8. Veredito GO/NO-GO

- **SG-V1 → ✅ GO.** Ratificação de produto concluída: parâmetros congelados e confirmados, topologia de criação de run confirmada (001 cria / 002 reutiliza §7-passed), política `source_exhausted` aceita com loop de review. Nenhuma Stop Condition acionada.
- **SG-V2 (Security) + SG-V3 (Database) → ✅ GO para revisão/design em paralelo.** Ambos são revisão/design e **não** executam coleta. Encaminhar OD-V1/OD-V2 a Security/DevOps junto com a abertura do SG-V2.
- **SG-6 (Channel Data / 002) → ⛔ NO-GO (inalterado).** Bloqueado por dependência estrutural: não existe `run_id` de vídeo congelado e §7-passed. **A próxima etapa elegível é SG-V2/SG-V3, nunca SG-6.**
- **`youtube-collection` / 002 → segue ARMADO e OCIOSO** (`.armed` em `main`, `TOTAL_RUNS=0`, sem dispatch/coleta).

## 9. Próximo passo seguro

1. Encaminhar **OD-V1** e **OD-V2** a Security/DevOps (design/review-only).
2. Abrir **SG-V2** (Security `audit_secrets`) e **SG-V3** (Database: confirmação zero-ALTER + atomicidade da finalização) — em paralelo, sem tocar em API/secret/pipeline.
3. Nada de código, workflow, migration, testes, verify, dispatch, deployment ou coleta até SG-V2..SG-V6 verdes + dispatch humano (SG-V7).

## 10. Restrições honradas / Intocados

- **Docs-only.** Nenhum código, workflow, migration, teste, verify, secret, GCP, Supabase, dispatch ou deployment tocado.
- **Não é DEC** — registro de ratificação de produto (SG-V1), não decisão formal no decision log.
- **Intocados:** `.github/workflows/youtube-collection.yml`; `.github/collection/youtube-collection.armed`; `services/data-engine/*` (collector/testes); `supabase/migrations/*` (schema já vivo, zero ALTER); `supabase/tests/*` (verify); `20260620000007_phase6_producer_events.*` (**PARKED**).
- **Vetos ativos reafirmados:** SG-6 NO-GO; sem dispatch; sem deployment; sem coleta; `0007` intocado; Fase 9/RLS vetada; publish barrado até SG-8/P5-REPRO-01; secrets/GCP/Supabase intocados; zero commit/push/PR sem autorização explícita.
- **Zero valor sensível.** Cita apenas **nomes** de secrets/vars (`YOUTUBE_API_KEY`) — nenhum valor, token, URL com query string, senha ou credencial.
