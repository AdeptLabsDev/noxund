## DEC-0002 — Tailwind v4 + sistema de design monocromático

- **Data:** 2026-06-20
- **Status:** Aprovada (Product Lead, via decisão de design do Frontend contract)
- **Decisor:** Product Lead (direção) → Product Orchestrator (execução)
- **Área:** Stack / Design System
- **Prioridade/Impacto:** Médio

### Contexto
`docs/agents/frontend-agent.md` foi atualizado para um sistema de design **normativo**, inspirado na *disciplina de engenharia visual* da Vercel/Next.js (não no tom): monocromático puro (saturação 0%, **sem acento de cor**), dark-first, profundidade por alpha-sobre-void, curva óptica de tracking, números mono + `tnum`, técnicas zero-asset (scrim, grid via gradiente+máscara). A spec exige implementação via **Tailwind v4 `@theme`** em `globals.css`. A fundação (`apps/web`) estava em **Tailwind v3**, o que conflitava com a spec e com a regra de `scope-guardrails.md` ("trocar Tailwind exige Product Orchestrator").

### Decisão
1. Adotar **Tailwind v4** em `apps/web` (CSS-first, `@theme`).
2. Semear o token system base em `globals.css`: rampa de luminância `surface-100..800` + `void`/`muted`/`primary`; overlays `alpha-100..900`; fontes sans/mono; easings decididos. Aliases literais (`--bg-void`, `--alpha-200`, …) mantidos para os snippets do contrato.
3. Substituir o placeholder por uma base monocromática on-system (sem feature de produto).
4. Confirmar a direção visual oficial: **monocromático, sem acento, "dossiê de cena"**.

### Alternativas consideradas
- **Manter v3, adiar para Sprint 1** — evitaria mexer na fundação, mas deixaria contrato e código divergentes e a regra de guardrail em aberto. (não)
- **Só documentar** — não resolveria a divergência técnica. (não)

### Justificativa
A spec é normativa e exige v4 (`@theme`, `bg-linear-to-t`, `@container`, `mask-image`). Alinhar a fundação agora mantém contrato e código coerentes e o build verde, sem antecipar UI de produto. O token system é explicitamente listado em **Owns** do Frontend Agent.

### Impacto
- **apps/web:** `tailwindcss ^3 → ^4`; `+@tailwindcss/postcss`; `−autoprefixer`; `postcss.config` → plugin v4; `tailwind.config.ts` removido (CSS-first); `globals.css` → `@import "tailwindcss"` + `@theme`; `page.tsx` → base monocromática.
- **Validação:** `pnpm install` ✅ · `pnpm --filter web lint` ✅ · `pnpm --filter web build` ✅ (4 rotas estáticas).
- **Documentos atualizados:** `scope-guardrails.md`, `README.md`, `docs/foundation/monorepo-structure.md`.
- **Non-negotiables:** preservados (sem feature, sem secret, sem lib de animação).

### Reversibilidade
Média — reverter para v3 é possível enquanto não há UI real, mas o token system já assume v4.

### Revisões necessárias
- [x] Product Lead (direção de design)  [x] Product Orchestrator  [ ] QA (na 1ª UI real: `tnum`, focus ring, reduced-motion)

### Follow-up
Frontend Agent, na Sprint 1: aplicar o token system na tabela do relatório (mono + `tnum`), implementar scrim/grid técnicos e o signature element (selo de autenticação).
