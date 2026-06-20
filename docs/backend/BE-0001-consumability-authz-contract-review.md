# BE-0001 — Backend Review · Consumibilidade dos Endpoints + Contrato de Authz

- **Owner:** Backend/Next API Agent (`docs/agents/backend-agent.md`)
- **Data:** 2026-06-20
- **Prioridade:** P0
- **Alvo da revisão:** `docs/database/mvp-data-model.md`, `docs/security/SEC-0001-mvp-data-model-review.md`, `docs/database/rls-review-notes.md`, `docs/database/migration-plan.md` — contra a API surface de `02_Stack_Infra_Architecture.md` §7 e o event model de `04_Database_Event_Model.md`.
- **Natureza:** revisão de proposta (sem código, sem rota implementada) + **compromisso de desenho** dos handlers. As condições "Alta" do SEC-0001 cuja mitigação é de handler são **minhas de desenhar** — aqui elas viram contrato.

---

## 0. Veredito

**O modelo de dados serve os endpoints de `02_` §7.** Não há gap conceitual que impeça implementar a superfície de API do MVP. Confirmo a consumibilidade endpoint a endpoint (§1).

**Backend assume SEC-F01, SEC-F02, SEC-F03 e SEC-F11 como contrato de implementação não-negociável** (§3), pré-condição:
- de **Fase 1** (migration `producers`+`applications`+`admin_users`) para SEC-F01/F02;
- de **Fase 9** (RLS) e do read endpoint do produtor para SEC-F01/F03;
- dos **endpoints `/internal/*`** para SEC-F11.

**Escrita atômica evento+payload confirmada** (§4): WTP grava `wtp_responses` + `producer_events` na mesma transação; intenção grava `producer_events` + `followups` na mesma transação. A garantia de atomicidade exige **funções Postgres (RPC)** — PostgREST é por statement (§4.1, aciona Database).

**5 achados de consumibilidade** (§2) — nenhum trava o modelo de dados; **um deles é gap na própria API surface** (`02_` §7 não tem rota para capturar a resposta do follow-up) e sobe ao Product Orchestrator.

**DevOps acionado por mim** (§5): SEC-F10 (scrub de PII/secret no Sentry) e SEC-F11 (provisionamento e rotação do secret do cron + agendamento OD-04).

**Bloqueio honesto:** o desenho **final** de `/apply` (provisionamento de `auth_user_id` na aprovação) e da **sessão** (`auth.uid()` → `producers`) depende de **OD-02 (Auth)**. A parte **anônima** de `/apply` é desenhável já; a ponte aprovação→identidade espera OD-02. Empurrei OD-02 ao Product Lead (já em `[PRODOPS] Resolver OPEN DECISIONS`).

---

## 1. Confirmação de consumibilidade (`02_` §7 → modelo)

Legenda: **R** = leitura · **W** = escrita · **E** = evento em `producer_events` · **A** = `audit_events`.
Authz "em código" = checagem no handler service-role (SEC-F01), não só RLS.

### 1.1 Public / semi-public

| Rota | Tabelas / colunas | Evento | Authz (boundary) | Serve? |
|---|---|---|---|---|
| `GET /` | — (página) | — | público; `noindex` é do Frontend | ✅ n/a |
| `POST /apply` | **W** `producers` (upsert idempotente por `lower(email)`), `applications` (`status=submitted`) · **E** `application_submitted` | `application_submitted` | `anon` **zero-grant**; handler service-role; whitelist estrita; `status` forçado (SEC-F02) | ✅ |

Notas `/apply`:
- Ordem transacional: resolve/insere `producers` → insere `applications` → emite `application_submitted` (referencia `producer_id`).
- Idempotência por `lower(email)` em `producers`; reaplicar **não** sobrescreve histórico — **nova** linha em `applications` + índice parcial garante ≤1 `submitted|under_review` por produtor (modelo já prevê).
- `/apply` é **anônimo** — não depende de sessão. Só o caminho **pós-aprovação** (provisionar `auth_user_id`) depende de OD-02.

### 1.2 Authenticated producer

