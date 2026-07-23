# DEC-0024 · Adendo de rastreabilidade — Política de ordenação de migrations (SG-8 `0008` vs. Phase 6 `0007` PARKED)

- **Data:** 2026-07-24
- **Status:** **Registrado.** Política de ordenação decidida pelo Product Lead. Aditivo a `DEC-0024` (não altera a decisão nem os artefatos SQL do commit `47402c9`). **Não** amplia escopo para Phase 6.
- **Decisor:** Product Lead · registrado pelo Product Orchestrator
- **Escopo:** numeração/ordenação de migrations em `main`. **Não** autoriza merge, apply, promoção de Phase 6, nem qualquer alteração da branch `wip/phase6-producer-events-preservation`.
- **Relaciona:** `DEC-0024-sg8-reconciliation-session-schema.md` · `supabase/migrations/20260620000008_sg8_reconciliation_session.sql` (header §ORDENAÇÃO) · `docs/database/migration-plan.md` (Fase 6) · nota de memória `phase6-producer-events-wip-preservation` · `DEC-0014` (disciplina de landing 0006, preflight fail-closed anti-0007)

---

## Contexto

O commit `47402c9` (PR #57) introduz a migration SG-8 com o identificador `20260620000008`. A Phase 6 (`producer_events`) foi autorada como `20260620000007`, mas **nunca entrou em `main`**: está preservada, como WIP, na branch `wip/phase6-producer-events-preservation` (commit `a1ec483`), pendente de revisão Database + Data Integrity antes de qualquer uso. O header da migration SG-8 e o `DEC-0024` descrevem a escolha do `0008` como forma de "evitar a `0007` PARKED". Esse fraseado pode ser lido como se o slot `0007` estivesse **reservado** para a Phase 6 — o que **não** é a política. Este adendo fixa a semântica de numeração para eliminar ambiguidade.

## Política registrada (Product Lead)

1. **A migration SG-8 permanece `20260620000008`.** É o identificador canônico e definitivo desta unidade em `main`.

2. **A sequência canônica de `main` é `0001…0006` + `0008`.** O identificador `0007` é um **vão intencional** (hole), **não** uma reserva. A migration Phase 6 `0007`, por viver apenas na branch WIP, **não faz parte** da sequência canônica de `main` e **não reserva** o identificador `0007`.

3. **Se a Phase 6 for futuramente promovida a `main`,** deverá ser **re-revisada** (Database + Data Integrity, no mínimo) e **renumerada para o próximo timestamp livre** posterior às migrations então presentes em `main` — não há garantia de que retome o `0007`. A promoção é uma decisão futura própria, fora deste PR.

4. **Não alterar agora** a branch WIP nem os bytes preservados da migration Phase 6. A preservação byte-exata (nota `phase6-producer-events-wip-preservation`) permanece intacta.

5. **Sem ampliação de escopo.** Este adendo apenas registra a política de ordenação/numeração. Não move, não promove, não revisa e não renumera a Phase 6 agora; não toca `producer_events`.

## Consequências operacionais

- O "vão" `0007` em `main` é **esperado e permanente** enquanto a Phase 6 não for promovida+renumerada. Ferramentas de verificação de contiguidade de migrations **não** devem tratar a ausência de `0007` como erro.
- O preflight fail-closed herdado de `DEC-0014` (que aborta o apply se qualquer migration mais nova que o alvo declarado aparecer, incluindo `0007`) permanece a salvaguarda correta: nenhum apply "cego" de `db push` pode aplicar a Phase 6 por engano.
- Este adendo **não** revoga nenhuma barreira: PR #57 segue **NO-GO** para merge/apply até concluir as cinco revisões obrigatórias **e** a validação executável local descartável.
