# 06 · Execution Plan, RACI & Backlog

**Objetivo:** transformar escopo em plano executável.

---

## 1. Timeline recomendada

### Semana 0 — Preparação
- Travar decisões de escopo.
- Definir owner de produto, engenharia, dados e marketing.
- Criar repositório.
- Configurar Supabase, Vercel e Sentry.
- Montar lista inicial de produtores.

### Semana 1 — Base técnica e coleta
- Construir landing/apply page.
- Criar auth gate.
- Criar schema base.
- Implementar coleta de vídeos YouTube.
- Rodar primeira coleta de 500 vídeos.

### Semana 2 — Metodologia e relatório
- Resolver artistas.
- Aplicar filtros de canal.
- Calcular Score por código.
- Montar Relatório 1 e Relatório 2.
- Revisar exemplos.
- Publicar relatório fechado.

### Semana 3 — Convites e uso
- Enviar Wave 1.
- Aprovar produtores.
- Monitorar abertura e ações.
- Ajustar bugs de UX sem alterar metodologia.

### Semana 4 — Follow-up
- Enviar follow-ups de intenção.
- Coletar produção real.
- Capturar WTP.
- Consolidar métricas.

### Semana 5 — Decisão
- Comparar resultados com critérios de sucesso.
- Decidir: avançar, repetir vertical, ajustar metodologia ou abortar hipótese.

---

## 2. RACI

| Área / Atividade | Product Lead | Product Ops | Backend Engineer | AI Engineer | Frontend/Design | Marketing |
|---|---|---|---|---|---|---|
| Decisão de escopo | A | C | C | C | C | C |
| PRD e critérios de sucesso | A | R | C | C | C | C |
| Landing/apply page | A | C | C | C | R | C |
| Lista de produtores | C | R | I | I | I | A/R |
| Convites DM/email | C | R | I | I | I | A/R |
| Schema Postgres | C | C | A/R | C | I | I |
| Coleta YouTube | C | I | C | A/R | I | I |
| Rubric de Score | A | C | C | R | I | I |
| Pipeline de agentes | C | I | C | A/R | I | I |
| Report UI | A | C | C | C | R | C |
| Eventos e métricas | A | R | R | C | C | C |
| Follow-up 10–14 dias | A | R | C | I | I | C |
| Análise final | A/R | R | C | C | C | C |

Legenda:  
**A** = accountable, decisão final.  
**R** = responsável pela execução.  
**C** = consultado.  
**I** = informado.

---

## 3. Backlog MVP

### Epic 1 — Produto fechado

#### PL-001 — Landing/apply page noindex
**Prioridade:** P0  
**Aceite:** produtor consegue entender a proposta e aplicar; página não é indexável.

#### PL-002 — Formulário de aplicação
**Prioridade:** P0  
**Aceite:** aplicação salva no banco com status `submitted`.

#### PL-003 — Aprovação manual admin
**Prioridade:** P0  
**Aceite:** admin altera status para `approved` ou `rejected` com nota.

#### PL-004 — Auth gate
**Prioridade:** P0  
**Aceite:** apenas produtor aprovado acessa `/app/report`.

---

### Epic 2 — Report UI

#### RP-001 — Tabela do relatório
**Prioridade:** P0  
**Aceite:** exibe Title, Tag, Score, Signals, Velocity, Competition e Example.

#### RP-002 — Dois snapshots
**Prioridade:** P0  
**Aceite:** usuário alterna entre Relatório 1 e 2 com copy honesta.

#### RP-003 — Example clicável
**Prioridade:** P0  
**Aceite:** clique abre vídeo do YouTube e registra evento.

#### RP-004 — Feedback por artista
**Prioridade:** P0  
**Aceite:** usuário marca útil/não útil por artista.

#### RP-005 — Intenção de produção
**Prioridade:** P0  
**Aceite:** usuário marca `vou produzir`; evento gera follow-up pendente.

---

### Epic 3 — Data engine

