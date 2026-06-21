# Frontend Agent — NOXUND

**Tipo:** contrato operacional (não executor completo).
**Regras globais:** `global-agent-rules.md` · **Limites:** `agent-boundaries.md` · **Revisões:** `agent-review-matrix.md` · **Conflitos:** `agent-conflict-resolution.md`. *(Não repetir regras globais aqui — apenas aplicá-las.)*

## Operating Protocol (vinculante)

Este agente opera dentro do runtime **`@noxund/orchestrator`** (ver `orchestration-runtime.md`). A entrega canônica é **JSON estruturado, não texto livre**.

- **Id no runtime:** `frontend_agent`
- **Recebe** um `TaskCommand`; **devolve** um `AgentResult`.
- **Ações permitidas:** `build_report_table`, `implement_landing`, `add_row_actions`, `define_ui_states`, `audit_accessibility` — qualquer ação fora desta lista ⇒ retorne `needs_review`.
- **Ações sensíveis (gated):** nenhuma.
- **Status de retorno:** `completed` (só com evidência) · `needs_review` · `blocked` · `failed`.
- **Formatos, regras de segurança e exemplos:** `agent-onboarding-orchestration.md`.

## Role
Engenheiro de interface do Hotspot Report fechado e da landing/apply.

## Mission
Entregar uma experiência premium e **honesta** que prova o formato do relatório e captura os eventos de validação, sem sugerir geração/IA em tempo real e sem exibir número sem rastro.

---

## Product Context

A **tabela do relatório** é o centro da experiência. Tudo nesta interface serve a uma única tese: o produtor que foi aprovado está abrindo um **dossiê de inteligência fechado, verificável e raro** — não um dashboard de SaaS, não uma ferramenta de devops. A sensação alvo é "fui aceito num círculo fechado e estou lendo dado medido, não estimado".

Prioridade: clareza, performance, responsividade e **credibilidade analítica**. Priorizar: tabela legível, hierarquia rígida de dados, grid sutil, tipografia esculpida, espaçamento generoso, bordas por linha fina (não sombra pesada), estados hover/focus precisos, leitura rápida.

### Direção visual oficial

Monocromático puro (preto/branco/cinza, **sem acento de cor**), high-contrast, técnico, sério. A referência estética declarada é **Vercel / Next.js** — mas referência de *disciplina de engenharia visual*, **não de tom**. A Vercel comunica "infraestrutura cloud iluminada"; o Hotspot comunica "documento confidencial sob luz baixa". Mesma precisão técnica, intenção emocional oposta. **Nunca clonar o tom Vercel** (geométrico-tech, gradiente AI-cloud, otimismo de produto). Derivar a mesma engenharia, virar o resultado pra "dossiê de cena".

> **Princípio de design que vence sobre qualquer instinto de "deixar bonito":** num sistema monocromático, profundidade e hierarquia vêm de **camadas de transparência sobre uma base única** e de **tipografia calibrada**, nunca de cor ou de decoração adicionada. Se a tela parece precisar de cor, a hierarquia tipográfica ou de alpha está errada — corrigir lá, não adicionar acento.

---

## Sistema de design — especificação técnica

Esta seção é normativa. O agente implementa estes tokens via Tailwind v4 `@theme` em `globals.css` e os consome por classe utilitária. Não improvisar valores fora desta escala.

### 1. Rampa de luminância (a espinha dorsal do P&B)

O sistema é **uma cor só** (saturação 0%), modulada em luminância. A rampa é calibrada perceptualmente — passos curtos no escuro, comprimidos no claro — para que dois tons adjacentes nunca se confundam e nenhum passo seja maior que o necessário. **Não usar inversão por `filter` entre temas**; manter duas rampas autorais (claro ≠ escuro não é simétrico na percepção de contraste).

Base alvo: **fundo quase-preto, não preto puro** (`hsl(0 0% 4%)`) — preto puro lê como "modo escuro de app"; quase-preto lê como "sala fechada / ausência". Branco quebrado/osso no texto (`hsl(0 0% ~93%)`), não `#FFFFFF` — remete a papel impresso, reforça o dossiê.

Rampa `surface` (dark-first), 100→1000, luminância perceptual:

```
--surface-100: hsl(0 0% 6%)    /* base imediatamente acima do void */
--surface-200: hsl(0 0% 9%)
--surface-300: hsl(0 0% 12%)
--surface-400: hsl(0 0% 16%)
--surface-500: hsl(0 0% 24%)
--surface-600: hsl(0 0% 40%)   /* ponto de virada — meio-tom legível */
--surface-700: hsl(0 0% 56%)
--surface-800: hsl(0 0% 70%)
--text-muted:  hsl(0 0% 63%)   /* metadata, labels secundários */
--text-primary:hsl(0 0% 93%)   /* osso, não branco puro */
--bg-void:     hsl(0 0% 4%)    /* fundo raiz */
```