| Rota | Tabelas / colunas | Evento | Authz | Serve? |
|---|---|---|---|---|
| `GET /app/report` | **R** `reports` (`status=published`) + `report_items` **via VIEW pública** (SEC-F03) + `artists` (nome); `example_url` já congelado no item | `report_opened`, `report_switched` | autenticado **E** `producers.status='approved'` **E** `report.status='published'` | ✅ |
| `POST /api/report/:reportId/artist/:artistId/feedback` | **W/E** `producer_events` (`artist_marked_useful` \| `artist_marked_not_useful`; resolve `report_item_id`) | feedback | autenticado+aprovado; `producer_id` **da sessão** (SEC-F01) | ✅ |
| `POST /api/report/:reportId/artist/:artistId/intent` | **W/E** `producer_events` (`intent_to_produce_declared`) **+** `followups` (`pending`, `producer_event_id`) — **atômico** | intenção (North Star) | autenticado+aprovado; `producer_id` **da sessão** (SEC-F01) | ✅ |
| `POST /api/wtp` | **W/E** `wtp_responses` **+** `producer_events` (`wtp_yes\|no\|maybe`) — **atômico** | WTP | autenticado+aprovado; `producer_id` **da sessão** (SEC-F01) | ✅ |

Notas produtor:
- **Leitura SEMPRE pela VIEW** (SEC-F03). O handler do produtor **nunca** toca `report_items` base nem `artist_metrics`. Snapshot congelado → ler `example_url` do item, **não** recomputar nem ir ao raw em read-time.
- `GET /app/report` precisa de **seletor** de qual dos 2 relatórios (ex.: `?report=<id>`); a alternância emite `report_switched`. Modelo suporta (2 linhas em `reports`). Detalhe de implementação, não gap de modelo (achado §2-B).
- Feedback/intent recebem `:artistId` no path, mas a métrica "Utilidade HOT" (`04_` §13) conta por **`report_item_id`** → o handler resolve `(reportId, artistId)` → `report_item_id` e grava no evento (coluna existe; achado §2-C).
- `producer_id` **nunca** vem do corpo/path/query — só da sessão (SEC-F01). Sem isso, IDOR: produtor A forja intent/WTP/feedback como B.

### 1.3 Admin

| Rota | Tabelas / colunas | Evento/Audit | Authz | Serve? |
|---|---|---|---|---|
| `GET /admin/applications` | **R** `applications` (+ `producers`) | — | `is_admin()` **em código** (SEC-F01) | ✅ |
| `PATCH /admin/applications/:id/status` | **W** `applications.status/reviewed_by/review_notes/reviewed_at`; reflete `producers.status`; na aprovação provisiona `producers.auth_user_id` (OD-02) · **A** `application.approved\|rejected` · **E** `application_approved` | sim | `is_admin()`; máquina de estados forçada no servidor; **só admin** (SEC-F14) | ✅ |
| `GET /admin/reports` | **R** `reports` + `report_items` (colunas completas — admin) | — | `is_admin()` | ✅ |
| `POST /admin/reports/:id/publish` | **W** `reports.status` `draft→published`, `published_at`; **materializa/congela** `report_items` · **A** `report.published` | sim | `is_admin()`; freeze point (SEC-F14) | ✅ |
| `GET /admin/metrics` | **R** agregados de `producer_events` (+ `wtp_responses`, `followups`, `report_items`) conforme `04_` §13; pode ler `score_value`/`raw_score` (server/admin) | — | `is_admin()` | ✅ |

Notas admin:
- Todo `/admin/*` chama `is_admin(auth.uid())` (lê `admin_users`, `revoked_at IS NULL`) **antes** de qualquer efeito — nunca deriva admin de `user_metadata` (SEC-D02).
- Publicar é o **ponto de congelamento**: depois de `published`, sem `UPDATE` de conteúdo de item (trigger de guarda recomendado pelo Security). Backend **não recomputa** em read-time.
- As 4 métricas-norte (`04_` §13) são `count()` sobre `producer_events` → `GET /admin/metrics` é servido integralmente. `score_value`/`raw_score` só aqui (admin), **nunca** no caminho do produtor (SEC-F03).

### 1.4 Internal jobs

