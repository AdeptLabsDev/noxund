## DEC-0017 — Ratificação v1 do pipeline determinístico: Opportunity (2-HOT honesto · ranking · composição), Score rubric `score_rubric_2026_06_v1`, Channel Filter `channel-filter-v1` (minimalista), DC2-01 fail-closed, e autorização da **trilha gated** de coleta de Channel Data (sem execução livre)

- **Data:** 2026-07-01
- **Status:** **Registrada — decisão de Product Lead.** Ratifica constantes/regras v1 do pipeline e resolve as decisões abertas OPP-02/03/06, SCORING-01..04, CHANNEL-02, DC2-01. **Não** altera tese, escopo travado, pesos §7 (40/25/20/15) nem non-negotiables.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator · designs por `data_agent` (`DATA-OPP-001`, `DATA-SCORING-001`, `DATA-CHANNEL-001`, `DATA-COLLECT-002`, `DATA-CONST-001`)
- **Área:** Metodologia (Score/Competition/Opportunity determinísticos) / Coleta (Channel Data) / Processo de gate
- **Relaciona:** DEC-0013 (pipeline-first), DEC-0016 (CI verde), `03_Data_AI_Agents_Methodology.md` §7/§8 (pesos + HOT>90 + Competition 5/15/50%), `01_MVP_Scope_PRD.md` §4.4/§5 (composição, HOT, display>83, Competition), `DATA-CONST-001` (proposta — **ratificada/revisada aqui**), `DATA-OPP-001`, `DATA-SCORING-001`, `DATA-CHANNEL-001`, `DATA-COLLECT-002`

### Contexto
Com os designs do Channel Filter, Channel Data collection, Popularity Scoring e Opportunity completos e verificados na fonte pelo Orchestrator (pesos 40/25/20/15 travados em §7; Velocity=mediana em PRD §5.5; Competition Low≤5/Med6-15/High>15 ou crescimento-7d>50% travado em metodologia L194-196 + PRD L207-209), o Product Lead ratificou as constantes/regras **v1** e resolveu as decisões abertas, incluindo o conflito de `/context` OPP-02.

### Decisão (o que se registra)

**1. OPP-02 — 2-HOT × Score>90 → "no máximo 2 HOT, honesto".** HOT existe **apenas** se `Score > 90`. O relatório exibe **0, 1 ou 2** HOT. **Nunca** promover artista com `Score ≤ 90` para cumprir quota visual. Se <2 cruzam 90, exibe-se honestamente <2 HOT. *(Resolve o conflito PRD L124 × PRD L159/metodologia L186 preservando o non-negotiable "nada de número/HOT falso".)*

**2. OPP-03 — chave de ranking.** Ordem principal `final_score DESC`; tie-breakers determinísticos, nesta ordem: `final_score DESC` → `velocity_component DESC` → `signals_component DESC` → `artist_id ASC`. *(Ratifica a chave — a metodologia não fixava a ordenação do relatório; "ordenar por velocity" era do Example. Supersede a proposta `raw_score`-based do `DATA-OPP-001`.)*

**3. OPP-06 — composição do relatório.** Exibe **até 10** artistas qualificados; **display gate `Score ≥ 83`**; HOT tag em até 2 com `Score > 90`. Se <10 têm `Score ≥ 83`, exibe <10. Se **todos <83**, marca o relatório `insufficient_opportunity` (sem oportunidades qualificadas). **Nunca** preencher slot com artista <83. **MVP:** cada relatório = um `run_id` próprio; os **2 relatórios fixos = 2 runs/relatórios distintos**, mesmo que simulados no fluxo de RE-GEN.

**4. SCORING v1 → `score_rubric_2026_06_v1` (ratificado como proposto).** `P_VEL=p90` · `SIGNALS_SAT_CAP=20` · `P_ENG=p90` · `DIVERSITY_TARGET=15` · `LAMBDA_REC=meia-vida 15d (λ≈0,046/dia)` · `AGE_FLOOR_DAYS=1`. Curvas: Velocity/Engajamento **percentil-âncora+teto**; Signals/Diversity **ln-saturating**; Recência **exponencial**. Arredondamento **ROUND_HALF_UP**. Referência de normalização: **artistas do próprio run, sem baseline histórico** — aceita-se **não-comparabilidade** entre relatórios (objetivo v1 = ranking interno do run, determinístico e auditável). Estes valores + curvas + método de interpolação de percentil **congelam no `rubric_hash`**; qualquer mudança ⇒ novo `rubric_version`.