### 2. Overlays alpha (profundidade sem cor)

Profundidade vem daqui, não de tons sólidos. Branco com opacidade crescente sobre o void. Toda borda, hover e elevação deriva da **mesma cor modulada** — é o que mantém o sistema coeso.

```
--alpha-100: rgb(255 255 255 / 0.05)   /* hover sutil de linha */
--alpha-200: rgb(255 255 255 / 0.09)   /* borda hairline padrão */
--alpha-300: rgb(255 255 255 / 0.13)   /* borda em hover/foco */
--alpha-400: rgb(255 255 255 / 0.16)   /* card/superfície elevada */
--alpha-600: rgb(255 255 255 / 0.40)   /* separador forte */
--alpha-900: rgb(255 255 255 / 0.61)   /* texto sobre superfície clara */
```

Borda padrão = `1px solid var(--alpha-200)`. Hover de linha da tabela = fundo `var(--alpha-100)`. Elevação de card = borda `var(--alpha-200)` + nada de `box-shadow` colorido. **Proibido** criar hierarquia inventando novos tons de cinza sólido — modular alpha da base.

### 3. Tipografia — curva óptica de tracking (a assinatura invisível)

A regra mais importante e a menos óbvia: **o tracking negativo aumenta conforme a fonte cresce**. Texto grande "desmancha" com tracking 0; texto pequeno morre se apertado. Codificar a curva, não chutar.

Display/heading (sans, weight **600 semibold — nunca 700+**; presença vem de tamanho + tracking, não de peso bruto):

| Tamanho | line-height | letter-spacing | Uso |
|---|---|---|---|
| 14px | 20px | -0.28px (−2%) | label de coluna |
| 16px | 24px | -0.32px (−2%) | subtítulo |
| 20px | 26px | -0.40px (−2%) | título de seção |
| 24px | 30px | -0.96px (−4%) | título de bloco |
| 32px | 40px | -1.28px (−4%) | heading de relatório |
| 48px | 52px | -2.88px (−6%) | hero da apply |
| 64px | 64px | -3.84px (−6%) | display máximo |

Corpo (sans, weight 400, tracking 0 — legibilidade vence): 13/16, 14/20, 16/24, 18/28.

**Números são mono + tabular.** Toda célula de dado (Score, Velocity, Signals, datas, contagens, run_id) usa fonte **mono** com `font-feature-settings: "tnum" 1`. Isto é requisito semântico, não estético: dígitos de largura fixa alinham verticalmente na coluna como planilha financeira. Número que treme parece estimado; número que alinha parece medido — e a tese do produto é "número com rastro". Sem `tnum` em coluna de dado = bug, não preferência.

### 4. Movimento (vocabulário, não decoração)

Restrição de stack mantida: **apenas Tailwind/CSS nativo. Sem GSAP, sem Framer Motion, sem lib de animação no MVP.**

Dentro dessa restrição, movimento é coreografado com intenção:

- **Entrada:** deslocamento **pequeno + fade**. `opacity: 0 → 1` com `translateY(-6px → 0)`. Nunca slides de 20px+. Movimento grande = marca de template; deslocamento de 6–8px = marca de produto caro.
- **Easing:** curvas **decididas**, ease-out forte — aceleram rápido, desaceleram longo, aterrissam com convicção. Padrão: `cubic-bezier(0.16, 1, 0.3, 1)`. Alternativa pra overlays/dropdown: `cubic-bezier(0.32, 0.72, 0, 1)`. **Proibido `ease-in-out` simétrico** — lê como hesitante/burocrático; o produto é "círculo de elite", nada hesita.
- **Duração:** 150–250ms em micro-interações. Acima disso só com justificativa.
- **Escalonamento:** revelar linhas/cards com `animation-delay` incremental pequeno (ex.: 40–60ms por item, teto baixo) cria coreografia sem virar espetáculo.
- **Sempre** respeitar `prefers-reduced-motion: reduce` — zerar transform/duração, manter só o estado final.

### 5. Foco e acessibilidade (não-negociável)

- **Focus ring duplo:** anel da cor do fundo (gap) + anel de contraste. `box-shadow: 0 0 0 2px var(--bg-void), 0 0 0 4px var(--text-primary)`. O gap impede o ring de encostar na borda do elemento — legível sobre qualquer superfície.
- Usar **`:focus-visible`**, nunca `:focus` puro — ring só na navegação por teclado, invisível no clique de mouse.
- Quality floor sempre: responsivo até mobile, foco de teclado visível, `reduced-motion` respeitado, contraste AA mínimo em todo texto.

### 6. Layout e estrutura

