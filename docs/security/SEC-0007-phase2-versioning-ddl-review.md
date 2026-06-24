# SEC-0007 — Security Review (review_rls) · Fase 2 — Versionamento (DDL)

- **Task:** `task_phase2_security_review_rls` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-24
- **SQL:** `supabase/migrations/20260620000002_phase2_versioning.sql`
- **Rollback:** `supabase/rollback/20260620000002_phase2_versioning.rollback.sql`
- **Handoff Database:** `docs/database/HANDOFF-phase2-versioning.md`
- **Mandato:** SEC-0002 §5 (re-review do SQL concreto antes de qualquer apply) · matrix #3 (Database+Security em toda migration). Gate de veto.

---

## 0. Veredito

✅ **SEM BLOQUEIO — veto técnico do Security sobre o SQL da Fase 2 BAIXADO.**

Os 5 itens do mandato passam; a Fase 2 reaplicou corretamente o padrão de segurança da Fase 1 (default-deny + revoke explícito; imutabilidade **UPDATE+DELETE+TRUNCATE**; `search_path` fixo; zero secret). **Decisão (a) — append-only das `*_versions` — RATIFICADA.**

*Não é gate único do apply.* Permanecem, **fora da minha alçada**: Data/AI #5 (fidelidade ao §7 + ownership do `rubric_hash`, matrix #5), o gate humano + required reviewers do `run_migration`, e um **verify pós-apply análogo ao da Fase 1** (condição abaixo). Veto da **Fase 9 (RLS Policies)** segue de pé (SEC-0001 §0).

---

## 1. Veredito por item do mandato

| Item | Veredito | Evidência |
|---|---|---|
| **RLS ENABLE + default-deny + revoke explícito; zero grant residual** | ✅ **PASSA** | `enable row level security` nas 2 (L108-109); `revoke all ... from anon, authenticated` (L114-115); **nenhuma** `create policy` (default-deny). O revoke explícito neutraliza os default privileges do Supabase — mesmo padrão aprovado na Fase 1. |
| **Triggers UPDATE+DELETE+TRUNCATE + função `search_path=''` + errcode** | ✅ **PASSA** | Função `versioning_row_immutable()` `set search_path = ''` (L81), `raise ... using errcode = 'restrict_violation'` (L84-85), sem `NEW`/`OLD` (serve row **e** statement). 4 triggers: `*_no_update_delete` (BEFORE UPDATE OR DELETE, row) + `*_no_truncate` (BEFORE TRUNCATE, statement) em **ambas** as tabelas (L89-101). **Lição SEC-F16 propagada** — cobre o TRUNCATE que um trigger row-level não pega. |
| **Ratificar (a) append-only das `*_versions`** | ✅ **RATIFICADO** | Ver §2. |
| **`config_json`/`hash` internos; nada aberto a anon/authenticated; leitura admin/server fica na Fase 9** | ✅ **PASSA** | Default-deny + revoke ⇒ anon/authenticated com **zero** acesso. Nenhuma policy de leitura criada — escrita é service-role/Data-AI (bypassa RLS). A fórmula do Score (`config_json`) nunca chega ao produtor; ele vê só `X/100` + tooltip conceitual (§7). Policies de leitura admin/server **diferidas à Fase 9** (correto, consistente com SEC-0001 §0). |
| **Zero secret no SQL/handoff; nenhuma tabela de marketplace** | ✅ **PASSA** | Sem credencial/token/senha no SQL nem no handoff. Seed do §7 é **template comentado** (L119-144), não executado; `hash` fica placeholder (computado pelo data-engine, não fabricado no banco). `config_json` é metodologia interna, **não** secret. Tabelas `rubric_versions`/`outcome_weight_versions` são do `04_ §11` — **nenhuma** de marketplace. |

---

## 2. Ratificação da decisão (a) — append-only das `*_versions`

**RATIFICO append-only (UPDATE+DELETE+TRUNCATE bloqueados) em `rubric_versions` e `outcome_weight_versions`.** Não é só integridade de banco — é **requisito de segurança/auditoria**:

