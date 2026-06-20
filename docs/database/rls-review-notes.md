# RLS & Security Review Notes — NOXUND MVP

**Status:** recomendações **revisadas pelo Security** (`docs/security/SEC-0001-mvp-data-model-review.md`). Ainda **não são políticas SQL finais** — Fase 9 (RLS) tem **veto mantido** do Security até o re-review com as condições no desenho.
**Base:** `02_...` §9, `04_...`, `scope-guardrails` §"Decisões que exigem Security Review", **SEC-0001**.

Database propõe; **Security decide e pode bloquear**. Nada aqui é "assumido como ok".

> **Decisões fechadas pelo Security (SEC-0001 §1) já incorporadas abaixo:**
> - **SEC-D01** — identidade via `auth_user_id uuid unique null` (FK lógica → `auth.users`), **não** `producers.id = auth.uid()`; sem hash de senha em `producers`.
> - **SEC-D02** — admin via tabela `admin_users` + helper `is_admin()` `SECURITY DEFINER`; **nunca** `user_metadata`.
> - **SEC-D03** — trigger `BEFORE UPDATE/DELETE` **obrigatório** em `raw_youtube_*` e `audit_events` (recomendado em `producer_events`).
> - **SEC-F01 (estrutural)** — `service_role` faz **bypass de RLS**: nos caminhos service-role, a fronteira de authz é o **código do handler**, não a RLS.

---

## 1. Roles assumidas (a confirmar com Security)

| Role | Quem | Acesso (alto nível) |
|---|---|---|
| `anon` | visitante não autenticado | só `POST /apply` (via server), nada de leitura direta |
| `producer` (authenticated) | produtor logado | seus próprios dados + relatórios **publicados** se `approved` |
| `admin` | operador NOXUND | aplicações, métricas, publicação, overrides |
| `service_role` | pipeline/server-side | escrita de raw/computed/eventos; **nunca exposta ao cliente** |

Pré-requisito: **RLS habilitado (`ENABLE ROW LEVEL SECURITY`) + default-deny em TODAS as tabelas** (SEC-F13), inclusive as internas só-service-role (defesa em profundidade). Ligação de identidade: **`auth_user_id = auth.uid()`** (SEC-D01). Admin via `is_admin()` lendo `admin_users` (SEC-D02).

> **Atenção (SEC-F01):** RLS protege `anon`/`authenticated`. **`service_role` ignora RLS.** Toda escrita/leitura sensível feita por handler service-role exige checagem de propriedade/role **em código** (`session.producer_id === payload.producer_id`; admin por `is_admin()`), senão há IDOR (produtor A forja intent/WTP como B). Isto é pré-condição da Fase 9 e dos endpoints.

---

## 2. Recomendações por requisito da tarefa

### 2.1 Produtor só acessa o próprio acesso/eventos
- Vínculo de propriedade via `producers.auth_user_id = auth.uid()` (SEC-D01), não `producer_id` direto do cliente.
- `producer_events`/`wtp_responses`: **`INSERT` via server/service-role** com **checagem de ownership em código** (SEC-F01) — evita produtor forjar intent/WTP de outro (IDOR).
- **SEC-F07 (least privilege):** **default-deny na leitura** de `producer_events`/`wtp_responses` pelo `producer` — não há UI que precise do log cru; estado de UI deriva server-side. Liberar `SELECT` só com necessidade concreta justificada pelo Frontend.
- Sem `UPDATE`/`DELETE` para `producer` em nenhuma dessas (append-only).

### 2.2 Produtor aprovado acessa relatórios publicados
- `reports`: `SELECT` só onde `status = 'published'` **e** o produtor é `approved` (`producers.status = 'approved'`).
- `report_items`: `SELECT` só se o `report` pai está `published` e o produtor é `approved`.
- **SEC-F03 (bloqueante — exposição de coluna):** RLS é por linha, não por coluna. A leitura do produtor passa por **VIEW pública dedicada** (ou `GRANT SELECT` por coluna) expondo só `title`, `rank`, `tag`, `score_display`, `signals`, `velocity_display`, `competition_*`, `example_*` + `selection_reason` sanitizado. **Nunca** `score_value`/`raw_score`/`selection_reason_json` cru/`metrics_detail_json` — senão o Score escondido (≤ 83) vaza.
- Produtor **nunca** vê `draft`/`archived` (SEC-F14).

### 2.3 Admin acessa aplicações e métricas
- `applications`, `audit_events`, `artist_metrics`, `producer_events` (agregados de métrica): `SELECT`/`UPDATE` (status) só para `admin`.
- Mudança de status (`applications`, `producers`) só por `admin`, sempre gravando `audit_events`.

### 2.4 Service role só server-side
- Escrita em RAW (`raw_youtube_*`), COMPUTED (`video_artist_mappings`, `channel_eligibility`, `artist_metrics`) e publicação de `reports`/`report_items`: **só `service_role`**.
- `service_role` nunca no bundle do frontend nem em rota pública (`02_...` §9).

