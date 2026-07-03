# MVP Backlog — NOXUND Hotspot Artists Report

**Mantido por:** Product Orchestrator Agent
**Base:** `06_Execution_RACI_Backlog.md` (semente) expandida para tarefas executáveis.
**Regra:** nenhuma tarefa vaga. Cada item tem critério de aceite verificável.

Prioridades: **P0** = sem isso o MVP não vai ao ar · **P1** = entra se não atrasar P0 · **P2** = Fase 2, não construir agora.

> **Ordem do sprint atual (DEC-0013 — pipeline-first).** Fundação de schema (Fases 1–5) está **live e verificada**. Foco agora: **Épico 5 (Data Pipeline)** → `[DATA] Search` → `Video Data` → `Entity Resolution` → `Channel Filter` → `Popularity Scoring` → `Opportunity` → **`Teste de reprodutibilidade (P5-REPRO-01, gate bloqueante antes do 1º publish)`** → publish (Backend/admin) → convite (GTM). A parte **`producer_events` (Fase 6)** fica em **background, design-only**, até a captura de eventos virar gargalo (após o 1º relatório publicado).

Owner agents: ver `docs/agents/README.md`.

---

## Épico 1 — Product Operations

### [PRODOPS] Estruturar camada operacional de docs
**Objetivo:** ter o centro operacional do MVP pronto antes de qualquer código.
**Descrição:** criar `docs/agents/*` e `docs/product/*` (Orchestrator, handoff, context-index, POS, backlog, decision log, guardrails).
**Critério de aceite:** todos os arquivos existem, linkados entre si e consistentes com `/context`.
**Dependências:** leitura de `/context`.
**Risco:** docs divergirem da fonte de verdade.
**Owner agent sugerido:** Product Orchestrator / Documentation.
**Prioridade:** P0

### [PRODOPS] Definir local e processo do decision log
**Objetivo:** resolver OD-06 (onde decisões vivem).
**Descrição:** escolher `docs/product/decisions/<id>.md` vs `DECISIONS.md`; documentar o fluxo de registro.
**Critério de aceite:** padrão escolhido, registrado como DEC-001, refletido no POS.
**Dependências:** decision-log-template.md.
**Risco:** decisões dispersas/sem rastro.
**Owner agent sugerido:** Product Orchestrator.
**Prioridade:** P0

### [PRODOPS] Resolver OPEN DECISIONS de fundação
**Objetivo:** fechar OD-02 (Auth), OD-03 (Email), OD-04 (Cron), OD-05 (FastAPI), OD-07 (Head of Product vazio).
**Descrição:** levar cada OD ao Product Lead com recomendação; registrar como DEC-NNN.
**Critério de aceite:** cada OD com status final (Aprovada/Rejeitada) no decision log.
**Dependências:** scope-guardrails.md.
**Risco:** retrabalho se decididos tarde.
**Owner agent sugerido:** Product Orchestrator.
**Prioridade:** P0

### [PRODOPS] Métricas de sucesso instrumentáveis
**Objetivo:** garantir que North Star e secundárias são calculáveis a partir de eventos.
**Descrição:** mapear cada métrica (`01_...` §8) para a query de `04_...` §13.
**Critério de aceite:** documento liga métrica → evento → query; nenhuma métrica sem fonte.
**Dependências:** modelo de eventos.
**Risco:** medir curiosidade em vez de comportamento.
**Owner agent sugerido:** Product Orchestrator / QA.
**Prioridade:** P0

---

## Épico 2 — Frontend