- `rubric_versions` é o **backbone de reprodutibilidade**. Um relatório congelado referencia `(rubric_version, rubric_hash)`; se a linha do rubric pudesse ser editada in-place, a auditoria de relatórios já publicados quebraria silenciosamente (o relatório diria "Score sob rubric X" enquanto o config de X mudou). Append-only é o que torna o non-negotiable #5 (*Score versionado por rubric; mudança de pesos = nova linha*) verificável no banco.
- Alinha com **SEC-0003 §2** (toda tabela append-only/imutável precisa do guard completo, inclusive TRUNCATE — senão `service_role`, que bypassa RLS, poderia limpar a tabela).
- **Trade-off aceito:** corrigir um rubric com erro = **nova versão (v2)**, nunca editar. É a disciplina correta para uma tabela que lastreia auditoria. Não há coluna de desativação que exija UPDATE (o "rubric atual" resolve-se por `active_from`).

---

## 3. Checagens independentes (além do mandato) — OK

- **Atômico:** `begin/commit` (L27, L117) → sem estado parcial.
- **Rollback correto e reversível:** dropa os 4 triggers → função compartilhada → 2 tabelas (L18-27), ordem certa (a função é usada pelos triggers; dropá-los antes evita falha). Atômico. Sem enums/sequences. `DROP TABLE` é DDL e **não** dispara os triggers de imutabilidade — o rollback funciona apesar do append-only. ✅
- **Idempotência:** `create table` sem `IF NOT EXISTS` (como na Fase 1) — aceitável, falha alto, protegido pela transação. ✅
- **Função não é `SECURITY DEFINER`** (é trigger function, roda como invoker) — `search_path=''` é higiene defensiva correta; o corpo só usa built-ins (`tg_op`/`tg_table_name`), então o search_path vazio não quebra nada. ✅

---

## 4. Condição antes do apply (não é defeito do SQL; espelha a Fase 1)

- **Verify pós-apply análogo ao da Fase 1 (recomendado→exigido para paridade):** o apply da Fase 2 deve rodar uma verificação empírica (como `phase1_post_apply_verify.sql`) que asserta: 2 tabelas, 4 triggers presentes, RLS-on nas 2, e **empiricamente** que `update/delete/truncate` como `service_role` são bloqueados e `anon`/`authenticated` têm **zero** acesso. A Fase 1 estabeleceu que a imutabilidade se **prova em banco**, não se assume. Isso é artefato do pipeline (DevOps) e entra na revisão da pipeline de apply da Fase 2 (matrix #8) — **não** trava este `review_rls` (o SQL está correto), mas é pré-condição para considerar o apply concluído.

---

## 5. Fora da minha alçada (registrado)

- **Data/AI #5 (matrix #5):** confirmar que o versionamento captura fielmente o §7 (componentes/pesos 40/25/20/15) e ratificar a propriedade do `rubric_hash` (owner do hash determinístico). **Sem objeção de segurança** — o SQL trata `config_json` como opaco e documenta o `hash` como computado fora do banco (respeita "IA/DB não gera número").
- **Open decision (b) do handoff** — `outcome_weight_versions.hash` (adicionado por "mesma disciplina"; `04_ §11` não listava): decisão de modelagem do Data/AI. **Sem objeção de segurança.**

---

## 6. Quadro de gates do `run_migration` (Fase 2)

| Gate | Estado |
|---|---|
| Security `review_rls` sobre o SQL (matrix #3) | ✅ **BAIXADO — este doc (SEC-0007)** |
| Data/AI #5 (fidelidade §7 + `rubric_hash`) | ⏳ pendente (não é meu gate) |
| Verify pós-apply análogo (DevOps) | ⏳ recomendado/exigido p/ paridade (§4) |
| Gate humano + required reviewers do apply | ⏳ em tempo de execução (como na Fase 1) |
| Fase 9 — RLS Policies | ⛔ veto à parte de pé (SEC-0001 §0) |

**Como o apply abre:** Security ✅ (aqui) + Data/AI #5 ✅ + verify de paridade + gate humano/reviewers. Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).
