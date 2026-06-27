# SEC-0012 — Security Review (review_rls) · Fase 4 — Raw YouTube Snapshots (DDL + verify)

- **Task:** `task_phase4_security_review_rls` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-26
- **SQL:** `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql`
- **Verify:** `supabase/tests/phase4_post_apply_verify.sql`
- **Rollback:** `supabase/rollback/20260620000004_phase4_raw_youtube_snapshots.rollback.sql`
- **Handoff:** `docs/database/HANDOFF-phase4-design.md`
- **Mandato:** SEC-0001 §0 + matrix #3 (Database + Security em toda migration). Gate de veto. Silêncio ≠ aprovação.
- **Status do alvo:** AUTORADO, NÃO APLICADO. Apply segue gated (humano + required reviewers + verify fail-closed), espelhando Fases 1–3.

---

## 0. Veredito

✅ **LIBERADO — SEM BLOQUEIO. Meu gate (matrix #3) sobre a Fase 4 está baixado.** O DDL impõe a imutabilidade **total e incondicional** do raw por trigger **abaixo do service_role** (SEC-D03/F01/F16); o scrub SEC-F08 está no schema (CHECK top-level + ausência estrutural de coluna de request/key), com a ressalva de honestidade do autor **aceita como suficiente na camada de schema**; RLS default-deny + revoke nas 3 (SEC-F13/F02); e o verify **já nasce com a lição DEC-0009 embutida** — paridade de errcode no caminho service_role e prova positiva (`restrict_violation`) no caminho grant-holder (SEC-F21/F22). Esta é a fase mais limpa das quatro: a correção que na Fase 3 só veio por hotfix (SEC-0009→0010) aqui chegou **antes do apply**, exatamente como o escopo da tarefa exigia.

Registro **uma condição não-bloqueante de carry-forward** (SEC-F23) — o scrub autoritativo e a higiene de log são gate de **pipeline** (Data/AI + Backend + DevOps), não de schema. Não é veto; é o complemento de `SEC-F08`/`SEC-F10` cuja trava é "Fases 4/6/7".

*(Veto da **Fase 9 — RLS Policies** segue de pé, à parte, SEC-0001 §0. Esta migration NÃO o destrava — adiciona zero policy, corretamente.)*

---

## 1. Condições de veto — veredito ponto a ponto

### #1 — Imutabilidade do raw por TRIGGER abaixo do service_role (SEC-D03/F01/F16) → ✅ PASSA

| Aspecto | Veredito | Evidência |
|---|---|---|
| Imutabilidade **abaixo** do service_role | ✅ | `raw_youtube_immutable()` (L46-55) e `raw_youtube_no_truncate()` (L57-66) levantam exceção; 6 triggers `before update or delete` (row) + `before truncate` (statement) nas 3 tabelas (L151-170). **Triggers comuns disparam para o owner e para service_role** — `BYPASSRLS` bypassa **RLS, não trigger**. Logo grants/RLS NÃO são a única defesa: a garantia fica no banco, abaixo do service_role. |
| **Total e incondicional** (ao contrário do freeze por-coluna de `report_runs`) | ✅ | `raw_youtube_immutable()` levanta **incondicionalmente** — não há caminho `return new`. Raw não tem STATE; qualquer UPDATE/DELETE é barrado. Correto e distinto do `report_runs_row_guard` (que permite STATE e congela só identidade). |
| Cobertura de TRUNCATE | ✅ | `before truncate ... for each statement` separado (row triggers não disparam em TRUNCATE). Fecha o vetor que um trigger só-row deixaria aberto. |
| Rotas alternativas de mutação | ✅ | `INSERT ... ON CONFLICT DO UPDATE` e `MERGE ... WHEN MATCHED` disparam o BEFORE UPDATE/DELETE → barrados. Não há `CREATE RULE`. Nenhuma rota DML escapa. |
| `search_path=''` nas 2 funções | ✅ | L49, L60 — higiene. Não são SECURITY DEFINER (trigger functions, invoker); o pin é correto e provado em §4 do verify (L43-57). |

**Limite honesto (registrado, não-bloqueante):** `DROP/DISABLE TRIGGER` e `DROP TABLE` são **DDL** e exigem ownership/superuser — fora do alcance do trigger (DML). É a mesma fronteira aceita em SEC-D03 e no rollback (que documenta `DROP TABLE` como rota DDL legítima só para run descartável). A ameaça aplicacional real é DML por service_role, e essa está fechada. Sem objeção.

### #2 — SEC-F08: CHECK top-level (não recursivo) rejeitando envelope de request → ✅ SUFICIENTE NO SCHEMA (sem veto) + carry-forward SEC-F23

CHECK `*_no_request_context`: `not (<payload> ?| array['config','request','headers','authorization','key'])` (L80-81, L109-110, L138-139).

Avaliei a ressalva do autor (scrub autoritativo é do pipeline; defesa primária = ausência de coluna; CHECK é top-level, não recursivo) e **aceito como suficiente na camada de schema**, pelos seguintes fatos:

1. **Defesa primária é estrutural e total:** não existe coluna para request/URL/key. A key **não tem onde** ser persistida — não é promessa, é ausência de superfície.
2. **O CHECK pega o vetor concreto que SEC-F08 nomeia** — o dump do envelope axios/fetch (`config.url` com `?key=`, `config.headers.Authorization`) tem `config`/`request`/`headers` no **topo**. O `?|` casa em chave de topo → INSERT rejeitado → zero vazamento.
3. **Zero falso-positivo nos 3 corpos legítimos:** `search.list`/`videos.list`/`channels.list` têm topo `{kind, etag, items, pageInfo, nextPageToken, …}` — **nenhum** deles tem `config/request/headers/authorization/key` no topo. O corpo verbatim do YouTube nunca ecoa a key. Verificado contra o contrato da YouTube Data API v3.
4. **`?|` em chave de topo é a escolha certa, não preguiça:** um scan recursivo seria o ferramental **errado** — custo por-insert em payload grande, risco real de falso-positivo conforme a API evolui, e **mesmo assim não-autoritativo**. Rejeitar o deep-scan foi acerto de engenharia, não atalho.

**Por que não é veto:** a obrigação da camada de schema (defesa estrutural + defesa-em-profundidade top-level, ambas com zero falso-positivo) está **cumprida**. O scrub autoritativo — garantir que só o **corpo** (`response.data`) é persistido, nunca o objeto de transporte — é por definição responsabilidade do pipeline, e o autor a atribui corretamente. Um CHECK não pode ser o scrub autoritativo sem virar fonte de falso-positivo.

> **SEC-F23 (carry-forward, não-bloqueante) — scrub autoritativo + log hygiene são gate de pipeline.** Antes da **coleta real**, exigir (não nesta migration): (a) Data/AI `define_collection_spec` / Backend persistem **apenas** o corpo da resposta, com scrub explícito de contexto de request, testado; (b) DevOps garante que a key nunca atersene em log/Sentry (SEC-F10). Trava herdada de `SEC-F08`/`SEC-F10` (Fases 4/6/7) — **não** trava o apply da Fase 4 (que não coleta nada), trava a coleta. Registro aqui para não se perder.

### #3 — RLS ENABLE + default-deny + revoke anon/authenticated nas 3, zero policy (SEC-F13/F02) → ✅ PASSA

| Aspecto | Veredito | Evidência |
|---|---|---|
| RLS habilitada nas 3 | ✅ | `enable row level security` em search_pages/videos/channels (L177-179). |
| Default-deny (zero policy) | ✅ | Nenhuma `create policy` no arquivo. RLS-on sem policy = nega tudo a anon/authenticated. |
| Revoke explícito | ✅ | `revoke all ... from anon, authenticated` nas 3 (L184-186) — remove o grant; o RLS-on é a 2ª camada se um grant vazar no futuro (exatamente o intento SEC-F13). |
| service_role | ✅ | Bypassa RLS (é o escritor interno insert-only), mas continua barrado de **mutar** pelos triggers (#1). Leitura interna por service_role é o uso pretendido; produtor nunca lê raw (vê `report_items`, Fase 5). |

Estrutura **idêntica** à Fase 3 que já liberei (SEC-0009 §1 / SEC-0010). Sem desvio.

### #4 — Errcode-parity no verify (lição DEC-0009 / SEC-F21 / SEC-F22) → ✅ PASSA (embutida na origem)

A asserção mais importante: o verify **não repete** o falso-negativo da Fase 2/3-pré-hotfix.

| Caminho | Errcode aceito | Evidência | Veredito |
|---|---|---|---|
| **Grant-holder (postgres)** — UPDATE/DELETE/TRUNCATE | **só `restrict_violation`** | L173, L178, L183 | ✅ **Prova POSITIVA do freeze (SEC-F22):** postgres detém o grant → o **único** mecanismo que pode barrar é o **trigger** → tem de ser `restrict_violation`. Se o trigger sumisse, o UPDATE teria sucesso e o probe levantaria "SUCCEEDED (regression)". Teste verdadeiro, não vacuoso. |
| **service_role** — UPDATE/DELETE/TRUNCATE | **`restrict_violation` OR `insufficient_privilege`** | L192, L197, L202 | ✅ **Paridade SEC-F21:** service_role pode ser barrado no *grant layer* (42501) **antes** do trigger, OU pelo trigger. Aceitar os dois evita o falso-negativo que travou a Fase 2 (DEC-0009). A existência do trigger é provada à parte (§4 L60-78 + o caminho grant-holder acima) → alargar o errcode aqui **não** afrouxa a garantia. |
| **SEC-F08 empírico** — corpo limpo ACEITO / envelope dirty REJEITADO | `check_violation` no dirty | aceito L217-222; rejeitado L229, L235, L241 | ✅ Prova as **duas** direções: zero falso-positivo no corpo verbatim e rejeição do `config`/`request`/`key` no topo. Scrub provado no schema. |
| **Unicidade lógica** — `(run_id, video_id)` duplicado | `unique_violation` | L258 | ✅ |
| **Default-deny** — anon/authenticated SELECT nas 3 | **só `insufficient_privilege`** (42501) | L274 | ✅ Correto manter **estrito** (SELECT sem grant é sempre 42501; trigger não entra). Não alargado — idêntico à decisão SEC-0010 §3. |

Estrutural §4 íntegro (3 tabelas L28-40; `search_path` pin L43-57; **6 triggers** L60-78; 3 índices L81-96; **3 FKs** para `report_runs` L99-115; **3 CHECKs SEC-F08** L118-133; RLS-on L136-147). `ON_ERROR_STOP=1`, todos os probes em transações revertidas (efeito colateral nulo). Seed usa `report_runs(window_start, window_end)` — colunas `not null` sem default na Fase 3 (L54-55), FK `→ report_runs(id)` satisfeita. Verificado.

---

## 2. Checagens independentes (minhas, além das 4 condições) — todas OK

- **Atômico:** `begin/commit` (L37/L188). Rollback atômico e na ordem certa (triggers→funções→tabelas, L20-38), fora de `migrations/` de propósito.
- **Zero secret** em SQL/verify/rollback/handoff. Nenhuma string de credencial/conexão.
- **Zero tabela de marketplace/Fase 2** — as 3 são `raw_youtube_*` do `04_ §4`.
- **FK `on delete restrict` → report_runs** (L74/99/130): belt-and-suspenders (report_runs já é indeletável por trigger). Raw nunca órfão de proveniência. Sem objeção.
- **`bigint` nos contadores:** correção de overflow, não preferência. **Sem ângulo de segurança** (não toco em metodologia; é decisão Data/AI #4).
- **PII:** `raw_json`/`response_json` guardam corpo público do YouTube (títulos/canais), não PII de produtor. Não abre nova superfície de PII; raw é default-deny interno. Gate LGPD (SEC-F09) segue de pré-produção, inalterado.

---

## 3. Quadro de gates do `run_migration` (Fase 4)

| Gate | Estado |
|---|---|
| Security `review_rls` do SQL + verify (matrix #3) | ✅ **BAIXADO** — este doc (SEC-0012) |
| Data/AI #4 (imutabilidade do raw / reprodutibilidade; tipos/nulabilidade fiéis ao payload) | ⏳ pendente — **não é meu gate** |
| Pipeline `phase4-db-apply.yml` (a autorar por DevOps) + `audit_secrets` (matrix #8, delta) | ⏳ ainda não autorada/auditada por mim |
| PR revisado + merge na `main` (sem push direto) | ⏳ |
| Gate humano + required reviewers em CI | ⏳ runtime |
| **SEC-F23** — scrub autoritativo + log hygiene no pipeline (antes da coleta real) | ⏳ carry-forward não-bloqueante (gate de coleta, não de apply) |
| Fase 9 — RLS Policies | ⛔ veto à parte (SEC-0001 §0); Fase 4 NÃO destrava |

**Como meu gate ficou baixado:** o DDL e o verify atendem integralmente SEC-D03/F01/F16, SEC-F08 (camada de schema), SEC-F13/F02 e SEC-F21/F22. Nenhuma correção exigida. **SEC-F23 não bloqueia o apply da Fase 4** (que não coleta dado) — é o gate da coleta, herdado de SEC-F08/F10, e fica registrado para Data/AI/Backend/DevOps. Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`) — este doc é a liberação explícita.
