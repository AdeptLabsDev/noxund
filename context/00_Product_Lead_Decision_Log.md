## 1. Decisão-mãe

### Decisão
O MVP da NOXUND será o **NOXUND Hotspot Artists Report**, não um marketplace.

### Motivo
O maior risco da NOXUND é o cold-start de marketplace de dois lados. Entrar como ferramenta de inteligência para produtores já validados resolve primeiro o lado difícil: oferta qualificada. O produtor pode usar o Hotspot sem abandonar BeatStars, YouTube ou seu fluxo atual. Isso reduz resistência, gera valor single-player e cria caminho para marketplace depois.

### Implicação prática
No MVP não serão construídos:

- checkout;
- carrinho;
- upload/download de beat;
- sistema de licenças;
- payout;
- split automático;
- marketplace público;
- busca pública de beats;
- perfis públicos de produtores;
- sub-perfis/beatmaker names em produção.

Esses itens ficam como **Fase Marketplace**, não MVP.

---

## 2. Decisão de posicionamento

### Decisão
Usar a headline:

> **Market intelligence engine for producers.**

E a subheadline:

> **See what's working, stay in the scene.**

### Motivo
O produto não deve se posicionar como “gerador de artistas por IA”, “previsão de viralização” ou “marketplace de beats”. O valor defensável é traduzir sinais públicos de mercado em uma lista acionável e verificável para produtores.

### Regra de comunicação
A NOXUND pode dizer:

> “Mostramos artistas com tração recente real dentro de uma cena específica, com sinais verificáveis.”

A NOXUND não pode dizer:

> “Nossa IA prevê quem vai estourar.”

---

## 3. Decisão de vertical

### Decisão
O MVP terá uma única vertical:

- **Nicho:** Chicago Drill
- **Keyword:** `chicago drill type beat`
- **Janela:** últimos 30 dias
- **Amostra:** 500 vídeos via YouTube Data API

### Motivo
Uma única vertical reduz variância, custo de validação e ruído metodológico. O objetivo não é provar que a NOXUND funciona em todos os gêneros; é provar que um relatório de inteligência muda comportamento de produção em uma cena específica.

---

## 4. Decisão de acesso

### Decisão
O acesso será fechado, por convite e aprovação manual.

### Implementação
- Criar uma landing/apply page premium, mas **noindex** e não posicionada como página pública de aquisição massiva.
- Montar uma lista inicial de **100 produtores-alvo**.
- Enviar convites em ondas:
  - Wave 1: 40–60 convites.
  - Wave 2: reposição até atingir 20–30 aprovados.
- Aprovar manualmente apenas produtores ativos de type beat com canal/portfólio real.

### Motivo
A qualidade do feedback importa mais que escala. Curiosos, iniciantes sem canal ou produtores fora do nicho diluem o sinal do MVP.

---

## 5. Decisão sobre relatórios fixos vs geração real

### Decisão
O MVP terá **2 relatórios fixos**, cada um com:

- 10 artistas;
- 2 artistas marcados como HOT;
- dados derivados da mesma metodologia.

O botão não deve se chamar “Re-Gen” se isso insinuar geração em tempo real. A copy correta é:

> **Ver outro grupo de oportunidades**

ou

> **Relatório 1 de 2 / Relatório 2 de 2**

### Motivo
Simular geração dinâmica quando o relatório é pré-estruturado enfraquece a credibilidade analítica, que é o ativo central da NOXUND.

---

## 6. Decisão sobre query por produtor

### Decisão
No MVP, o produtor **não executa consulta sob demanda**.

A keyword fica travada e visível para comunicar visão de produto futuro, mas o sistema entrega snapshots estáticos.

### Observação
A regra de **1 query/dia por produtor** fica registrada como política de Fase 2, quando existir pipeline sob demanda real. No MVP, implementar essa limitação como feature seria teatro de produto, não validação.

---

## 7. Decisão sobre Score

### Decisão
O Score deve ser determinístico, versionado e calculado por código.

### Rubric MVP
| Componente | Peso | Mede |
|---|---:|---|
| Velocity normalizada | 40% | Views/dia do artista relativo à distribuição da amostra de 500 vídeos. |
| Signals | 25% | Quantidade de vídeos válidos do artista na janela, com penalização de excesso. |
| Engajamento ponderado por recência | 20% | `(likes + comentários) / views`, com peso maior para vídeos mais recentes. |
| Diversidade de canais | 15% | Validação de demanda por múltiplos canais distintos. |