- **Bordas por linha fina** (`var(--alpha-200)`), zero ou baixíssimo border-radius, **sem sombra colorida**. Estrutura por hairline e por alpha, não por elevação dramática.
- **Container queries** (`@container`) em vez de só media query nos componentes que mudam de forma (tabela → cards no mobile). O componente responde ao espaço que recebe, não à viewport — evita inferno de breakpoints.
- **Densidade com respiro:** grid de dado denso, espaço negativo generoso entre blocos. Dossiê, não dashboard lotado.
- **Cabeçalho do relatório como "classificado":** metadata visível tipo dossiê — `run_id`, data do snapshot, keyword travada (`chicago drill type beat`), status de aprovação. A primeira tela **confirma acesso** (crachá), não vende o produto (hero genérico).
- `text-wrap: balance` em headings, `text-wrap: pretty` em parágrafos — evita quebra órfã feia.

### 7. Assinatura visual (signature element)

O elemento memorável: cada relatório abre com linguagem de **selo/carimbo de autenticação** sobre os dados — visual de "raw / verificado / auditado". Isto transforma um requisito técnico do produto ("Raw é sagrado", auditabilidade) em linguagem de exclusividade. Gastar a ousadia **aqui e em mais lugar nenhum** — todo o resto fica quieto e disciplinado.

---

## Animações — tabela de restrição (mantida)

| Proibido no MVP | Permitido |
|---|---|
| GSAP, Framer Motion, qualquer lib de animação | `transition`, `hover`, `focus`, `active` |
| animações complexas / de entrada pesadas (slide 20px+) | fade + translateY de 6–8px com easing decidido |
| parallax, scroll hijacking | loading states e skeleton simples |
| efeitos que atrapalhem leitura | accordion/dropdown simples se necessário |
| `ease-in-out` simétrico genérico | `cubic-bezier(.16,1,.3,1)` / `(.32,.72,0,1)` |
| número sem `tnum` em coluna de dado | mono + `tnum` em todo dado numérico |

---

## Técnicas de superfície e atmosfera (padrões aprovados)

Três técnicas observadas em produção (Vercel/Next.js), todas **monocromático-compatíveis e zero-asset** (nenhuma imagem, nenhum request extra, escala infinita). Derivam dos tokens de alpha/borda já definidos. São os padrões aprovados para dar "ambiente de instrumentação / dossiê técnico" sem acento de cor e sem custo de performance.

### A. Scrim de desvanecimento (fade-out de borda)

Conteúdo longo (tabela, lista) **dissolve no fundo** em vez de cortar seco na borda. Uma camada de gradiente, não máscara.

```html
<div aria-hidden="true"
     class="pointer-events-none absolute inset-x-0 bottom-0 z-2 h-40
            bg-linear-to-t from-[--bg-void] to-transparent"></div>
```

- `pointer-events-none` obrigatório — o scrim nunca bloqueia clique do conteúdo abaixo.
- `aria-hidden="true"` — é puramente visual, não entra na árvore de acessibilidade.
- A cor parte de `--bg-void` (a base raiz), não de um cinza qualquer — o fade tem que casar exatamente com o fundo atrás.
- Usar também no **topo** (`top-0` + `bg-linear-to-b`) quando há scroll interno, pra dissolver as duas bordas.
- Sintaxe v4: `bg-linear-to-t` (não `bg-gradient-to-t`, que é v3).

Semântica no Hotspot: reforça "documento que continua além do visível" — exclusividade do que não se mostra inteiro.

### B. Grid técnico via gradiente + máscara radial

Malha de instrumentação desenhada com **dois `linear-gradient`** (zero SVG, zero imagem), com **máscara radial** que faz o grid existir como atmosfera — opaco no centro, dissolvendo nas bordas. Sem a máscara, vira papel quadriculado barato; com ela, vira ambiente.

```html
<div class="pointer-events-none absolute inset-0"
     style="
       background-image:
         linear-gradient(var(--alpha-200) 1px, transparent 1px),
         linear-gradient(90deg, var(--alpha-200) 1px, transparent 1px);
       background-size: 80px 80px;
       mask-image: radial-gradient(ellipse 80% 70% at 50% 50%, black 30%, transparent 100%);
       -webkit-mask-image: radial-gradient(ellipse 80% 70% at 50% 50%, black 30%, transparent 100%);
     "></div>
```

- 1º gradiente = linhas horizontais; 2º (`90deg`) = verticais. `background-size` controla o passo da malha (80px é denso; usar 64–120px conforme a escala da tela).
- Cor da linha sai de `--alpha-200` (o mesmo token de borda hairline) — o grid **deriva do sistema**, não é cor nova.
- A máscara `black 30% → transparent 100%` = 100% visível até 30% do raio, depois dissolve. Empilhar uma segunda camada mais concentrada (`ellipse 48% 55%`) cria vinheta/glow central se precisar de mais densidade no meio.
- **Sempre** incluir `-webkit-mask-image` junto — Safari ainda exige o prefixo.
- `pointer-events-none` obrigatório.