### 2.5 YouTube API key nunca no frontend
- Fora de RLS, mas crítico: `YOUTUBE_API_KEY` só no ambiente do data-engine/server (Data/AI a consome via Security). Nunca em `NEXT_PUBLIC_*`, nunca em log (`scope-guardrails` Security Review).
- Idem `service_role` do Supabase e credenciais de email.

### 2.6 Eventos sensíveis não devem ser públicos
- `audit_events`: `SELECT` só `admin`/`service_role`. Contêm decisões e overrides — nunca para `producer`/`anon`.
- `producer_events`: visível ao próprio produtor só o que for dele; agregação de métrica é admin/server. Telemetria de outro produtor nunca cruza.

---

## 3. Imutabilidade reforçada por trigger (SEC-D03 — não é opcional)

**Por que grants/RLS não bastam (SEC-F01):** `service_role` faz **bypass de RLS**. Como toda escrita de raw/computed/evento passa por handlers service-role, "sem rota de UPDATE via RLS/grants" **não** torna o raw imutável — o service-role pode sobrescrever qualquer linha. Para as classes que o produto declara **verdadeiramente imutáveis** (raw sagrado, log de auditoria), a garantia precisa estar **abaixo** do service-role: **trigger no banco**.

| Classe | Garantia **requerida** |
|---|---|
| RAW (`raw_youtube_*`) | Sem `GRANT UPDATE/DELETE` a role de app; só `INSERT` por `service_role`. **+ trigger `BEFORE UPDATE/DELETE` que levanta exceção — OBRIGATÓRIO (SEC-D03).** |
| `audit_events` | Append-only **+ trigger `BEFORE UPDATE/DELETE` — OBRIGATÓRIO (SEC-D03).** |
| `producer_events` | Append-only; **trigger de imutabilidade recomendado (SEC-D03)** — protege as métricas-norte de sobrescrita. |
| SNAPSHOT (`report_items`, `reports` publicados) | Após `published`, sem `UPDATE` de conteúdo; só transição `published → archived` por admin + `audit_events`. Trigger de guarda recomendado para barrar update de item de report publicado. |

A imutabilidade do raw/audit **não pode depender só do código de app nem só de RLS** (service-role bypassa) — trigger no banco é a camada que sobrevive ao service-role.

---

## 4. PII e privacidade (`02_...` §9, backlog [SEC] privacidade)

- PII vive em `producers` (`email`, URLs) e `applications` (respostas). Acesso só server/admin.
- **Logs sem PII, sem tokens, sem keys.** Eventos de produto no Postgres podem referenciar `producer_id` (uuid), não email.
- `wtp_responses.free_text` e `applications.*_answer` podem conter texto livre sensível → tratar como PII.

---

## 5. Endpoints e jobs (contexto para RLS, owner Backend/Security)

- `/app/*` exige autenticação **e** `approved` (`02_...` §7, §9).
- `/admin/*` só `admin` role.
- `/internal/*` (followups/coleta) protegido por **secret**, não por sessão de usuário (`02_...` §7; matriz: internal jobs → Security + DevOps).
- Rate limiting básico em `POST /apply` (anti-spam) — backlog [SEC].

---

## 6. Pontos decididos pelo Security (SEC-0001) e o que resta

**Fechados (não reabrir sem nova DEC do Security):**
1. Identidade ↔ `auth_user_id` (SEC-D01); role admin via `admin_users` + `is_admin()` (SEC-D02).
2. `INSERT` de `producer_events`/`wtp_responses`: **via service-role server-side com checagem de ownership em código** (SEC-F01).
3. `audit_events`: admin/service-role only; `actor_id` pode ser nulo para `actor_type='pipeline'|'system'` (SEC-0001 §2 SEC-F08 nota).
4. Imutabilidade RAW/audit: **grants + trigger obrigatório** (SEC-D03) — não "grants apenas".

**Resta desenhar/decidir antes da Fase 9 (re-review do Security):**
- Forma exata da VIEW pública de `report_items` (SEC-F03) e do `selection_reason` sanitizado — alinhar com Frontend/Backend.
- `app_metadata.role` como alternativa a `admin_users` (ambos aceitos por Security; escolher um).
- **Pré-produção (não trava o doc):** SEC-F09 (LGPD: base legal/consentimento na apply page + caminho de deleção manual de PII), SEC-F10 (scrubbing de log no Sentry — DevOps).

---

## 7. Status

⚠️ **Revisado pelo Security — aprovação condicional, veto mantido (SEC-0001).** O modelo conceitual de RLS está aceito; a **Fase 9 (RLS) não entra em `main`** sem o re-review do Security contra SEC-F01/F02/F03 + SEC-F13/F14 no desenho, com evidência (policies + triggers + view + checagens de ownership). Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).
