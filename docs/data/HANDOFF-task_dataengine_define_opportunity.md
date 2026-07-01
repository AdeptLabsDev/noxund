# Handoff — task_define_opportunity · Opportunity Agent (ranking · HOT · Competition · Example)

## 1. Identificação

- **Tarefa:** `task_define_opportunity` (delegada via `delegate_task: define_opportunity`, prioridade high)
- **Owner agent:** Data/AI Pipeline (`data_agent`)
- **Ação:** `define_opportunity` *(ver OPEN-DATA-OPP-08 — nome ainda **não** consta na allow-list publicada do `data_agent`; o trabalho de especificar/planejar determinístico é permitido — onboarding §4)*
- **Data:** 2026-06-30
- **Prioridade:** P0 / high
- **Resultado do agente:** `completed` (DESIGN-only) — com OPEN QUESTIONS registradas para antes de qualquer compute-live
- **Decisão de origem:** DEC-0013 (pipeline-first); cadeia DATA-COLLECT-001/002 → DATA-ENTITY-001 → DATA-CHANNEL-001 → DATA-SCORING-001 → **DATA-OPP-001** (nó terminal do pipeline determinístico)

## 2. Objetivo

Formalizar, sem executar, a metodologia **determinística, auditável e reproduzível** do Agente 6 (Opportunity): transformar `final_score`/`raw_score` + os 4 componentes de `artist_metrics` (de `DATA-SCORING-001`) e a contagem de canais distintos (de `DATA-CHANNEL-001`) nas **linhas do relatório** — **ranking**, **HOT** (`>90`), **Score exibido** (`>83`), **Competition Low/Medium/High**, **Example** (top-3 velocity → mais recente → maior views) com `selection_reason_json` — materializadas em `reports` + `report_items` (snapshot congelado no publish). Nenhum dado real, número, secret, migration, código ou IA faz parte desta ação.

## 3. Critério de aceite (do backlog)

`docs/product/mvp-backlog.md` — `[DATA] Opportunity Agent (ranking + HOT + Competition + Example)`:
> **Objetivo:** montar as linhas do relatório.
> **Descrição:** ranking; HOT se >90; Score exibido se >83; Competition por thresholds; Example por regra determinística (top-3 velocity → mais recente → maior views); grava `selection_reason_json`.
> **Critério de aceite:** linhas com prova determinística; Example idêntico em reprocesso.
> **Risco:** Example "no olho".

## 4. Resultado

- [x] Critério de aceite atendido **no nível de design** (o compute-live depende de OPEN-DATA-OPP-01/06 + herdadas OPEN-DATA-CHANNEL-01 / OPEN-DATA-SCORING-01/02).
- [x] Demonstrável (como verificar): ler `docs/data/DATA-OPP-001-opportunity-spec.md` §§5–9; confrontar o shape com `reports`/`report_items` aplicados (migration Fase 5, L331–414), o validador `report_item_reason_complete` (L164–188), o enum `competition_level` (L89–91) e o freeze de snapshot (L430–513). Nenhum comando/coleta/migration/cálculo foi executado.

| Critério | Veredito |
|---|---|
| **ranking** | ✅ ordem total determinística `final_score DESC → raw_score DESC → artist_id ASC` (chave de negócio + desempate de precisão + desempate estável por chave natural) — §5. A chave de negócio é ratificável (OPEN-DATA-OPP-03); os desempates garantem ordem total. |
| **HOT se >90** | ✅ `final_score > 90` estrito (inviolável); conjunto HOT = top-2 por Score (cap-de-2 determinístico) — §6. Caso **>2** pinado; caso **<2** é conflito PRD §4.4 ↔ §5.2 → OPEN-DATA-OPP-02. |
| **Score exibido se >83** | ✅ `score_display = 'X/100'` só se `final_score > 83`; senão `NULL` (linha permanece, colunas restantes visíveis); `score_value` interno sempre gravado — §7. |
| **Competition por thresholds** | ✅ bucketing `Low ≤5 / Medium 6–15 / High >15` sobre `channel_diversity_count` + override por crescimento 7d `>50%`; mapeia ao enum vivo `competition_level` — §8. Constantes = OPEN-DATA-OPP-01; semântica do gatilho 7d = OPEN-DATA-OPP-04. |
| **Example determinístico** | ✅ `ValidVideos → vel(v) por-vídeo (consumida, não recomputada) → top-3 por vel → mais recente → maior views → min video_id` — §9. "Example no olho" eliminado por construção. |
| **grava `selection_reason_json`** | ✅ contrato `{candidates(≥1), top3(≥1), tiebreak, selected_example.video_id}` satisfaz o validador F5-05A **por construção**; chaves aditivas (`versions`, `competition`) aceitas — §9.2. |
| **Example idêntico em reprocesso** | ✅ função pura (sem rede/LLM/relógio; tempo = `window_end`), ordenação por chave natural estável até `video_id` → byte-idêntico → P5-REPRO-01 — §12. |
| **linhas com prova determinística** | ✅ cada célula (ranking/HOT/Score/Competition/Example/versões) mapeada a coluna/JSON do shape aplicado, rastreável até `raw_youtube_videos` — §12. |