### [FE] Landing/apply page noindex
**Objetivo:** apresentar a proposta e capturar aplicação qualificada.
**Descrição:** página premium, `noindex`, copy honesta (nota "fixed report snapshots, not real-time generation"), CTA `Request Access`.
**Critério de aceite:** página entendível, não indexável (meta noindex + robots), sem copy proibida.
**Dependências:** copy aprovada (Épico 9).
**Risco:** copy sugerir previsão/IA mágica.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] Formulário de aplicação
**Objetivo:** coletar dados do produtor.
**Descrição:** campos do `01_...` §4.1; `POST /apply`; validação client+server.
**Critério de aceite:** aplicação válida persiste com status `submitted` e gera evento `application_submitted`.
**Dependências:** `POST /apply` (Backend), schema (Database).
**Risco:** spam/curiosos.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] Report UI — tabela
**Objetivo:** entregar a experiência central do Hotspot.
**Descrição:** tabela com Title, Tag (HOT), Score (`X/100` só se >83), Signals, Velocity, Competition, Example clicável; tooltip público do Score.
**Critério de aceite:** renderiza as 7 colunas conforme regras de exibição; HOT visível só quando aplicável.
**Dependências:** dados (mock na Sprint 1, real na Sprint 3).
**Risco:** expor número sem rastro.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] Toggle honesto entre os 2 relatórios
**Objetivo:** alternar relatórios sem simular IA.
**Descrição:** botão "Ver outro grupo de oportunidades" / "Relatório 1 de 2"; sem animação de "processando".
**Critério de aceite:** alterna entre snapshots; gera evento `report_switched`; nenhuma copy de geração ao vivo.
**Dependências:** dois snapshots.
**Risco:** parecer fake realtime AI.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] Ações por artista + Example clicável
**Objetivo:** capturar feedback e intenção.
**Descrição:** botões `Útil`, `Não útil`, `Vou produzir`; clique no Example abre YouTube em nova aba.
**Critério de aceite:** cada ação chama o endpoint correto e dispara o evento; clique no Example gera `example_clicked`.
**Dependências:** endpoints de feedback/intent (Backend).
**Risco:** evento norte (`intent`) não registrado.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] WTP UI
**Objetivo:** capturar disposição a pagar.
**Descrição:** componente sim/não/talvez + faixa opcional + texto livre.
**Critério de aceite:** resposta persiste em `wtp_responses` e gera evento `wtp_*`.
**Dependências:** `POST /api/wtp`.
**Risco:** WTP não capturado.
**Owner agent sugerido:** Frontend.
**Prioridade:** P0

### [FE] Mock fiel ao schema (Sprint 1)
**Objetivo:** navegar o produto sem pipeline real.
**Descrição:** dados fake de 2 relatórios respeitando os campos de `report_items`.
**Critério de aceite:** UI completa funciona só com mock; troca para dados reais sem mudar componentes.
**Dependências:** schema de report_items.
**Risco:** mock divergir do schema real.
**Owner agent sugerido:** Frontend.
**Prioridade:** P1

---

## Épico 3 — Backend/API

### [BE] Auth gate + approval gate
**Objetivo:** só produtor aprovado acessa o relatório.
**Descrição:** sessão autenticada (magic link/senha simples); middleware checa `producers.status = approved`.
**Critério de aceite:** acesso a `/app/report` negado para não autenticado e para autenticado não aprovado.
**Dependências:** Auth (OD-02), schema producers.
**Risco:** acesso indevido a dados fechados.
**Owner agent sugerido:** Backend / Security.
**Prioridade:** P0

### [BE] Endpoint `POST /apply`
**Objetivo:** registrar aplicação.
**Descrição:** valida payload, cria `producers` + `applications` (`submitted`), gera evento.
**Critério de aceite:** aplicação persistida e idempotente por email; sem PII em log.
**Dependências:** schema.
**Risco:** duplicidade/spam.
**Owner agent sugerido:** Backend.
**Prioridade:** P0

### [BE] Endpoints de feedback / intent / wtp
**Objetivo:** capturar eventos de produto.
**Descrição:** `POST /api/report/:r/artist/:a/feedback`, `.../intent`, `POST /api/wtp`; cada um grava `producer_events`.
**Critério de aceite:** evento correto criado; `intent` dispara criação de follow-up pendente.
**Dependências:** schema eventos + followups.
**Risco:** evento norte perdido ou duplicado.
**Owner agent sugerido:** Backend.
**Prioridade:** P0

