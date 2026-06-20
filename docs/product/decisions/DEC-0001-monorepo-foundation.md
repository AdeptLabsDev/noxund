## DEC-0001 — Fundação em monorepo + tooling

- **Data:** 2026-06-19
- **Status:** Proposta (aguarda confirmação do Product Lead)
- **Decisor:** Product Orchestrator (propõe) → Product Lead (confirma)
- **Área:** Stack / Tooling
- **Prioridade/Impacto:** Médio

### Contexto
A Sprint 0 pede a fundação técnica mínima do repositório em monorepo, sem construir features. Os frameworks já estão travados em `/context` (`02_Stack_Infra_Architecture.md`): Next.js + TS, Supabase, Python. O que faltava decidir é a **organização do monorepo** e a **tooling** (gerenciador de pacotes, layout), além de fixar o local do decision log (OD-06).

### Decisão
1. Monorepo com layout `apps/`, `packages/`, `services/`, `supabase/`, `docs/`, `context/`.
2. Gerenciador de pacotes **pnpm** (workspaces para `apps/*` e `packages/*`); `services/data-engine` é Python e fica fora dos workspaces JS.
3. Node 20 (`.nvmrc`), `tsconfig.base.json` compartilhado.
4. Decision log vive em **`docs/product/decisions/<id>.md`** (um arquivo por decisão) — **resolve OD-06**.

### Alternativas consideradas
- **npm/yarn workspaces** — funcionam, mas pnpm é mais eficiente e padrão em monorepos Next.js. (não)
- **Turborepo/Nx** — orquestração extra desnecessária para o tamanho do MVP. (não agora)
- **`DECISIONS.md` único apendado** — simples, mas pior para diffs/rastreio por decisão. (não)

### Justificativa
Mantém a fundação leve, alinhada à stack travada, sem antecipar complexidade (sem Turbo/Nx, sem Redis/Celery). Um arquivo por decisão dá rastreabilidade limpa.

### Impacto
- **Escopo:** nenhum (não toca produto).
- **Non-negotiables:** preservados (sem deps instaladas, sem features, sem secrets).
- **Documentos a atualizar:** `scope-guardrails.md` (fechar OD-06), `monorepo-structure.md`, README raiz.
- **Tarefas afetadas:** `[PRODOPS] Definir local e processo do decision log`.

### Reversibilidade
Alta — trocar pnpm→npm ou layout é barato enquanto não há código de produto.

### Revisões necessárias
- [x] Product Orchestrator  [ ] Product Lead (confirmar)  [ ] DevOps (ao `git init`/CI)

### Follow-up
Confirmar com o Product Lead. Após confirmado, mudar status para Aprovada e o DevOps Agent inicializa git + branch protection.
