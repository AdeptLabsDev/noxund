# supabase — Database & Auth

**Status:** placeholder. Sem migrations ainda.
**Owner agents:** Database Agent, Security & Privacy Agent.

## O que viverá aqui (quando construído)

- `migrations/` — migrations versionadas do schema do MVP (`04_Database_Event_Model.md`).
- Políticas RLS e roles.
- Seeds de desenvolvimento (dados fake, nunca dados reais de produtor).

## Princípios (ver docs/agents/database-agent.md)

- **Raw imutável** — tabelas raw nunca recebem update.
- **Computed reconstruível** — métricas/score/rows recalculáveis a partir do raw.
- **Report snapshot congelado** — não muda após publicado.
- **Sem tabelas de marketplace/Fase 2** (`04_...` §12): `beats`, `orders`, `payouts`, `licenses`, etc.
- Toda migration passa por **Database + Security review** (`agent-review-matrix.md` #3).

## Como será inicializado (futuro, com revisão)

> Não rodar agora.

```bash
# requer Supabase CLI
supabase init
supabase migration new <nome>
```