### [BE] Captura de resposta do follow-up
**Objetivo:** fechar o loop de validação e produzir o evento obrigatório "follow-up respondido" (`02_...` §10) — gap §2-E do BE-0001, resolvido em **DEC-0004**.
**Descrição:** canal `email` → página mínima via **link assinado, single-use, expirável**; canal `dm_manual` → captura pelo admin em `/admin`. Ambos gravam `followups.response` + emitem `producer_events` (`followup_confirmed_produced`/`_not_produced`) via RPC atômica.
**Critério de aceite:** resposta persiste em `followups` e gera o evento; métrica "Confirmação em follow-up" (`04_...` §13) tem caminho de entrada; token assinado revisado por Security.
**Dependências:** RPC atômica (Database), token/rota (Security), OD-03 (Email) só para o envio.
**Risco:** métrica de confirmação (LD-14 ≥50%) sem captura.
**Owner agent sugerido:** Backend / Security.
**Prioridade:** P0

### [BE] API admin mínima
**Objetivo:** operar aprovação e publicação.
**Descrição:** `GET /admin/applications`, `PATCH /admin/applications/:id/status`, `POST /admin/reports/:id/publish`, `GET /admin/metrics`; protegida por role.
**Critério de aceite:** só admin acessa; status muda com nota; publicar congela snapshot.
**Dependências:** roles (Security).
**Risco:** endpoint sensível exposto.
**Owner agent sugerido:** Backend / Security.
**Prioridade:** P0

### [BE] Internal job endpoints protegidos
**Objetivo:** rodar follow-ups e (opcional) coleta.
**Descrição:** `POST /internal/followups/run-due` e `POST /internal/youtube/run-collection` (ou CLI), protegidos por secret.
**Critério de aceite:** acesso só com secret; sem secret em log; CLI aceitável no MVP.
**Dependências:** cron (OD-04).
**Risco:** trigger público de jobs.
**Owner agent sugerido:** Backend / DevOps.
**Prioridade:** P1

---

## Épico 4 — Database

### [DB] Schema base (acesso + produtores)
**Objetivo:** suportar aplicação e aprovação.
**Descrição:** `producers`, `applications` conforme `04_...` §3, com enums de status.
**Critério de aceite:** aplicação pode ser enviada e aprovada; FKs e enums corretos.
**Dependências:** —.
**Risco:** estados inconsistentes.
**Owner agent sugerido:** Database.
**Prioridade:** P0

### [DB] Tabelas raw (imutáveis)
**Objetivo:** preservar fonte da verdade.
**Descrição:** `report_runs`, `raw_youtube_search_pages`, `raw_youtube_videos`, `raw_youtube_channels`; raw nunca sobrescrito.
**Critério de aceite:** recoleta cria novo `run_id`; nenhuma rota de update em raw.
**Dependências:** —.
**Risco:** raw mutável quebra auditoria.
**Owner agent sugerido:** Database / Data Integrity.
**Prioridade:** P0

### [DB] Tabelas computed + versionamento
**Objetivo:** métricas reconstruíveis e versionadas.
**Descrição:** `artist_metrics`, `channel_eligibility`, `video_artist_mappings`, `artists`, `artist_aliases`, `rubric_versions`, `outcome_weight_versions`.
**Critério de aceite:** computed recalculável a partir de raw; todo score guarda `rubric_version` + `rubric_hash` + `computed_from_video_ids`.
**Dependências:** raw.
**Risco:** misturar raw com computed.
**Owner agent sugerido:** Database / Data Integrity.
**Prioridade:** P0

### [DB] Tabelas de relatório + eventos + follow-up + WTP
**Objetivo:** suportar relatório congelado e validação.
**Descrição:** `reports`, `report_items` (com `selection_reason_json`), `producer_events`, `followups`, `wtp_responses`.
**Critério de aceite:** relatório reconstruível por `run_id` + `rubric_version`; eventos são log (sem flags mutáveis).
**Dependências:** computed.
**Risco:** relatório mutar após publicação.
**Owner agent sugerido:** Database / Data Integrity.
**Prioridade:** P0