| Rota | Tabelas / colunas | Evento | Authz | Serve? |
|---|---|---|---|---|
| `POST /internal/followups/run-due` | **R** `followups` (`status=pending AND due_at<=now()`) · **W** `followups.status→sent`, `sent_at` · **E** `followup_sent` | sim | **secret** + constant-time + **404** (SEC-F11); não-sessão | ✅ |
| `POST /internal/youtube/run-collection` | **W** `raw_youtube_*` via service-role + `run_id` (majoritariamente Data/AI) | — | **secret** (SEC-F11) ou CLI | ✅ |

Notas internal:
- `followups(status, due_at)` indexado (plano de migration Fase 7) → varredura do cron eficiente.
- `run-collection` é gatilho protegido; a lógica de coleta é do Data/AI. Backend só expõe a porta segura. Aceitável CLI no MVP (`02_` §7, backlog [BE] P1).
- Depende de OD-04 (cron) p/ agendamento e OD-03 (email) p/ o envio — não bloqueiam o desenho do handler.

---

## 2. Achados de consumibilidade

Nenhum trava o **modelo de dados**. A,B,C,D são clareza de implementação/desenho; **E é gap na API surface** (`02_` §7) e sobe ao Orchestrator.

- **§2-A — Pares atômicos exigem função Postgres (RPC).** O cliente Supabase/PostgREST executa **por statement**; duas escritas (evento+payload) não são atômicas por dois round-trips. **Decisão de desenho:** WTP e intenção passam por **função `plpgsql` transacional** (RPC). Toca DDL → **revisão Database**. Detalhe em §4.1.
- **§2-B — `GET /app/report` precisa de seletor de relatório.** São 2 relatórios fixos + toggle (`report_switched`). A rota aceita qual relatório (ex.: `?report=<id>`) e emite o evento. Modelo suporta; é implementação.
- **§2-C — feedback/intent devem resolver `report_item_id`.** O path traz `:artistId`, mas a métrica "Utilidade HOT" (`04_` §13) e a proveniência precisam de `report_item_id`. Handler resolve `(reportId, artistId)→report_item_id` e grava (coluna existe em `producer_events`).
- **§2-D — `channel` do follow-up depende de OD-03 (Email).** `followups.channel ∈ {email, dm_manual}`. Default decidido quando OD-03 fechar. **Não** bloqueia a captura de intenção (cria follow-up `pending` já; canal materializado/ajustado depois).
- **§2-E — (GAP NA API SURFACE) Falta rota de captura da resposta do follow-up.** Os eventos `followup_confirmed_produced` / `followup_confirmed_not_produced` e a transição `followups → responded|missed` (e a métrica "Confirmação em follow-up", `04_` §13) **não têm endpoint em `02_` §7**. O produtor responde por **link de email** (provável sem sessão ativa) ou é registrado pelo admin no caso `dm_manual`. **Recomendação:** rota produtor-facing **por token assinado** (ex.: `POST /followup/:token/respond`) — escopo é o **loop de follow-up do MVP**, não Fase 2. Sobe ao Product Orchestrator para incluir na superfície. Modelo já suporta (eventos + `followups.response/responded_at`).

---

## 3. Contrato de implementação de authz (compromisso de desenho)

Estas não são recomendações: são o **contrato** que Backend honra antes de Fase 1/9. São auditáveis pelo Security no re-review (evidência: handlers + testes).

### 3.1 SEC-F01 (Alta) — authz de propriedade/role em código em TODO caminho service-role

**Princípio:** `service_role` faz **bypass de RLS** → nos caminhos service-role o **handler é a fronteira de autorização**; a RLS é defesa em profundidade só p/ `anon`/`authenticated`.

Regras inegociáveis:
1. **`producer_id` é sempre derivado da sessão server-side:** `auth.uid()` → `producers.auth_user_id` → `producers.id`. **Nunca** lido de body/query/path. Qualquer `producer_id` vindo do cliente é **ignorado** (não há `session.producer_id === payload.producer_id` a comparar porque o payload **não carrega** `producer_id`).
2. **Mutações de linhas do produtor** (feedback, intent, wtp) gravam **apenas** o `producer_id` resolvido da sessão.
3. **Caminhos `/admin/*`:** todo handler chama `is_admin(auth.uid())` (lê `admin_users`, `revoked_at IS NULL`) e responde 403/404 **antes** de qualquer efeito colateral. Admin **nunca** derivado de `user_metadata`/JWT auto-declarado.
4. **Binding de recurso:** path params (`reportId`, `artistId`) validados (existem **e** pertencem a `report` `published`) antes do uso; divergência → rejeição.
5. **`service_role` só server-side:** nunca em `NEXT_PUBLIC_*`, nunca no bundle, nunca enviado ao cliente.