Não é honesto marcar tudo pronto para compute-live: as **constantes de Competition** (rótulo público), a **regra de composição do relatório** e a **conciliação "2 HOT"** dependem de decisão humana (§11), e a coleta/Score real são herdados de OPEN-DATA-CHANNEL-01 / OPEN-DATA-SCORING-01/02. O **design** está completo.

## 5. Arquivos alterados

- `docs/data/DATA-OPP-001-opportunity-spec.md` — **criado**: spec de design do Opportunity Agent (ranking determinístico, regra HOT + cap-de-2, gate de exibição `>83`, bucketing de Competition + gatilho 7d, algoritmo do Example + contrato `selection_reason_json`, formatação, versionamento `opportunity-rules-2026_06_v1`, reprodutibilidade/auditoria por célula, OPEN QUESTIONS, escopo negativo).
- `docs/data/HANDOFF-task_dataengine_define_opportunity.md` — **criado**: este handoff de governança.

Nenhum arquivo de schema, migration, serviço, workflow ou configuração foi alterado. Nenhuma migration foi aplicada; nenhuma conexão de banco foi aberta; nenhum número foi computado; nenhuma IA foi invocada.

## 6. Impacto no escopo

- **Mantém o MVP travado?** Sim. Ranking/HOT/Competition/Example permanecem **CODE determinístico**; IA continua exclusiva do Entity Resolution. Consome Score/Competition upstream **sem redefinir**. Keyword/janela/volume/pesos intactos.
- **Toca algum non-negotiable?** Apenas para **preservá-los**: zero número/rótulo por IA, raw imutável, computed reconstruível, snapshot congelado no publish (F5-01), versões congeladas na evidência, default-deny (`report_items` sem policy até Fase 9), `0007` parked, Fase 9 vetada. Todos mantidos como gates.
- **Toca número/banco/auth/copy pública?** **Não computa número**, não muda schema/auth/copy. Define a **metodologia** que produz **rótulos e ordem públicos** (HOT, Competition, ranking, Score exibido) e o **contrato de escrita** sobre `reports`/`report_items` já aplicados → por isso aciona **Data/AI + Product Lead** (rótulos governam superfície pública). Nenhuma alteração de keyword/janela/volume/fonte/pesos.

## 7. Validação executada

- Conferência com `03_Data_AI_Agents_Methodology.md` §1 (IA nunca produz/julga/exibe número — nem rótulo/ordem), §8 (HOT>90; Score exibido>83; Competition Low/Med/High; Example top-3 velocity→mais recente→maior views — refletidos verbatim), §9 (estrutura da linha: title/tag/score/signals/velocity/competition/example_url/example_video_id/report_id/run_id/rubric_version — mapeada às colunas), §10 (auditoria por célula de Competition e Example — mapeada), §11–12 (raw/computed + reprodutibilidade) — todos preservados.
- Conferência com `01_MVP_Scope_PRD.md` §4.4 (10 artistas, 2 HOT), §5.1 (title "<Artista> Type Beat"), §5.2 (HOT>90), §5.3 (Score X/100 só >83), §5.5 (Velocity mediana, formatação), §5.6 (Competition thresholds), §5.7 (Example determinístico) — refletidos; conflito §4.4 ("exatamente 2") ↔ §5.2 (">90") isolado em OPEN-DATA-OPP-02.
- Conferência com o shape **aplicado** de `reports` (L331–353) e `report_items` (L367–414): colunas `rank/tag/score_display/score_value/signals/velocity_display/competition_level/competition_channel_count/example_video_id/example_url/selection_reason_json`; enum `competition_level ∈ {Low,Medium,High}`; enum `report_status` (draft→published→archived); FKs compostas (item↔report, item↔metric, example↔raw); `unique (report_id, rank)`/`(report_id, artist_id)`; CHECK `report_item_reason_complete` — usados **sem propor ALTER**. Confirmado: **DDL é storage-only, zero CHECK de faixa/threshold de número/rótulo**.
- Conferência com o validador `report_item_reason_complete` (L164–188): exige `candidates`(≥1), `top3`(≥1), `tiebreak`, `selected_example.video_id` não-vazio — o contrato §9.2 satisfaz **por construção** (artista pontuado ⇒ `videos.accepted ≥ 1` ⇒ `candidates ≥ 1`); chaves aditivas aceitas.
- Conferência com o freeze de snapshot (L430–513): o Opportunity escreve em `draft` (working set); o publish (`draft→published`, admin) congela — spec respeita a fronteira (materializa, não publica).
- Conferência com `DATA-SCORING-001` §8 (fronteira Scoring↔Opportunity: HOT/exibição/ranking/Competition-label/Example são **OUT** do Scoring, **IN** aqui) — assumida verbatim; §5.3/§5.6 (velocity por-vídeo e contagem de canais **consumidas**, não recomputadas).
- Conferência com `DATA-CHANNEL-001` §6 (contagem de canais distintos = Competition; `ValidVideos` como conjunto-candidato do Example) — consumida sem reabrir.
- Conferência com `scope-guardrails` (Data/AI Review para regra de Competition/Velocity/Example; escalar conflito de `/context` ao Product Lead) e `data-ai-pipeline-agent.md` (não-negociável de número/rótulo por IA; allow-list — OPEN-DATA-OPP-08).