### Regra pública
O usuário vê apenas `X/100` e um tooltip conceitual. O usuário não vê a fórmula completa.

### Regra interna
Todo Score precisa guardar:

- componentes;
- pesos;
- versão/hash do rubric;
- vídeos usados;
- data da coleta;
- run_id.

---

## 8. Decisão sobre IA generativa

### Decisão
A IA generativa **não calcula, julga nem exibe números**.

### Permitido no MVP
- Extração assistida do nome do artista em títulos ambíguos.
- Rascunho interno de microcopy, se necessário.

### Proibido no MVP
- IA gerando Score;
- IA escolhendo ranking;
- IA definindo Competition;
- IA escolhendo Example;
- IA escrevendo insight analítico sobre artista no relatório.

### Motivo
O produto vende confiança. Qualquer número precisa ser rastreável até dados brutos da YouTube Data API.

---

## 9. Decisão sobre data lake / séries temporais

### Decisão
Não construir data lake diário no MVP.

### Motivo
A spec exclui análise histórica além da janela de 30 dias. Coletar diariamente todos os artistas rastreados antecipa custo de Fase 2 antes de validar a hipótese central.

### O que fazer no MVP
Armazenar snapshots brutos de cada rodada de coleta. Isso permite auditoria e reprocessamento, sem manter uma operação diária contínua.

---

## 10. Decisão sobre exposure penalty

### Decisão
Não implementar `exposure_penalty` no MVP.

### Motivo
O MVP tem dois relatórios fixos, não um feed contínuo. Penalizar exposição só faz sentido quando houver múltiplas rodadas, personalização ou geração recorrente.

### Status
Fase 2. Só entra com fórmula documentada, versionada e auditável.

---

## 11. Decisão sobre ML scoring

### Decisão
Não usar ML para scoring no MVP.

### Motivo
O MVP precisa começar com um rubric simples, transparente e reproduzível. ML só será justificável depois que houver volume suficiente de eventos reais de produtor.

### Requisito futuro não negociável
Se ML entrar na Fase 2 ou Fase 3, todo score gerado por modelo deve guardar:

- `model_version`;
- `feature_snapshot_id`;
- `training_dataset_version`;
- input features;
- output;
- data da inferência.

---

## 12. Decisão sobre stack

### Decisão
Usar stack híbrida, mas com cortes de MVP.

### Stack MVP aprovada
- **Frontend + Core API:** Next.js + TypeScript.
- **UI:** Tailwind CSS + componentes próprios/shadcn.
- **Auth:** Supabase Auth ou Clerk. Decisão operacional recomendada: Supabase Auth para reduzir serviços no MVP.
- **Banco:** PostgreSQL via Supabase.
- **Data Engine:** Python.
- **API interna de dados:** FastAPI apenas se necessário; script/worker Python é suficiente para a primeira validação.
- **Email follow-up:** Resend ou Postmark.
- **Cron:** Vercel Cron ou Supabase Scheduled Functions.
- **Observabilidade:** Sentry primeiro; Datadog apenas se a operação crescer.
- **Redis/Celery:** não bloqueia MVP. Entram se a automação do pipeline virar recorrente ou se jobs passarem a travar execução.

---

## 13. Decisão sobre marketing

### Decisão
Marketing do MVP será founder-led, fechado, de cena e orientado por convite.

### Canais primários
- DM via conta de artista, não via conta institucional.
- Email curto e direto.
- Relacionamento com produtores ativos de Chicago Drill.

### Canais secundários
- Conteúdo público com dados agregados, sem abrir o produto.
- Comunidades de produtores.
- Parcerias com educadores/canais de type beat.

### Não fazer no MVP
- Ads pagos massivos.
- SEO aberto.
- Product Hunt.
- Promessa de marketplace.
- “AI hype”.

---

## 14. Critério de avanço para Fase 2

Avançar somente se todos os critérios forem atingidos:

| Critério | Mínimo |
|---|---:|
| Produtores validados engajados | N ≥ 15 |
| Taxa de intenção declarada | ≥ 30% |
| Confirmação real em 10–14 dias | ≥ 50% dos que declararam intenção |
| Sinal positivo de WTP | ≥ 25% |
| Abertura do relatório pelos aprovados | ≥ 70% |

Se não atingir, revisar curadoria/metodologia e canal de convite antes de pivotar.

