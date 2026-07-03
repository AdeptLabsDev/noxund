## DEC-0007 — Condições adicionais para o apply da Fase 1 (audit_secrets + PR)

- **Data:** 2026-06-21
- **Status:** **Aprovada — concedida pelo Product Lead (2026-06-21)**
- **Decisor:** Product Lead (registrada pelo Product Orchestrator)
- **Área:** Segurança / Infra / Processo de gate
- **Prioridade/Impacto:** Alto (endurece o gate do apply da Fase 1; não destrava nada além do `configure_env`)
- **Relaciona:** DEC-0006 (gate humano da migration), SEC-0004 (veto técnico baixado), INFRA-0001 (ambiente credenciado), SEC-0002 §5

### Contexto
O `devops_agent:configure_env` (sensível/gated) foi dispatchado para montar o ambiente credenciado `production-db` conforme `INFRA-0001` — artefatos versionados (`config.toml`, `.github/workflows/phase1-db-apply.yml`, `supabase/tests/phase1_post_apply_verify.sql`), **sem secret**, com os valores populados out-of-band pelo Product Lead. O Product Lead **aprova o gate humano do `configure_env`**, mas condiciona o apply real a garantias adicionais.

### Decisão
1. **`configure_env` autorizado** — montar o ambiente `production-db` e versionar os artefatos (sem secret). O gate humano deste passo está **concedido**.
2. **`run_migration` (apply da Fase 1) NÃO autorizado** até **ambas** as condições abaixo, **além** de DEC-0006 e do veto do Security já baixado (SEC-0004):
   - **(a)** `security_agent:audit_secrets` sobre o ambiente credenciado/artefatos retornar **sem bloqueio** (cobre INFRA-0001 §5: SHA-pin das actions, escopo do Environment ao branch protegido, ausência de secret em arquivo versionado/log, política de rotação);
   - **(b)** os artefatos versionados entrarem por **Pull Request revisado (DevOps + Security, matrix #8) e mergeado** na `main` — **sem push direto** (non-negotiable #7).
3. O **gate de execução em CI** do `INFRA-0001 §3` (dispatch manual `APPLY-PHASE1` + required reviewers DevOps+Security do Environment `production-db`) permanece como camada complementar em tempo de execução.

### Gate consolidado do `run_migration` (após esta decisão)

> **✅ FECHADO (2026-06-24) — ver DEC-0008.** Todos os gates abaixo foram satisfeitos e a Fase 1
> foi **aplicada e verificada** em CI (run `27956757153`). Tabela atualizada para o estado final.

| Gate | Fonte | Estado |
|---|---|---|
| Veto técnico do Security (SQL) | SEC-0004 | ✅ baixado |
| Aprovação humana da migration | DEC-0006 | ✅ concedida |
| `audit_secrets` sem bloqueio | DEC-0007 (a) | ✅ fechado (SEC-0006, antes do merge) |
| PR revisado + mergeado | DEC-0007 (b) | ✅ fechado (sem push direto) |
| Required reviewers em CI | INFRA-0001 §3 | ✅ fechado (run de `main`, reviewer AdeptLabsDev) |

### Alternativas consideradas
- **Aplicar logo após `configure_env`, só com DEC-0006** — rejeitada pelo Product Lead: deixaria a mudança de ambiente sem revisão de segurança (`audit_secrets`) e poderia introduzir os artefatos sem PR. Contraria "sem push direto na `main`" e a matriz de revisão #8.

### Justificativa
A mudança de ambiente credenciado é, ela própria, superfície de segurança (secrets, supply chain de actions, escopo do Environment). Revisá-la com `audit_secrets` e fazê-la entrar por PR preserva a auditabilidade e o controle de mudança sem custo relevante — o ambiente já está preparado (`INFRA-0001` "preparado, pendente de ação humana").

### Impacto
- **Escopo:** nenhum no produto. Endurece o processo de apply da Fase 1.
- **Non-negotiables:** reforça #7 (sem push direto) e a revisão de Security obrigatória.
- **Reversibilidade:** alta — nada aplicado; condições puramente processuais.

### Follow-up
1. `devops_agent:configure_env` executa → artefatos numa branch + **abre PR** (não push direto).
2. `security_agent:audit_secrets` sobre o ambiente/PR.
3. PR revisado (DevOps + Security) e mergeado.
4. Product Lead popula o Environment `production-db` (secrets + variables) out-of-band.
5. `database_agent:run_migration` dispara o workflow gated → apply + verificação §4/§5.
