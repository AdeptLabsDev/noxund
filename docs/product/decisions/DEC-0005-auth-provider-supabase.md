## DEC-0005 — Auth provider: Supabase Auth (resolve OD-02)

- **Data:** 2026-06-20
- **Status:** **Aprovada — confirmada pelo Product Lead (2026-06-20)**
- **Decisor:** Product Orchestrator
- **Área:** Stack / Auth
- **Prioridade/Impacto:** Alto (gargalo da Fase 1)

### Contexto
Backend (BE-0001) e Database (handoff) bloquearam o desenho final do `/apply` e da sessão em **OD-02 (Auth: Supabase Auth vs Clerk)** e o escalaram ao Product Lead via PO. OD-02 estava em `scope-guardrails` com recomendação Supabase Auth ("Confirmar na Sprint 0"). É o gargalo real para abrir a Fase 1 (`producers` + `applications` + `admin_users`).

### Decisão
**Adotar Supabase Auth.** Encerra OD-02.

### Alternativas consideradas
- **Clerk** — bom produto, mas **adiciona um fornecedor** fora da stack travada e quebra a coerência com o modelo de segurança já fechado. (não)
- **Supabase Auth** — nativo da stack já travada (LD-12); integra direto com RLS via `auth.uid()`. (sim)

### Justificativa
1. **Coerência com decisão já travada:** LD-12 fixa Supabase na stack; Supabase Auth não é mudança de stack, é usar o que já está dentro. Clerk seria *adicionar fornecedor* — exatamente o que `00_`/`scope-guardrails` evitam ("menos fornecedores").
2. **Coerência com o modelo de segurança:** SEC-D01 já amarra `producers.auth_user_id → auth.users.id` e a RLS de produtor a `auth_user_id = auth.uid()`. Toda a Fase 9 (SEC-0001) foi desenhada sobre `auth.users`/`auth.uid()` nativos do Supabase. Clerk forçaria uma ponte de identidade redundante.
3. **Menor superfície:** um fornecedor a menos = menos secrets, menos integração, menos risco (alinhado a `02_...` §9 e ao padrão de segurança day-1).

### Impacto
- **Escopo:** nenhum. Mantém a stack travada (LD-12).
- **Non-negotiables:** preservados; reforça o desenho de RLS (SEC-0001) que já assume Supabase Auth.
- **Documentos a atualizar:** `scope-guardrails.md` (OD-02 → Resolvida).
- **Tarefas afetadas:** destrava `[BE] Auth gate + approval gate`, `[BE] Endpoint POST /apply`, e a Fase 1 do `migration-plan.md`.

### Reversibilidade
Média-alta enquanto não há código — trocar para Clerk seria caro depois que a RLS e o `auth_user_id` estiverem implementados, por isso confirmar **agora**. Product Lead pode reverter antes da Fase 1.

### Revisões necessárias
- [x] Product Orchestrator
- [x] **Product Lead — confirmado (2026-06-20)**
- [ ] Security (magic-link vs senha é detalhe de implementação dentro do Supabase Auth; sem impacto de schema — SEC-0001)

### Follow-up
Notificar Product Lead para confirmação. Com OD-02 fechada + Data/AI ✅ + Backend ✅, a **Fase 1** pode abrir com revisão **Database + Security**. OD-03 (Email) e OD-04 (Cron) seguem abertas, mas só impactam Sprint 2 (follow-up), não a Fase 1.
