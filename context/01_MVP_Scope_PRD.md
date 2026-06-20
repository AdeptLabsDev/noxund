# 01 · NOXUND Hotspot Artists Report — MVP Scope / PRD

**Produto:** NOXUND Hotspot Artists Report  
**Tipo de MVP:** validação fechada, manual-assistida, com dados reais  
**Vertical:** Chicago Drill  
**Keyword:** `chicago drill type beat`  
**Status:** escopo travado para execução

---

## 1. Problema

Produtores de type beat decidem para quais artistas produzir com base em intuição, feed, pedidos de audiência, observação manual de canais e sensação de cena. Isso gera três dores:

1. **Entrar tarde demais** em artistas já saturados por muitos produtores.
2. **Ignorar oportunidades emergentes** porque os sinais estão espalhados.
3. **Gastar horas em descoberta manual** sem uma leitura objetiva de tração recente.

A dor não é falta de dado. O YouTube já contém os sinais. A dor é transformar esses sinais em decisão rápida e confiável.

---

## 2. Hipótese central

> Se produtores ativos de type beat receberem sinais estruturados de tração recente, competição e prova verificável, uma parcela relevante deles mudará sua decisão de produção.

O MVP não valida se a tabela é bonita.  
O MVP não valida se “IA” parece interessante.  
O MVP valida se o relatório muda comportamento real de produção.

---

## 3. Público-alvo do MVP

### ICP inicial
Produtores de type beat ativos no nicho Chicago Drill, com canal próprio no YouTube ou portfólio público de beats.

### Critérios de aprovação
Um produtor pode entrar no beta se cumprir:

- publica type beats ou beats com regularidade;
- possui canal/portfólio real;
- atua ou consegue atuar no território de Chicago Drill/Drill;
- não aparenta bot/spam;
- entende a lógica “artista + type beat”.

### Fora do ICP
- produtores totalmente iniciantes sem canal;
- artistas buscando beats;
- beatmakers sem atividade pública recente;
- curiosos sem intenção de uso;
- labels/A&Rs.

---

## 4. Escopo funcional do MVP

### 4.1 Landing/apply page fechada

**Objetivo:** apresentar a proposta e capturar aplicação.

**Requisitos:**

- Página visualmente premium.
- `noindex`.
- CTA: `Request Access` ou `Apply for Access`.
- Copy sem promessa de previsão/IA mágica.
- Formulário curto.
- Sem cadastro público aberto direto para produto.

**Campos do formulário:**

- Nome artístico/produtor.
- Email.
- Link do YouTube.
- Link de portfólio/BeatStars opcional.
- Nicho principal.
- Pergunta: “Como você decide para quais artistas produzir hoje?”
- Pergunta: “Você produziria para um artista sugerido por sinais de mercado?”

---

### 4.2 Aprovação manual

**Objetivo:** garantir que o feedback venha de produtores que informam a hipótese.

**Estados da aplicação:**

- `submitted`
- `under_review`
- `approved`
- `rejected`
- `invited_to_report`

**Critério de aprovação:**
Produtor ativo, real, com sinais públicos de produção.

---

### 4.3 Acesso autenticado ao relatório

**Objetivo:** entregar a experiência fechada do Hotspot.

**Requisitos:**

- Login por email magic link ou senha simples.
- Acesso permitido apenas para aprovados.
- Registro de abertura do relatório.
- Registro de cliques nos exemplos do YouTube.
- Registro de feedback por artista.

---

### 4.4 Relatórios

O MVP terá dois snapshots fixos:

- **Relatório 1 de 2**
- **Relatório 2 de 2**

Cada relatório terá:

- 10 artistas;
- 2 artistas `HOT`;
- tabela com colunas públicas definidas;
- exemplo clicável no YouTube;
- feedback por linha.

### Copy do botão
Usar:

> Ver outro grupo de oportunidades

Não usar:

- Re-Gen;
- Generate again;
- AI retry;
- New AI analysis;
- qualquer copy que implique processamento em tempo real.

---

## 5. Colunas públicas da tabela

### 5.1 Title

**Formato:** `Nome do Artista Type Beat`  
**Exemplo:** `Kairo Vee Type Beat`

**Propósito:** usar a linguagem que o produtor já entende e já usa no YouTube.

---

### 5.2 Tag

**Formato:** `HOT`, exibida apenas quando aplicável.

**Critério:** `Score > 90`.

**Propósito:** criar hierarquia visual e apontar oportunidades urgentes.

---

### 5.3 Score

**Formato:** `X/100`, exibido apenas para artistas com `Score > 83`.

**Tooltip público:**

> O score mede performance recente de vídeos publicados dentro da janela analisada, não crescimento histórico completo do artista.

