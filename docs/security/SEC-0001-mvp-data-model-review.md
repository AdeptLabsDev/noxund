# SEC-0001 — Security & Privacy Review · Proposta de Modelo de Dados do MVP

- **Revisor:** Security & Privacy Agent (veto — `agent-conflict-resolution.md`, matriz #3)
- **Data:** 2026-06-20
- **Alvo:** `docs/database/` (`README.md`, `mvp-data-model.md`, `entity-relationship-notes.md`, `migration-plan.md`, `rls-review-notes.md`)
- **Base:** `02_...` §8–§9, `04_...`, `07_...`, `scope-guardrails` §"Decisões que exigem Security Review", `DEC-0003`.
- **Natureza do alvo:** **proposta em docs** — sem migration, sem schema Supabase, sem código. A revisão é sobre o modelo conceitual e as recomendações de RLS.

---

## 0. Veredito

**Aprovação condicional. Sem veto sobre o modelo conceitual** — ele é sólido, fiel a `04_` e já nasce com consciência de segurança (append-only, escrita por service-role, PII sinalizada, raw imutável).

**Mas o veto de Security permanece EXPLÍCITO sobre:**

1. **Fase 9 (RLS Policies)** do `migration-plan.md` — não avança sem o re-review de Security contra as condições SEC-F01..F06 abaixo.
2. **Qualquer migration ou endpoint que toque acesso/auth** (Fases 1, 4, 6, 8 + endpoints `/apply`, `/app/*`, `/admin/*`, `/internal/*`) — só com as mitigações desenhadas, não "prometidas".
3. **Gate de pré-produção** (antes de coletar PII real de produtor): SEC-F09 (LGPD/privacidade).

Tradução operacional: a proposta pode seguir para Data/AI + Backend e para a redação de migrations **com as condições incorporadas no desenho**. Nenhuma RLS/auth real entra em `main` sem eu revisar de novo. Bloqueio só cai com mitigação aceita por Security (`agent-conflict-resolution.md`).

---

## 1. Decisões que Security fecha agora (estão na minha alçada)

Estas não são recomendações — são decisões de segurança (auth/roles/RLS/secrets são owned por Security, `agent-boundaries.md`).

### SEC-D01 — OD-DB-08: identidade ≠ `producers.id = auth.uid()`
**Decisão: usar `auth_user_id uuid UNIQUE NULL` (FK lógica para `auth.users.id`) em `producers`. NÃO usar `producers.id = auth.uid()` como PK.**

Porquê (segurança, não preferência):
- O `/apply` é **anônimo**. A identidade de auth só deve ser provisionada **na aprovação** (convite/magic-link). Cravar `id = auth.uid()` obrigaria criar um usuário de auth para **todo** aplicante — inclusive não aprovados e spam — inflando a `auth.users`, ampliando superfície de ataque e abrindo enumeração de quem aplicou.
- Desacoplar "registro de aplicante" de "identidade autenticada" permite **rejeitar/bloquear sem nunca criar credencial**, e manter PII de aplicantes fora do subsistema de auth.
- RLS de produtor passa a ser `auth_user_id = auth.uid()` (mesma simplicidade), com `auth_user_id` preenchido **só** no momento da aprovação, por service-role, com `audit_events`.

Fecha OD-DB-08. **Database**: adicionar a coluna; **não** criar coluna de senha/hash em `producers` (identidade delegada ao Supabase Auth — SEC-F12).

### SEC-D02 — Modelo de role admin
**Decisão: admin derivado SOMENTE de fonte controlada por service-role. Tabela dedicada `admin_users` (uuid do auth) + helper `is_admin()` `SECURITY DEFINER` usado nas policies. Permitido alternativamente `app_metadata.role`, NUNCA `user_metadata`.**

Porquê: `user_metadata` no Supabase é **editável pelo próprio usuário** → derivar admin dali é escalonamento de privilégio crítico. Tabela dedicada dá auditabilidade (grant/revoke registrável em `audit_events`), revogação imediata e independência de refresh de JWT.

`admin_users` **não é tabela de marketplace** — é controle de segurança. **Database**: adicionar (aditivo, fora das 19; sem impacto de escopo — registrar). Fecha o ponto #6.1 do `rls-review-notes.md`.

### SEC-D03 — Imutabilidade de RAW e `audit_events` exige trigger (não é opcional)
**Decisão: `BEFORE UPDATE/DELETE` trigger que levanta exceção é OBRIGATÓRIO em `raw_youtube_*` e `audit_events` (e recomendado em `producer_events`).** Não só grants/RLS.

Porquê — este é o ponto mais importante e o `rls-review-notes.md` o subestima (item §3 "opcional"): **`service_role` faz BYPASS de RLS** (ver SEC-F01). Logo, "sem rota de UPDATE via RLS/grants" **não** torna o raw imutável — o service-role pode sobrescrever qualquer linha. Para as classes que o produto declara verdadeiramente imutáveis (raw sagrado, log de auditoria), a garantia precisa estar **abaixo** do service-role: trigger no banco. Eleva o "opcional" da proposta para **requerido** nessas duas/três tabelas.

---

## 2. Achados (severidade · mitigação exigida)

| ID | Sev | Achado | Mitigação exigida | Trava |
|---|---|---|---|---|
| **SEC-F01** | **Alta** | **`service_role` faz bypass de RLS.** Toda a proposta apoia escrita sensível em "via service-role server-side". Isso significa que **os handlers do servidor — não a RLS — são a fronteira real de autorização** nesses caminhos. RLS só protege `anon`/`authenticated`. | Documentar e exigir: **todo** caminho com service-role faz checagem de propriedade/role **em código** (`session.producer_id === payload.producer_id`; admin verificado por `is_admin()`). Sem isso → IDOR (produtor A forja evento/WTP/intent como produtor B). | Fase 9 + endpoints |
| **SEC-F02** | **Alta** | **`/apply` + mass-assignment.** `anon` "via server" está ambíguo. Se `anon` ganhar policy de INSERT direto, ou se o handler aceitar o corpo cru, um aplicante pode setar `status='approved'`, `reviewed_by`, `approved_at`, `auth_user_id` — e furar o approval gate (tese de validação). | `anon` com **zero grant direto** em qualquer tabela. `/apply` escreve **só** por handler server-side (service-role) com **whitelist estrita de campos** do aplicante (`email`, `display_name`, `youtube_url`, `portfolio_url`, `niche`, 2 respostas). `status` sempre forçado a `pending`/`submitted` no servidor. Rate limit anti-spam (`07_` quota/abuse). | Fase 1 + `/apply` |
| **SEC-F03** | **Alta** | **Exposição em nível de coluna.** `report_items` é legível por produtor aprovado e guarda `score_value` (valor interno **congelado mesmo quando `score_display` é null porque Score ≤ 83**), `raw_score` (via metric), `selection_reason_json`, `metrics_detail_json`. RLS do Postgres é **por linha**, não por coluna → produtor leria o Score que o produto decidiu esconder (regra `01_`/`03_`: Score só se > 83) e detalhes internos de metodologia. | Leitura de produtor passa por **VIEW** dedicada ou **GRANT SELECT (colunas)** expondo só o público (`score_display`, `tag`, `signals`, `velocity_display`, `competition_*`, `example_*`, `title`, `rank` + `selection_reason` sanitizado). **Nunca** `score_value`/`raw_score`/json interno completo ao produtor. | Fase 9 + read endpoint |
| **SEC-F04** | Alta | Identidade `auth.uid()` (OD-DB-08). | **Resolvido — SEC-D01** (`auth_user_id` FK). | Fase 1 |
| **SEC-F05** | Alta | Modelo de role admin (ponto #6.1). | **Resolvido — SEC-D02** (`admin_users` + `is_admin()`; nunca `user_metadata`). | Fase 9 |
| **SEC-F06** | Alta | Imutabilidade raw/audit depende só de grants/RLS (vulnerável a service-role). | **Resolvido — SEC-D03** (trigger obrigatório em `raw_youtube_*`, `audit_events`; recomendado em `producer_events`). | Fases 4/6/8 |
| **SEC-F07** | Média | **Least privilege em leitura de evento.** A proposta dá ao produtor `SELECT` no próprio `producer_events`. Não há necessidade de UI para o produtor ler o log cru. | Default-deny leitura de `producer_events`/`wtp_responses` para `producer`, salvo necessidade concreta justificada pelo Frontend. Estado de UI deriva server-side. | Fase 9 |
| **SEC-F08** | Média | **`jsonb` livre carrega risco.** `metadata` (events), `response` (followups), `raw_json`/`response_json` (raw) podem acumular PII além da devida, ou um segredo dumpado por engano. | `metadata`/`response` com shape restrito por `event_type`; **nenhum segredo/token** em qualquer `jsonb`; ao salvar payload do YouTube, **scrub** de contexto de request que possa conter a key. | Fases 4/6/7 |
| **SEC-F09** | Média | **LGPD/privacidade.** Fundador BR → LGPD aplica mesmo em beta fechado. Coleta-se email, URLs, respostas livres (`applications.*_answer`, `wtp_responses.free_text`) = PII. `rls-review-notes` deixou retenção/anonimização como "fora do MVP?". | **Antes de coletar PII real (pré-prod):** aviso de privacidade + base legal/consentimento na apply page (Frontend/Product); **caminho documentado de deleção manual** de PII por produtor (manual é aceitável no MVP); classificação de PII registrada. Não trava o doc; trava o lançamento. | Pré-produção |
| **SEC-F10** | Média | **Higiene de log concreta.** `02_` §10 exige eventos de erro (ex.: "tentativa de acesso sem aprovação", "falha de parsing de artista") — risco de logar email/título/free_text/token. | Logs referenciam `producer_id`/`run_id` (uuid), **nunca** email/free_text/title/keys/tokens. Scrubbing no Sentry (coord. DevOps). | Pré-produção |
| **SEC-F11** | Baixa | **Hardening de `/internal/*` (cron).** `02_` §9: protegido por secret, não sessão. | Secret forte aleatório em env; comparação **constant-time**; responder **404** (não 401) a secret ausente/errado. Coord. Backend/DevOps. | Endpoints internos |
| **SEC-F12** | Baixa (afirmação) | **Sem material de credencial em tabelas de app.** | Confirmado limpo: nenhuma coluna de senha/hash/secret nas 19 tabelas. Manter assim — identidade no Supabase Auth; keys (YouTube/service-role/email) só em env, nunca `NEXT_PUBLIC_*`, nunca no banco. | — |
| **SEC-F13** | Afirmação | **RLS habilitada + default-deny em TODAS as tabelas**, inclusive internas (raw/computed/audit), mesmo as que só o service-role toca. | Afirmado. Se um grant vazar para `authenticated` por engano, o default-deny ainda bloqueia. Defesa em profundidade. | Fase 9 |
| **SEC-F14** | Afirmação | **Publicação e transições de status são ações privilegiadas.** | Afirmado: `draft→published`, mudança de `producers.status`/`applications.status`, overrides → **só admin** + `audit_events`. Draft **nunca** legível por produtor. Leitura de relatório exige `status='published'` **E** produtor `approved`. | Fase 9 |

---

## 3. Fora da alçada de Security (sem objeção)

`OD-DB-01` (split de runs), `OD-DB-02`/`OD-DB-05` (nomes — já fechados em `DEC-0003`), `OD-DB-04` (mapping vs event-log), `OD-DB-06`/`OD-DB-07` (proveniência por célula). São metodologia/escopo → **Data/AI + Product Orchestrator**. **Security não tem objeção de segurança a nenhuma das opções.** Observo apenas que SEC-F03 melhora com `report_items.artist_metric_id` (OD-DB-06): a separação metric↔snapshot facilita expor ao produtor só o snapshot público e manter o detalhe interno em `artist_metrics` (admin/server).

---

## 4. Checagem de escopo/secrets (visão de segurança)

- **19 tabelas + `admin_users` (segurança):** nenhuma tabela de marketplace/Fase 2 (`04_` §12 / `scope-guardrails`). Verificado. Nenhuma expande a promessa do produto.
- **Secrets:** nenhuma coluna portadora de segredo proposta. Nenhum `NEXT_PUBLIC_*` sensível implícito. Sem objeção.

---

## 5. Handoff (formato `handoff-template.md` — ênfase: risco/severidade/mitigação/veto)

**Resultado:** proposta de modelo de dados **aprovada condicionalmente** por Security. Modelo conceitual sólido; **veto mantido** sobre RLS (Fase 9), migrations/endpoints de acesso e gate de pré-produção, até as mitigações estarem **no desenho**.

**Decisões de Security (fechadas):** SEC-D01 (`auth_user_id` FK, não `id=auth.uid()`), SEC-D02 (`admin_users` + `is_admin()`, nunca `user_metadata`), SEC-D03 (trigger de imutabilidade obrigatório em raw/audit).

**Riscos abertos que travam:** SEC-F01 (service-role bypassa RLS → authz em código), SEC-F02 (mass-assignment no `/apply`), SEC-F03 (exposição de coluna interna ao produtor). Estes três são **Alta** e são pré-condição para Fase 9 / endpoints.

**Pré-produção:** SEC-F09 (LGPD), SEC-F10 (log hygiene).

**Revisões cruzadas acionadas:** Database (SEC-D01/D02/D03 + colunas/triggers/view), Backend (SEC-F01/F02/F03/F11 — authz em código, whitelist, view de leitura, cron), Data/AI (sem objeção; nota SEC-F03↔OD-DB-06), DevOps (SEC-F10/F11 — Sentry scrub, secret do cron).

**Como Security levanta o veto:** re-review desta lista quando (a) o desenho de RLS da Fase 9 incorporar SEC-F01..F06 e SEC-F13/F14, e (b) o handoff da migration trouxer evidência (policies + triggers + view + checagens de ownership). Silêncio de Security ≠ aprovação (`agent-conflict-resolution.md`).

**Próximo passo recomendado:** Database incorpora SEC-D01/D02/D03 ao `mvp-data-model.md`; Backend desenha os handlers de `/apply` e leitura de relatório já com SEC-F01/F02/F03; só então abrir Fase 1 (migration `producers`+`applications`) com revisão **Database + Security**.