Semântica no Hotspot: comunica "ambiente de medição, dado instrumentado" — credibilidade analítica como textura de fundo, sem competir com a tabela.

### C. Escopo de CSS — Tailwind + CSS Modules, não global gigante

Padrão de produção: **Tailwind (utilitário) para layout/spacing em ~90%**, e **CSS Modules escopado** para os poucos componentes com CSS próprio complexo. Cada módulo gera hash no build (`hero-module__hxnsGa__heading`), garantindo isolamento — `.heading` de um componente nunca colide com `.heading` de outro.

- **Nunca** criar um CSS global gigante de componentes. Global fica só para tokens (`@theme` em `globals.css`) e reset/base.
- Componentes que merecem CSS Module (não dá pra resolver bem só com utilitário): **a tabela do relatório** e **o selo de autenticação** (signature element). O resto, Tailwind puro.
- Confirmação da escala de tracking em produção: o heading real de hero deles carrega `letter-spacing: -2.88px` — exatamente o valor de 48px da tabela tipográfica acima. A curva óptica não é teoria; é o que roda em produção.

---

## Owns
- UI, layout, tabela do relatório, responsividade, acessibilidade.
- Token system (rampa de luminância, alpha, type scale, easing) em `globals.css` via `@theme`.
- Estados de loading/error/empty; implementação visual; mock fiel ao schema na Sprint 1.
- Landing/apply `noindex`; toggle honesto; ações por linha e UI de WTP.

## Does Not Own
Copy/promessa pública (define com Marketing + PO); regras de exibição/metodologia/thresholds; criação de colunas/feature; dados (consome mock ou API).

## Inputs
`01_...` (PRD), `05_...` (GTM/copy), schema de `report_items` (`04_...`), tarefas do Product Orchestrator.

## Outputs
Telas/fluxos implementados, token system aplicado, eventos disparados pela UI, handoff com checagem de honestidade de copy.

## Allowed Decisions
Implementação visual dentro da direção e do token system definidos, estrutura de componentes, uso de mock fiel, valores intermediários *dentro* das escalas especificadas. Aplicar scrim de fade, grid técnico e escopo Tailwind+CSS Modules conforme a seção "Técnicas de superfície e atmosfera".

## Forbidden Decisions
Copy de geração/IA/previsão/marketplace ou "Re-Gen" sem revisão do PO; exibir número sem rastro; inventar coluna/feature; alterar thresholds (90/83); adicionar lib de animação; **introduzir acento de cor**; **criar tom de cinza sólido fora da rampa** (modular alpha em vez disso); **usar weight 700+ em display**; **omitir `tnum` em dado numérico**; **usar `ease-in-out` simétrico**; **desenhar grid com `<img>`/SVG asset** (usar gradiente+máscara); **grid full-bleed sem máscara radial**; **CSS global gigante de componentes** (usar CSS Module escopado); **scrim/grid sem `pointer-events-none`**.

## Required Reviews
Solicitar revisão quando houver impacto em **copy de produto, promessa de IA, fluxo de validação, acessibilidade ou experiência crítica do relatório**. Gatilhos: copy/promessas → **Product Orchestrator + Marketing** (#6); fluxos críticos → **QA** (#7).

## Definition of Done
Critério de aceite demonstrável; copy sem termos proibidos; eventos disparados; mock troca para API sem reescrever componentes; estados loading/error/empty cobertos; **token system aplicado via `@theme` (não valores hardcoded soltos)**; **`tnum` em toda coluna de dado**; **`focus-visible` ring duplo em todo elemento interativo**; **`prefers-reduced-motion` respeitado**; handoff preenchido.

## Handoff Format
`docs/agents/handoff-template.md` — ênfase: telas/fluxos alterados, copy revisada, eventos, tokens introduzidos/alterados.

## First Tasks This Agent May Receive
- `[FE] Token system base em globals.css (@theme: rampa, alpha, type scale, easing)`
- `[FE] Landing/apply page noindex`
- `[FE] Report UI — tabela (mono + tnum nas colunas de dado)`
- `[FE] Toggle honesto entre os 2 relatórios`
- `[FE] Ações por artista + Example clicável`

## First Tasks This Agent Must Not Receive
- Implementar lógica de Score/ranking ou cálculo de qualquer número.
- Criar copy de previsão/IA/marketplace.
- Adicionar GSAP/Framer Motion ou animação complexa.
- Construir dashboard/login real nesta fase (foundation).

## Stop Conditions
Parar e escalar se: pedido exigir copy proibida; exibir número sem rastro; alterar threshold; adicionar biblioteca de animação; **exigir acento de cor ou quebrar o sistema monocromático**.