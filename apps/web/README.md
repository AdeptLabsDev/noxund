# apps/web — NOXUND Frontend + Core API

**Status:** placeholder. Não scaffoldado ainda (sem dependências instaladas).
**Stack pretendida:** Next.js + TypeScript + Tailwind (front + core API via Route Handlers/Server Actions).
**Owner agents:** Frontend Agent, Backend Agent.

## O que viverá aqui (quando construído)

- Landing/apply page `noindex` (Frontend).
- Report UI fechada: tabela, toggle honesto, ações por linha, WTP (Frontend).
- API surface: `/apply`, feedback/intent/wtp, admin, internal jobs (Backend).
- Auth + approval gate via Supabase Auth (Backend + Security).

## Como será scaffoldado (futuro, com revisão)

> Não rodar agora. Isto documenta o caminho; a criação é tarefa do Frontend/Backend Agent com revisão.

```bash
# a partir da raiz do monorepo
pnpm create next-app@latest apps/web --ts --eslint --app --tailwind --src-dir --import-alias "@/*"
```

## Restrições (ver docs/agents/)

- Nenhuma copy de geração/IA em tempo real.
- Nenhum número exibido sem rastro até `raw_youtube_videos`.
- `tsconfig.json` deve estender `../../tsconfig.base.json`.
- Variáveis públicas só via `NEXT_PUBLIC_*`; secrets ficam server-side.
