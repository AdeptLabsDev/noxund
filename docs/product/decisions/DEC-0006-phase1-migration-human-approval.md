## DEC-0006 — Aprovação humana antecipada do apply da migration da Fase 1

- **Data:** 2026-06-21
- **Status:** **Aprovada — concedida pelo Product Lead (2026-06-21)**
- **Decisor:** Product Lead (registrada pelo Product Orchestrator)
- **Área:** Segurança / Schema / Processo de gate
- **Prioridade/Impacto:** Alto (destrava o apply da Fase 1, sob condição)

### Contexto
O `database_agent` concluiu `task_phase1_ddl_authoring`: DDL concreto da Fase 1 (`producers`, `applications`, `admin_users`, `audit_events`) autorado em `supabase/migrations/20260620000001_phase1_core_identity_access.sql` + rollback companheiro, incorporando SEC-0002 §5 + SEC-F15 + `audit_events` antecipada. **Nada aplicado.** Há **dois gates independentes** sobre `change_db_schema`/`run_migration`:
1. **Veto técnico do Security** (SEC-0002 §0/§5) — só cai com re-review do **SQL concreto** contra as 6 condições do §5; "silêncio de Security ≠ aprovação".
2. **Gate de aprovação humana** — exigido pelo runtime para ações sensíveis (`change_db_schema`/`run_migration`).

### Decisão
O **Product Lead concede, antecipadamente, a aprovação humana** para o apply da migration da Fase 1 (`20260620000001_phase1_core_identity_access.sql`) **nesta fase**. A aprovação **satisfaz o gate humano (gate #2)** — mas **não substitui nem antecipa o re-review do Security (gate #1)**. O apply só ocorre quando **ambos** estiverem satisfeitos: Security baixa o veto sobre o SQL **e** esta aprovação humana cobre o `run_migration`.

### Alternativas consideradas
- **Aplicar agora com base só na aprovação humana** — rejeitada: contorna o gate técnico do Security sobre o SQL concreto; viola o não-negociável "sem alteração de schema sem revisão" e o protocolo SEC-0002 §5.
- **Esperar a aprovação humana só após o Security** — possível, mas adiciona um round-trip. Antecipar o gate humano (registrado aqui) permite aplicar imediatamente após o Security baixar o veto, sem nova espera.

### Justificativa
Mantém o sequenciamento de segurança intacto (Security revisa o SQL primeiro) e ainda assim preserva velocidade de validação: o caminho crítico passa a ser apenas o `review_rls` do Security, não a disponibilidade do Product Lead. A aprovação fica escopada à Fase 1 e a este arquivo de migration — não é um cheque em branco para migrations futuras.

### Impacto
- **Escopo:** nenhum. 4 tabelas de identidade/acesso/auditoria; zero Fase 2.
- **Non-negotiables:** preservados. "Sem alteração destrutiva de banco sem revisão" continua valendo — o veto do Security segue ativo até o re-review.
- **Documentos a atualizar:** este DEC; o apply final referencia DEC-0006 + o veredito do `review_rls`.
- **Tarefas afetadas:** destrava o gate humano de `database_agent:run_migration` da Fase 1 (condicionado ao Security).

### Reversibilidade
Alta. Enquanto o apply não ocorrer, o Product Lead pode revogar esta aprovação. Após o apply, a reversão é via `supabase/rollback/20260620000001_phase1_core_identity_access.rollback.sql` (rollback declarado e reversível).

### Revisões necessárias
- [x] Product Lead — aprovação concedida (2026-06-21)
- [x] Product Orchestrator — registrada
- [ ] **Security — `review_rls` sobre o SQL concreto (gate #1, bloqueante)**

### Follow-up
1. Orchestrator delega `security_agent:review_rls` sobre o SQL concreto (SEC-0002 §5 + SEC-F15).
2. Com o veto baixado **e** esta aprovação, `database_agent:run_migration` (gated) aplica a Fase 1.
3. Provisionamento do projeto Supabase segue como **trilha paralela** (DevOps/Infra), independente do `review_rls`.