Não foram executados: cálculo sobre dados reais, coleta, queries de banco, migration, testes de engine ou P5-REPRO-01 — esta ação produz somente o contrato de design.

## 8. Riscos

- **"Example no olho" (eliminado):** algoritmo determinístico com desempate estável até `video_id` (§9) + `selection_reason_json` como prova + FK `example_video_id → raw` → Example reconstruível e byte-idêntico. Coberto por P5-REPRO-01.
- **Constantes de Competition não ratificadas (alto):** os limiares `5/15/50%` e a semântica do gatilho 7d governam um **rótulo público**; congelar errado distorce a leitura de saturação. Mitigação: OPEN-DATA-OPP-01/04 (sign-off Product Lead + Data/AI) antes de `opportunity-rules-2026_06_v1` definitivo e de compute-live.
- **Conflito "2 HOT" (médio, escalado):** PRD §4.4 (exatamente 2) vs `>90` (§5.2) quando `<2` cruzam 90 — não se pode fabricar HOT ≤ 90. Mitigação: OPEN-DATA-OPP-02 (Product Lead); caso `>2` já pinado (cap-de-2).
- **Gap de auditoria/versão do shape aplicado (médio):** sem coluna para `recent_7d`/`prior_7d` (Competition 7d) nem para `opportunity_version`/`opportunity_hash`. Mitigação: chaves **aditivas** em `selection_reason_json` (aceitas por F5-05A), **sem** ALTER — OPEN-DATA-OPP-04/05; coluna dedicada = migration aditiva gated futura.
- **Composição do relatório (médio):** run com `<10` pontuáveis ou todos `≤83` não satisfaz "10 artistas / 2 HOT / coluna Score" (PRD §4.4). Mitigação: OPEN-DATA-OPP-06 (curadoria vs relaxar) — Product Lead.
- **Não-determinismo (mitigado):** função pura, tempo = `window_end`, `numeric` exato, ordem total por chave natural → byte-idêntico; coberto por P5-REPRO-01 (bloqueante antes do 1º publish).
- **Compute-live herdado (alto, herdado):** sem `raw_youtube_channels`/Score real (OPEN-DATA-CHANNEL-01, OPEN-DATA-SCORING-01/02) não há `artist_metrics` live → Opportunity não roda live. **Não bloqueia o design** (DEC-0013) — OPEN-DATA-OPP-07.

## 9. Revisões necessárias