### [DB] RLS e políticas de acesso
**Objetivo:** isolar dados por produtor/role.
**Descrição:** Row Level Security no Supabase para produtores e admin.
**Critério de aceite:** produtor só vê o que pode; admin separado por role; testado.
**Dependências:** Auth.
**Risco:** vazamento entre produtores.
**Owner agent sugerido:** Database / Security.
**Prioridade:** P0

### [DB] Funções RPC atômicas evento+payload
**Objetivo:** garantir atomicidade onde o produto escreve payload + evento no mesmo ato (achado do Backend; PostgREST é por statement).
**Descrição:** funções Postgres (`plpgsql`) para os pares: WTP (`wtp_responses` + `producer_events`), intenção (`producer_events` + `followups`) e resposta de follow-up (`followups.response` + `producer_events`) — DEC-0004.
**Critério de aceite:** cada par grava de forma atômica (tudo-ou-nada); falha não deixa evento órfão nem payload sem evento; revisada com Backend.
**Dependências:** tabelas de eventos/followups/WTP (Fases 6–7).
**Risco:** evento sem payload (ou vice-versa) distorce métrica.
**Owner agent sugerido:** Database / Backend.
**Prioridade:** P0

### [DB] Guarda contra schema de marketplace
**Objetivo:** impedir criação prematura de tabelas de Fase 2.
**Descrição:** documentar/CI-checar ausência de `beats`, `orders`, `payouts`, `licenses`, etc.
**Critério de aceite:** nenhuma tabela proibida (`04_...` §12) existe.
**Dependências:** —.
**Risco:** superfície de manutenção desnecessária.
**Owner agent sugerido:** Database.
**Prioridade:** P1

---

## Épico 5 — Data Pipeline

### [DATA] Search Agent (coleta)
**Objetivo:** coletar ~500 vídeos da keyword travada.
**Descrição:** `search.list` paginado, janela 30d; grava `raw_youtube_search_pages` + metadados de coleta.
**Critério de aceite:** ~500 vídeos coletados com `run_id`, query exata, janela e page tokens auditados.
**Dependências:** YouTube API key (Security).
**Risco:** quota/coleta inconsistente.
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Video Data Agent
**Objetivo:** estatísticas por vídeo.
**Descrição:** `videos.list` (statistics,snippet) em lotes de 50; grava `raw_youtube_videos` (payload bruto).
**Critério de aceite:** estatísticas salvas verbatim; payload bruto imutável.
**Dependências:** Search Agent.
**Risco:** sobrescrita de raw.
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Entity Resolution Agent (único ponto de IA)
**Objetivo:** extrair nome do artista do título.
**Descrição:** regex `<artist> type beat` primeiro; LLM só em ambíguo, com guardrail de substring e fila de revisão; grava método em `video_artist_mappings`.
**Critério de aceite:** nome sempre substring/normalização do título; baixa confiança → `needs_review=true`; método registrado.
**Dependências:** raw videos.
**Risco:** alucinação de nome.
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Channel Filter Agent
**Objetivo:** elegibilidade + canais distintos.
**Descrição:** heurística numérica de spam/histórico; grava `channel_eligibility` + contagem distinta por artista.
**Critério de aceite:** elegibilidade com motivo + `rule_version`; canais distintos alimentam Competition, vídeos válidos alimentam Signals (sem duplicar).
**Dependências:** mappings.
**Risco:** Competition duplicar Signals.
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Popularity Scoring Agent (determinístico)
**Objetivo:** calcular Score e componentes por código.
**Descrição:** rubric 40/25/20/15; normalização sobre a amostra; grava componentes + `rubric_hash` + `computed_from_video_ids`.
**Critério de aceite:** mesmo input ⇒ mesmo output; Score nunca editável à mão.
**Dependências:** eligibility + metrics.
**Risco:** Score arbitrário/irreprodutível.
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Opportunity Agent (ranking + HOT + Competition + Example)
**Objetivo:** montar as linhas do relatório.
**Descrição:** ranking; HOT se >90; Score exibido se >83; Competition por thresholds; Example por regra determinística (top-3 velocity → mais recente → maior views); grava `selection_reason_json`.
**Critério de aceite:** linhas com prova determinística; Example idêntico em reprocesso.
**Dependências:** scoring.
**Risco:** Example "no olho".
**Owner agent sugerido:** Data/AI Pipeline.
**Prioridade:** P0