**5. CHANNEL-02 → `channel-filter-v1` (REVISADO — minimalista).** Política v1: o Channel Filter evita **apenas domínio extremo de um único canal dentro do run**; **não** filtra por tamanho de canal, inscritos, views totais, uploads públicos ou duplicidade de título. Constantes:
- `MAX_RUN_VIDEOS_PER_CHANNEL = 60` (único gate quantitativo ativo — anti-domínio extremo);
- `MIN_PUBLIC_UPLOADS = disabled` (sem floor de elegibilidade);
- `MIN_SUBS = disabled`; `MIN_CHANNEL_VIEWS = disabled` (sem floors de tamanho);
- `DUP_TITLE_CAP = disabled/removido do v1`.

*Justificativa (DUP_TITLE_CAP):* em "chicago drill type beat", títulos repetidos/muito similares são comportamento normal do nicho (SEO, gênero, referência de artista, intenção comercial), **não** evidência confiável de spam; usá-lo distorceria Competition/Signals e removeria produtores legítimos. **Supersede** o conjunto de 4 gates ordenados do `DATA-CHANNEL-001` (spec-refresh v1 é follow-up design-only). Mudança de constante/regra ⇒ novo `rule_version`.

**6. DC2-01 — canal deletado/suspenso → fail-closed agora.** Se `channels.list` não retornar um canal necessário ao run, o run **aborta/requer recoleta como novo `run_id`**. **Sem tombstone** agora (opção aditiva futura se aparecer na prática).

**7. Trilha gated de coleta de Channel Data (Passo 4) — AUTORIZADO iniciar; execução livre NÃO.**
- **Autorizado:** Security revisar SEC-F23 / PII pública de canal; DevOps desenhar pipeline de coleta **gated**; Database revisar DC2-01 + slots aditivos futuros; Data/AI preparar implementação determinística + contrato de coleta; preparar runbook `channels.list → raw_youtube_channels`.
- **NÃO autorizado (ainda):** rodar coleta real sem gates; usar API key/secret sem pipeline aprovado; publicar relatório real **antes de P5-REPRO-01**; tocar Fase 9/RLS Policies; destravar `0007/producer_events`.

**8. Próximos passos autorizados.** Landar `DATA-OPP-001` + `DATA-CONST-001` em `main` como docs de design (PR revisado, sem auto-merge). Rascunhar o código determinístico `channel-filter → scoring → opportunity` desde que: **não** compute-live; **não** rode coleta real; **não** publique; **fique atrás** das constantes ratificadas e da coleta de canal gated.

### Versões congeladas por esta DEC
- `score_rubric_2026_06_v1` (Score) — item 4.
- `channel-filter-v1` (Channel Filter minimalista) — item 5.

### Itens abertos remanescentes (não-bloqueantes deste registro)
- **self_channel (micro-open — pede confirmação):** a política minimalista removeu os filtros de tamanho, mas **não** menciona a exclusão do **canal do próprio artista** da contagem de Competition (regra semântica, não filtro de tamanho). **Recomendação do Orchestrator:** manter `self_channel` em v1 (o canal do próprio artista não é "competição"; mantê-lo distorce Competition). **Aguarda confirmação do Product Lead.**
- **Movidos para a trilha gated (item 7):** DC2-02 (SEC-F23/PII), DC2-04 (same-run sub-fase), runbook.
- **Aditivos futuros (Database):** OPP-04 (slot de auditoria do crescimento-7d), OPP-05 (`opportunity_version/hash`), CHANNEL-03 (`reason` enum), CHANNEL-05 (`rule_hash`), DC2-03 (`publishedAt`).
- **Spec-refresh design-only:** atualizar `DATA-CHANNEL-001` (rule set) e `DATA-CONST-001`/`DATA-SCORING-001` (OPEN→ratificado) ao v1 desta DEC.

### Reversibilidade
Alta. Constantes/regras vivem em `rubric_version`/`rule_version` versionados e congelados por `hash`; nada aplicado a schema (zero ALTER). Reverter = novo `rubric_version`/`rule_version`. Nenhum dado, nenhuma migration, nenhuma coleta real executada.

### Sequenciamento (próximo)
1. Landar `DATA-OPP-001` + `DATA-CONST-001` + esta DEC (PR revisado, sem auto-merge).
2. Confirmar `self_channel` (item aberto).
3. Iniciar a trilha gated do Passo 4 (rotear Security/DevOps/Database/Data-AI — review/design only).
4. Rascunhar o código determinístico (atrás das constantes + coleta gated; sem compute-live).
5. **P5-REPRO-01** como gate fail-closed antes de qualquer publish. Fase 9 vetada; `0007` parked.