- [x] **Data/AI Review** — metodologia determinística, versionamento (`opportunity-rules-2026_06_v1`) e fronteira consumo/produção definidos pelo owner; nenhum número/rótulo gerado por IA.
- [ ] **Product Orchestrator + Product Lead** — ratificar OPEN-DATA-OPP-01 (constantes de Competition), decidir OPEN-DATA-OPP-02 (conflito "2 HOT" quando `<2` cruzam 90 — conflito de `/context`), confirmar OPEN-DATA-OPP-03 (chave de ranking) e OPEN-DATA-OPP-06 (composição do relatório). Governam superfície pública.
- [ ] **Database/Data Integrity** — confirmar que **nenhum** delta de schema é necessário para `opportunity-rules-2026_06_v1` (shape aplicado já suporta via chaves aditivas em `selection_reason_json`); avaliar OPEN-DATA-OPP-04/05 (coluna dedicada de evidência 7d / versão do Opportunity = migration aditiva gated futura, nunca aqui).
- [ ] **QA / P5-REPRO-01** — após implementação: duas montagens do mesmo `run_id` + mesmas versões, `rank`/`tag`/`score_display`/`competition_level`/`example_video_id`/`selection_reason_json` byte-idênticos, zero não-determinismo. Bloqueante antes do 1º publish.
- [ ] **Security** — sem impacto direto; `score_value`/`selection_reason_json` permanecem internos (SEC-F03), exposição pública só por VIEW na Fase 9 (fora deste escopo); `report_items` segue default-deny (RLS-on + revoke).

> **Nota de governança (espelha `entity-db-apply`):** o **compute-live e o publish** ligados a este nó exigem **ratificação humana das constantes de Competition + conciliação da regra "2 HOT" + Data/AI + Product Lead**, e dependem da coleta de canal e do Score real (OPEN-DATA-CHANNEL-01 / OPEN-DATA-SCORING-01/02). **Este estágio de design NÃO os exige e NÃO os faz** — `reports`/`report_items` já estão aplicados (Fase 5) e nenhuma migration nova é proposta. Silêncio de revisor não equivale a aprovação.

## 10. Próximos passos

1. Product Orchestrator/Product Lead revisar/aceitar este handoff e decidir as OPEN QUESTIONS §13 (especialmente constantes de Competition, conflito "2 HOT" e composição do relatório).
2. Com o pipeline determinístico agora **especificado ponta a ponta** (Collect → Entity → Channel → Scoring → **Opportunity**), implementar o **data-engine determinístico** em `services/data-engine`: `opportunity-rules-2026_06_v1` (ranking, HOT+cap, gate `>83`, Competition bucketing + gatilho 7d, Example + `selection_reason_json`), com fixtures e comparação byte-a-byte, computando `opportunity_hash` em código.
3. Coordenar com Database a persistência da versão/evidência do Opportunity (chaves aditivas em `selection_reason_json` — sem ALTER; coluna dedicada só se e quando Database decidir migration aditiva gated).
4. Quando OPEN-DATA-CHANNEL-01 (coleta de canal) e OPEN-DATA-SCORING-01/02 (constantes/curvas) avançarem: ligar Channel Filter → Scoring → Opportunity → **P5-REPRO-01** (bloqueante antes do 1º publish) → publish (admin) do 1º relatório.

## 11. Open decisions / bloqueios

- **OPEN-DATA-OPP-01** *(bloqueante p/ compute-live)*: constantes de Competition `{ LOW_CHANNEL_MAX, HIGH_CHANNEL_MAX, GROWTH_HIGH_PCT, GROWTH_WINDOW_DAYS, PRIOR_ZERO_RULE }` — governam rótulo público → Product Lead + Data/AI.
- **OPEN-DATA-OPP-02** *(conflito de `/context`)*: "exatamente 2 HOT" (PRD §4.4) vs "`>90`" (§5.2) quando `<2` cruzam 90 — escalar ao Product Lead; recomendação "no máximo 2" (nunca fabricar HOT ≤ 90); caso `>2` já pinado (cap-de-2).
- **OPEN-DATA-OPP-03**: chave de ranking do relatório (proposta `final_score → raw_score → artist_id`) — Product Lead confirma a chave de negócio; desempates garantem ordem total.
- **OPEN-DATA-OPP-04**: gatilho de crescimento de Competition (div-por-zero `prior_7d=0`; escopo do override; sem coluna dedicada de evidência 7d) — Data/AI + Product Lead + Database; recomendação de chaves aditivas.
- **OPEN-DATA-OPP-05**: persistência da versão do Opportunity (`opportunity_version`/`opportunity_hash`) sem coluna dedicada — recomendação `selection_reason_json.versions`; Database + Data/AI.
- **OPEN-DATA-OPP-06**: composição do relatório (N=10 com `<10` pontuáveis; mapeamento dos 2 relatórios fixos para run(s); apresentação com todos `≤83`) — Product Lead.
- **OPEN-DATA-OPP-07** *(herdado)*: compute-live depende de OPEN-DATA-CHANNEL-01 + OPEN-DATA-SCORING-01/02 → bloqueia live, **não** o design.
- **OPEN-DATA-OPP-08** *(governança, menor)*: ação `define_opportunity` fora da allow-list publicada do `data_agent` → Orchestrator ratificar.