### [DATA] Teste de reprodutibilidade
**Objetivo:** garantir credibilidade analítica.
**Descrição:** reprocessar o mesmo snapshot + mesmo rubric e comparar relatório.
**Critério de aceite:** relatório idêntico byte-a-byte nas células computadas; diferença = bug.
**Dependências:** pipeline completo.
**Risco:** divergência entre relatórios.
**Owner agent sugerido:** Data/AI Pipeline / QA.
**Prioridade:** P0

---

## Épico 6 — Security & Privacy

### [SEC] Gestão de secrets e API keys
**Objetivo:** nunca expor credenciais.
**Descrição:** `.env.example` sem valores; YouTube/email/Supabase service role só no server; checagem de vazamento.
**Critério de aceite:** nenhuma key no front/bundle; nenhum secret em log; `.env` no `.gitignore`.
**Dependências:** —.
**Risco:** key exposta.
**Owner agent sugerido:** Security.
**Prioridade:** P0

### [SEC] Proteção de endpoints sensíveis
**Objetivo:** fechar admin e internal jobs.
**Descrição:** roles para admin; secret para internal/cron; rate limiting básico em `/apply`.
**Critério de aceite:** admin/internal inacessíveis sem credencial; tentativa registra evento de erro.
**Dependências:** Auth, RLS.
**Risco:** endpoint sensível público.
**Owner agent sugerido:** Security / Backend.
**Prioridade:** P0

### [SEC] Privacidade de dados de produtor
**Objetivo:** tratar PII com cuidado mínimo.
**Descrição:** mapear PII (email, links), restringir acesso, logs limpos.
**Critério de aceite:** PII acessível só por server/admin; logs sem PII.
**Dependências:** schema.
**Risco:** vazamento de PII.
**Owner agent sugerido:** Security / Data Integrity.
**Prioridade:** P1

---

## Épico 7 — QA

### [QA] Fluxos críticos ponta a ponta
**Objetivo:** validar o caminho aplicar → aprovar → abrir → agir → follow-up.
**Descrição:** testar cada passo do loop de validação (`05_...` §9).
**Critério de aceite:** cada passo gera o evento esperado; nenhum estado órfão.
**Dependências:** Backend + Frontend + DB.
**Risco:** métrica norte não medível.
**Owner agent sugerido:** QA.
**Prioridade:** P0

### [QA] Edge cases
**Objetivo:** cobrir bordas que quebram credibilidade ou dados.
**Descrição:** vídeo sem estatística; título ambíguo; produtor não aprovado; relatório já publicado; falha de email; quota YouTube.
**Critério de aceite:** cada borda tratada com erro/evento previsto, sem corromper raw/computed.
**Dependências:** pipeline + endpoints.
**Risco:** falha silenciosa.
**Owner agent sugerido:** QA.
**Prioridade:** P0

### [QA] Verificação de honestidade de copy
**Objetivo:** garantir zero "fake realtime AI".
**Descrição:** varrer UI/landing por copy proibida (Re-Gen, "AI predicts", etc.).
**Critério de aceite:** nenhuma copy proibida; toggle e tooltip conformes.
**Dependências:** Frontend.
**Risco:** dano de credibilidade.
**Owner agent sugerido:** QA / Marketing.
**Prioridade:** P0

---

## Épico 8 — DevOps/Infra

### [INFRA] Ambientes local/staging/prod
**Objetivo:** ter os três ambientes do `02_...` §5.
**Descrição:** Next.js + Supabase (local/dev/staging/prod), Python com `.env`, dados fake local.
**Critério de aceite:** dev roda local com mock; staging em Vercel preview + Supabase staging.
**Dependências:** Supabase/Vercel (quando necessário).
**Risco:** antecipar infra sem necessidade.
**Owner agent sugerido:** DevOps.
**Prioridade:** P1

