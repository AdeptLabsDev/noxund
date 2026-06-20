# packages/shared — Tipos e contratos compartilhados

**Status:** placeholder. Não scaffoldado ainda.
**Stack pretendida:** TypeScript puro (sem runtime pesado).
**Owner agents:** Backend Agent, Frontend Agent (com Database/Data-AI para tipos de dados).

## O que viverá aqui (quando construído)

- Tipos compartilhados entre `apps/web` e futuras libs (ex.: shape de `report_item`, enums de `event_type`).
- Schemas de validação (ex.: Zod) reutilizáveis entre front e API.
- Constantes do domínio (ex.: thresholds públicos: HOT > 90, Score exibido > 83) — **somente exibição**, nunca o rubric/fórmula.

## Restrições

- **Não** colocar aqui lógica de cálculo de Score/metodologia (vive no data engine, determinístico).
- `tsconfig.json` estende `../../tsconfig.base.json`.
- Sem dependências de framework (Next/React) — mantém-se agnóstico.