---

```json
{
  "task_id": "task_define_opportunity",
  "agent": "data_agent",
  "status": "completed",
  "summary": "Opportunity Agent (opportunity-rules-2026_06_v1) definido em DESIGN-only: nó terminal do pipeline determinístico que consome final_score/raw_score/componentes de artist_metrics (DATA-SCORING-001) e a contagem de canais distintos (DATA-CHANNEL-001) e produz reports + report_items (10 linhas ranqueadas por run). RANKING = ordem total final_score DESC -> raw_score DESC -> artist_id ASC (chave de negocio ratificavel OPEN-DATA-OPP-03; desempates garantem ordem total). HOT = final_score>90 estrito (inviolavel), conjunto = top-2 por Score (cap-de-2 determinístico); caso >2 pinado, caso <2 e conflito PRD 4.4 x 5.2 -> OPEN-DATA-OPP-02 (recomendacao: no maximo 2, nunca fabricar HOT<=90). Score exibido: score_display 'X/100' so se final_score>83, senao NULL (linha permanece); score_value interno sempre. Competition: bucket Low<=5/Medium6-15/High>15 sobre channel_diversity_count + override por crescimento de publicacoes 7d>50% -> enum competition_level; constantes = PROPOSTAS nao travadas (OPEN-DATA-OPP-01), semantica do gatilho 7d (div-por-zero/escopo/audit-slot) = OPEN-DATA-OPP-04. Example: ValidVideos -> vel por-video (consumida de metrics_detail_json.videos.accepted[].vel, NAO recomputada) -> top-3 por vel -> mais recente -> maior views -> min video_id, gravado em selection_reason_json {candidates(>=1),top3(>=1),tiebreak,selected_example.video_id} satisfazendo o validador F5-05A por construcao. Determinismo: funcao pura (sem rede/LLM/relogio; tempo=window_end), ordem total por chave natural, numeric exato -> P5-REPRO-01; Example identico em reprocesso -> risco 'Example no olho' eliminado. Escreve em report draft (working set); publish draft->published (admin) congela por trigger F5-01. reports/report_items ja aplicados (Fase 5); nenhum apply/migration/codigo/coleta/IA/numero executado. Score/Velocity/Signals/Competition CONSUMIDOS sem redefinir. Versao do Opportunity e evidencia 7d recomendadas como chaves ADITIVAS em selection_reason_json (aceitas por F5-05A, zero ALTER) -> OPEN-DATA-OPP-05/04. Compute-live herdado de OPEN-DATA-CHANNEL-01 + OPEN-DATA-SCORING-01/02 (OPEN-DATA-OPP-07) nao bloqueia o design.",
  "artifacts": [
    { "type": "spec", "path": "docs/data/DATA-OPP-001-opportunity-spec.md", "description": "Criado: spec de design do Opportunity Agent (ranking determinístico, HOT + cap-de-2, gate de exibicao >83, Competition bucketing + gatilho 7d, Example + selection_reason_json/F5-05A, formatacao, versionamento opportunity-rules-2026_06_v1, reprodutibilidade/auditoria por celula, OPEN QUESTIONS, escopo negativo)." },
    { "type": "handoff", "path": "docs/data/HANDOFF-task_dataengine_define_opportunity.md", "description": "Criado: handoff de governanca desta tarefa (design-only, nada executado)." }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "data_agent",
    "action": "implement_deterministic_pipeline",
    "priority": "high",
    "reason": "Pipeline determinístico agora especificado ponta a ponta (Collect->Entity->Channel->Scoring->Opportunity). Proximo passo: implementar o data-engine determinístico em services/data-engine (opportunity-rules-2026_06_v1 + score_rubric_2026_06_v1 + channel-filter-v1 + entity-resolver-v1) com fixtures e comparacao byte-a-byte (P5-REPRO-01), computando os hashes em codigo e persistindo versao/evidencia via chaves aditivas em selection_reason_json/metrics_detail_json (zero ALTER). Antes de compute-live e do 1o publish, Product Lead + Data/AI devem ratificar OPEN-DATA-OPP-01 (constantes de Competition), OPEN-DATA-OPP-02 (conflito 2-HOT) e OPEN-DATA-OPP-06 (composicao), e destravar OPEN-DATA-CHANNEL-01 (coleta de canal) + OPEN-DATA-SCORING-01/02 (constantes/curvas)."
  }
}
```