**Trava:** Fase 1 (endpoints de evento) + Fase 9 (RLS). Sem isto → IDOR.

### 3.2 SEC-F02 (Alta) — `/apply` anon zero-grant, whitelist, status forçado, rate limit

1. **`anon` com zero grant direto** em qualquer tabela (RLS — DB/Security). `/apply` escreve **só** por handler service-role.
2. **Whitelist estrita (allowlist, nunca blocklist):** `email` (normalizado `lower`+`trim`), `display_name`, `youtube_url`, `portfolio_url` (opcional), `niche`, `decision_process_answer`, `intent_answer`. Validação por schema (zod ou equiv.). **Proibido** `...body`/spread do corpo cru no insert.
3. **Servidor força:** `producers.status='pending'`, `applications.status='submitted'`. `status`, `reviewed_by`, `approved_at`, `auth_user_id`, `reviewed_at`, `review_notes` **nunca** entram pela whitelist → mass-assignment fechado, approval gate protegido.
4. **Idempotência por `lower(email)`** (não sobrescreve histórico).
5. **Rate limit anti-spam:** por IP + por email (`07_` quota/abuse). Infra coordenada com DevOps se exigir store externo.
6. **Sem PII em log** (SEC-F10): logar `producer_id` (uuid) só **após** criar; nunca email/respostas.

**Trava:** Fase 1 + `/apply`.

### 3.3 SEC-F03 (Alta) — leitura do produtor por VIEW pública

1. Read produtor-facing **sempre** pela **VIEW pública** dedicada (ou grant por coluna). **Nunca** `report_items` base, **nunca** `artist_metrics`.
2. **Exposto:** `title`, `rank`, `tag`, `score_display`, `signals`, `velocity_display`, `competition_level`, `competition_channel_count`, `example_video_id`, `example_url`, + `selection_reason` **sanitizado**.
3. **Proibido ao produtor:** `score_value`, `raw_score` (via `artist_metrics`), `selection_reason_json` cru, `metrics_detail_json`. Razão: `score_value` existe mesmo quando `score_display` é null (Score ≤ 83) → vazá-lo quebra a regra de produto (Score só > 83).
4. **`selection_reason` sanitizado:** shape público (regra do Example + thresholds em linguagem pública), sem score interno nem lista de vídeos rejeitados. **Forma exata a alinhar Backend ⇄ Frontend ⇄ Security** (casa com o item aberto do `rls-review-notes` §6).

**Trava:** Fase 9 + read endpoint.

### 3.4 SEC-F11 (Baixa) — `/internal/*` por secret, constant-time, 404

1. Auth por **secret forte** em env (header `x-internal-secret` / bearer), **não** sessão de usuário.
2. **Comparação constant-time** (`crypto.timingSafeEqual`) — nunca `===` no segredo.
3. **404** (não 401/403) a secret ausente/errado — não revelar que a rota existe.
4. Secret aleatório forte, **rotacionável**; **provisionamento/rotação é DevOps** (§5).
5. Log: nunca o secret; só `run_id`/job id.

**Trava:** endpoints internos.

---

## 4. Escrita atômica evento + payload (confirmada)

| Operação | Escreve (uma transação) | Regra |
|---|---|---|
| **WTP** (`POST /api/wtp`) | `wtp_responses` (`response`,`price_range?`,`free_text?`) **+** `producer_events` (`wtp_*`) | ambos ou nenhum (`mvp-data-model.md` §`wtp_responses`: "Backend deve escrever ambos atomicamente") |
| **Intenção** (`.../intent`) | `producer_events` (`intent_to_produce_declared`) **+** `followups` (`pending`, `producer_event_id` = id do evento) | FK exige o evento primeiro → insere evento, pega id, insere follow-up, commit; falha → rollback total. Sem intenção órfã, sem follow-up sem origem |
| **Feedback** (`.../feedback`) | `producer_events` (`artist_marked_*`, com `report_item_id` resolvido) | escrita única |
| **Aprovação** (`PATCH .../status`) | `applications` (+ `producers.status`/`auth_user_id`) **+** `audit_events` **+** `producer_events` (`application_approved`) | uma transação; toda transição → `audit_events` (SEC-F14) |