#### DE-001 — Search Agent
**Prioridade:** P0  
**Aceite:** coleta ~500 vídeos da keyword travada na janela de 30 dias.

#### DE-002 — Video Data Agent
**Prioridade:** P0  
**Aceite:** estatísticas dos vídeos salvas em raw_youtube_videos.

#### DE-003 — Entity Resolution
**Prioridade:** P0  
**Aceite:** artista é extraído com método registrado e casos ambíguos marcados.

#### DE-004 — Channel Filter
**Prioridade:** P0  
**Aceite:** canais elegíveis/inelegíveis salvos com motivo.

#### DE-005 — Score deterministic
**Prioridade:** P0  
**Aceite:** Score gerado por código com rubric_version e componentes.

#### DE-006 — Example deterministic
**Prioridade:** P0  
**Aceite:** Example escolhido pela regra documentada.

---

### Epic 4 — Follow-up e validação

#### FV-001 — Scheduler de follow-up
**Prioridade:** P0  
**Aceite:** intenção gera follow-up com due_at em 10–14 dias.

#### FV-002 — Envio de follow-up
**Prioridade:** P0  
**Aceite:** email ou tarefa manual de DM é gerada.

#### FV-003 — Captura de resposta
**Prioridade:** P0  
**Aceite:** resposta salva como evento e/ou followup.response.

#### FV-004 — WTP
**Prioridade:** P0  
**Aceite:** produtor responde sim/não/talvez e faixa opcional.

---

### Epic 5 — Métricas admin

#### MT-001 — Dashboard mínimo
**Prioridade:** P1  
**Aceite:** Product Lead vê aplicação, abertura, intenção, follow-up e WTP.

#### MT-002 — Export CSV
**Prioridade:** P1  
**Aceite:** eventos podem ser exportados para análise manual.

---

## 4. P0 absoluto

Sem estes itens, o MVP não deve ir ao ar:

1. Acesso fechado.
2. Report UI com 2 snapshots.
3. Score determinístico.
4. Competition por canais distintos.
5. Example determinístico.
6. Eventos de intenção.
7. Follow-up 10–14 dias.
8. WTP.
9. Auditoria básica até raw data.

---

## 5. P1 permitido

Pode entrar se não atrasar P0:

- dashboard admin bonito;
- export CSV;
- PostHog;
- filtros visuais;
- animações premium;
- tooltips extras;
- convite por email automatizado.

---

## 6. P2 / Fase 2

Não construir agora:

- query sob demanda;
- 1 query/dia real;
- multi-nicho;
- pagamentos;
- plano pago;
- Celery/Redis obrigatório;
- marketplace;
- sub-perfis;
- data lake diário;
- ML scoring.

---

## 7. Definition of Done do MVP

O MVP está pronto para validação quando:

- 2 relatórios estão publicados e congelados;
- pelo menos 20 produtores podem ser aprovados;
- todo clique/feedback/intenção gera evento;
- follow-up é criado automaticamente ou em fila operacional;
- Product Lead consegue calcular as métricas de sucesso;
- nenhum texto da UI sugere geração em tempo real ou previsão garantida;
- nenhum número público está sem método rastreável.

---

## 8. Checklist de lançamento

### Produto
- [ ] Landing noindex.
- [ ] Formulário funcionando.
- [ ] Auth funcionando.
- [ ] Approval gate funcionando.
- [ ] Relatórios revisados.
- [ ] Copy honesta no botão de alternância.

### Dados
- [ ] Coleta 500 vídeos concluída.
- [ ] Raw salvo.
- [ ] Rubric versionado.
- [ ] Score calculado por código.
- [ ] Examples auditáveis.

### Marketing
- [ ] Lista de 100 produtores.
- [ ] Wave 1 preparada.
- [ ] DM copy aprovada.
- [ ] Email copy aprovada.

### Validação
- [ ] Eventos implementados.
- [ ] Follow-up scheduler implementado.
- [ ] WTP implementado.
- [ ] Dashboard/export disponível.