**Propósito:** sintetizar tração recente em um número simples.

---

### 5.4 Signals

**Formato:** número inteiro.

**Definição:** quantidade de vídeos válidos encontrados para o artista dentro da janela de 30 dias.

**Vídeo válido:** vídeo cujo canal passou pelo filtro de elegibilidade.

**Propósito:** mostrar volume de sinal sem criar uma tabela complexa.

---

### 5.5 Velocity

**Formato:** `X.Xk/day` ou `XXX/day`.

**Definição:** mediana de views por dia dos vídeos válidos do artista dentro da janela.

**Por que mediana:** reduz distorção por um vídeo viral isolado.

---

### 5.6 Competition

**Formato:** `Low`, `Medium` ou `High`.

**Definição:** mede quantos canais distintos estão publicando type beats para aquele artista.

| Nível | Critério MVP |
|---|---|
| Low | até 5 canais distintos na janela de 30 dias |
| Medium | 6 a 15 canais distintos |
| High | mais de 15 canais distintos ou crescimento de publicações nos últimos 7 dias acima de 50% vs 7 dias anteriores |

**Propósito:** mostrar se a oportunidade ainda não está saturada por muitos produtores.

---

### 5.7 Example / Reference

**Formato:** ícone do YouTube clicável.

**Definição:** vídeo-prova do artista selecionado por regra determinística.

**Regra de seleção:**

1. Filtrar vídeos do artista que passaram pelo Channel Filter.
2. Ordenar por velocity, maior para menor.
3. Entre os 3 maiores, escolher o publicado mais recentemente.
4. Em empate de data, escolher o de maior views absoluto.

**Propósito:** provar que a linha vem de sinal real, não de lista inventada.

---

## 6. Ações do produtor no relatório

Cada linha terá ações simples:

1. `Útil`
2. `Não útil`
3. `Vou produzir para esse artista`

### Evento mais importante
`Vou produzir para esse artista` é a métrica norte do MVP.

---

## 7. Follow-up obrigatório

### Quando
10 a 14 dias após o produtor marcar `Vou produzir para esse artista`.

### Perguntas
- Você chegou a produzir o beat?
- Publicou?
- Pode enviar o link?
- O relatório influenciou sua decisão?
- Você pagaria por um relatório como esse atualizado semanalmente?

### Por que é obrigatório
Sem follow-up, o MVP mede curiosidade. Com follow-up, mede mudança real de comportamento.

---

## 8. Métricas de sucesso

### North Star

| Métrica | Definição | Meta mínima |
|---|---|---:|
| Taxa de intenção declarada | % de produtores validados que marcam `vou produzir` para ao menos 1 artista | ≥ 30% |

### Métricas secundárias

| Métrica | Definição | Meta mínima |
|---|---|---:|
| Confirmação em follow-up | % dos que declararam intenção e confirmam produção real | ≥ 50% |
| WTP | % que responde “sim” à disposição a pagar | ≥ 25% |
| Utilidade dos HOT | % dos artistas HOT marcados como úteis | ≥ 60% |
| Open rate dos aprovados | % dos aprovados que abrem o relatório | ≥ 70% |

### Amostra mínima

- Lista inicial: 100 produtores.
- Convites enviados na primeira onda: 40–60.
- Aplicações aprovadas: 20–30.
- Resultado conclusivo: pelo menos 15 produtores validados engajados.

Se `N < 15`, tratar como sinal direcional, não conclusão.

---

## 9. Fora de escopo do MVP

Explicitamente fora:

- marketplace;
- checkout;
- pagamentos;
- Stripe;
- upload de beats;
- download de arquivos;
- contratos/licenças;
- split automático;
- sub-perfis/beatmaker names em produção;
- múltiplos nichos;
- múltiplas keywords;
- query sob demanda;
- relatório gerado em tempo real;
- análise histórica além de 30 dias;
- modelo ML de scoring;
- data lake diário;
- exposure penalty;
- insight textual gerado por IA sobre artistas;
- landing pública indexável;
- tráfego pago massivo.

---

## 10. Critério de avanço para Fase 2

Avançar para automação parcial e possível monetização somente se:

- N ≥ 15 produtores validados engajados;
- intenção declarada ≥ 30%;
- confirmação real ≥ 50%;
- WTP positivo ≥ 25%;
- nenhum problema grave de credibilidade metodológica for identificado.

---

## 11. Fase 2 prevista, mas não construída agora

- Pipeline de agentes totalmente orquestrado.
- Query real sob demanda com limite de 1/dia.
- Novos subgêneros.
- Reports semanais.
- Cobrança ou plano beta pago.
- Exposure management.
- Começo da camada de sub-perfis de produtores.
- Teste de marketplace curado.