Todo evento usa `producer_id` **da sessão** (SEC-F01).

### 4.1 Mecanismo de atomicidade (decisão de desenho — aciona Database)

PostgREST/cliente Supabase é **por statement**; dois `insert` em chamadas separadas **não** são atômicos. Portanto os pares (WTP, intenção, aprovação) passam por **função `plpgsql` (RPC)** que faz os dois `insert` na mesma transação. O handler Next:
1. autentica + deriva `producer_id` da sessão (SEC-F01);
2. valida payload (whitelist/zod);
3. chama a RPC com os campos já saneados.

A **DDL das funções é do Database**; o **contrato de chamada e a authz são do Backend**. → **revisão Database** para `fn_record_wtp`, `fn_declare_intent`, `fn_record_feedback`, `fn_decide_application` (nomes indicativos). As funções não substituem a checagem de ownership do handler — ela acontece **antes**, no Next.

---

## 5. Dependências e revisões cruzadas acionadas

| Para | O quê | Por quê |
|---|---|---|
| **DevOps** | **SEC-F10** — scrub de PII/secret no Sentry (email, `free_text`, `*_answer`, título, tokens, keys) | `02_` §10 exige eventos de erro; risco de logar PII/secret. Pré-produção. |
| **DevOps** | **SEC-F11** — provisionar/rotacionar o secret do cron + agendamento (OD-04) | secret forte em env; cron chama `/internal/followups/run-due`. |
| **Database** | Funções RPC atômicas (§4.1) + resolução `report_item_id` (§2-C) | DDL é do Database; atomicidade evento+payload. Matriz #2 (schema/eventos). |
| **Database + Security** | Forma exata da **VIEW pública** + `selection_reason` sanitizado (SEC-F03) | item aberto `rls-review-notes` §6; alinhar com Frontend. |
| **Security** | Re-review SEC-F01/F02/F03/F11 com evidência (handlers + testes) | levanta o gate da Fase 9 / endpoints. Silêncio ≠ aprovação. |
| **Product Orchestrator** | Achado **§2-E** (rota de resposta do follow-up ausente em `02_` §7) | completar a API surface; escopo MVP (loop de follow-up), não Fase 2. |
| **Product Lead (via PO)** | **OD-02 (Auth)** | desenho final de `/apply` pós-aprovação + sessão. Gargalo real da Fase 1. |

---

## 6. Critério de aceite desta revisão

- [x] **Backend confirma que o modelo serve os endpoints** de `02_` §7 (§1) — com 5 achados (§2), nenhum bloqueando o modelo de dados.
- [x] **Backend assume SEC-F01/F02/F03/F11 como contrato de implementação** não-negociável antes de Fase 1/9 e dos endpoints internos (§3).
- [x] **Escrita atômica evento+payload confirmada** (WTP, intenção, aprovação) com mecanismo definido (§4).
- [x] **DevOps acionado** para SEC-F10 e SEC-F11 (§5).
- [x] **Dependência OD-02** registrada e empurrada ao Product Lead via PO.

**Como o gate do Security cai (do meu lado):** entrego os handlers de `/apply` e de leitura do relatório **já** com SEC-F01/F02/F03 no código, e os `/internal/*` com SEC-F11, com testes que provem: (a) `producer_id` nunca vem do cliente; (b) `/apply` não seta campos fora da whitelist; (c) produtor lê só a VIEW; (d) `/internal/*` responde 404 sem secret e usa comparação constant-time. Esse é o pacote de evidência para o re-review do Security antes da Fase 9.

> **Não-negociável (alinhado a `CLAUDE.md` / `global-agent-rules`):** segurança desde o primeiro commit. SEC-F01/F02/F03/F11 entram no **desenho** dos handlers, não como "depois".