### [INFRA] Observabilidade (Sentry + eventos)
**Objetivo:** ver erros e eventos de produto.
**Descrição:** Sentry no app e engine; eventos técnicos obrigatórios (`02_...` §10).
**Critério de aceite:** erro técnico chega ao Sentry; eventos de produto no Postgres.
**Dependências:** schema eventos.
**Risco:** falhas invisíveis.
**Owner agent sugerido:** DevOps.
**Prioridade:** P1

### [INFRA] Job de coleta + cron de follow-up
**Objetivo:** rodar pipeline e follow-ups.
**Descrição:** job Python controlado para coleta; cron diário para `followups` due.
**Critério de aceite:** coleta executável de forma controlada; follow-ups due processados diariamente.
**Dependências:** cron (OD-04), pipeline.
**Risco:** follow-up esquecido.
**Owner agent sugerido:** DevOps / Backend.
**Prioridade:** P1

---

## Épico 9 — Marketing/GTM

### [GTM] Lista de 100 produtores-alvo
**Objetivo:** preparar aquisição por convite.
**Descrição:** planilha com nome, canal, email, social, nicho, evidência de atividade, nota de fit (`05_...` §4).
**Critério de aceite:** 100 produtores qualificados de Chicago Drill/Drill listados.
**Dependências:** —.
**Risco:** produtores fora do ICP.
**Owner agent sugerido:** Marketing/GTM.
**Prioridade:** P0

### [GTM] Copy aprovada (DM, email, onboarding, landing)
**Objetivo:** comunicação honesta e de cena.
**Descrição:** revisar/aprovar copy do `05_...` §5–§8; banir promessa de previsão/IA mágica.
**Critério de aceite:** copy aprovada, sem termos proibidos, com nota de honestidade na landing.
**Dependências:** —.
**Risco:** prometer demais.
**Owner agent sugerido:** Marketing/GTM.
**Prioridade:** P0

### [GTM] Plano de ondas de convite
**Objetivo:** operar Wave 1/2/3.
**Descrição:** Wave 1 (40–60), reposição até 20–30 aprovados, Wave 3 se necessário.
**Critério de aceite:** plano com volumes, sequência e critério de reposição.
**Dependências:** lista de produtores.
**Risco:** amostra < 15.
**Owner agent sugerido:** Marketing/GTM.
**Prioridade:** P1

---

## Épico 10 — Documentation

### [DOCS] Manter context-index atualizado
**Objetivo:** índice sempre fiel a `/context`.
**Descrição:** atualizar `context-index.md` a cada mudança de contexto.
**Critério de aceite:** índice reflete o estado atual de `/context`.
**Dependências:** —.
**Risco:** docs divergentes.
**Owner agent sugerido:** Documentation.
**Prioridade:** P1

### [DOCS] README operacional + `.env.example`
**Objetivo:** onboarding técnico mínimo.
**Descrição:** README de raiz operacional (sem apagar `context/`); `.env.example` documentado sem secrets.
**Critério de aceite:** novo dev entende estrutura e variáveis sem ver secrets reais.
**Dependências:** stack decidida.
**Risco:** vazar secret no exemplo.
**Owner agent sugerido:** Documentation / DevOps.
**Prioridade:** P1

### [DOCS] Glossário de metodologia público
**Objetivo:** sustentar credibilidade.
**Descrição:** descrever em linguagem pública o que Score/Velocity/Signals/Competition significam (sem fórmula).
**Critério de aceite:** texto consistente com tooltips e promessa metodológica (`03_...` §17).
**Dependências:** rubric.
**Risco:** promessa além do dado.
**Owner agent sugerido:** Documentation / Marketing.
**Prioridade:** P2

---

## P0 absoluto (não vai ao ar sem)

1. Acesso fechado (auth + approval gate).
2. Report UI com 2 snapshots + toggle honesto.
3. Score determinístico (rubric versionado).
4. Competition por canais distintos.
5. Example determinístico.
6. Eventos de intenção.
7. Follow-up 10–14 dias.
8. WTP.
9. Auditoria básica até raw data.
