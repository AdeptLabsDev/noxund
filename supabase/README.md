# supabase — Database & Auth (RETIRED — historical artifacts)

> **RETAINED HISTORICAL / LEGACY DATABASE ARTIFACTS.** The Supabase project this directory targeted no longer exists — it was **permanently retired** (see [`DEC-0034`](../docs/product/decisions/DEC-0034-legacy-supabase-dataset-retirement-and-p9-p8-resequencing.md) and [`SUPABASE-LEGACY-STRUCTURAL-BRIEF-R0`](../docs/database/SUPABASE-LEGACY-STRUCTURAL-BRIEF-R0.md)). Nothing in this directory means Supabase remains the active platform. `migrations/` 0001–0006 are **historical applied schema evidence** (were live in production, now unreachable). 0008/0009 are **design-only and were never applied**. No production PostgreSQL successor is deployed yet.

**Status:** historical / retired. Not an active development target.
**Owner agents:** Database Agent, Security & Privacy Agent.

## O que viverá aqui (quando construído)

- `migrations/` — migrations versionadas do schema do MVP (`04_Database_Event_Model.md`). O CLI aplica **todo** `.sql` daqui como forward migration, em ordem de timestamp.
- `rollback/` — down-scripts companheiros (1:1 com cada migration). **Fora de `migrations/` de propósito**, para o CLI não aplicá-los como forward. Rodar manualmente para reverter.
- Políticas RLS e roles.
- Seeds de desenvolvimento (dados fake, nunca dados reais de produtor).

### Autorado, não aplicado

- **Fase 1 (Core Identity / Access):** `migrations/20260620000001_phase1_core_identity_access.sql` + `rollback/20260620000001_phase1_core_identity_access.rollback.sql`. Tabelas `producers`, `applications`, `admin_users`, `audit_events` (antecipada — SEC-0002 §3). **DDL autorado; apply gated.** Re-review do Security sobre o SQL é pré-condição do `run_migration` (ver `docs/database/HANDOFF-phase1-ddl.md`).

## Princípios (ver docs/agents/database-agent.md)

- **Raw imutável** — tabelas raw nunca recebem update.
- **Computed reconstruível** — métricas/score/rows recalculáveis a partir do raw.
- **Report snapshot congelado** — não muda após publicado.
- **Sem tabelas de marketplace/Fase 2** (`04_...` §12): `beats`, `orders`, `payouts`, `licenses`, etc.
- Toda migration passa por **Database + Security review** (`agent-review-matrix.md` #3).

## Como será inicializado (futuro, com revisão)

> Não rodar agora. **Historicamente inaplicável agora:** o projeto Supabase alvo foi retirado permanentemente; estas instruções referem-se a um projeto que não existe mais.

```bash
# requer Supabase CLI
supabase init
supabase migration new <nome>
```
