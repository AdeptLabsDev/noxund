# RLS & Security Review Notes — NOXUND MVP

**Status:** recomendações iniciais. **Não são políticas SQL finais.** Para o **Security & Privacy Agent** revisar e fechar (Security é co-owner de RLS e tem poder de veto — `security-privacy-agent.md`, matriz #3).
**Base:** `02_...` §9, `04_...`, `scope-guardrails` §"Decisões que exigem Security Review".

Database propõe; **Security decide e pode bloquear**. Nada aqui é "assumido como ok".

---

## 1. Roles assumidas (a confirmar com Security)

| Role | Quem | Acesso (alto nível) |
|---|---|---|
| `anon` | visitante não autenticado | só `POST /apply` (via server), nada de leitura direta |
| `producer` (authenticated) | produtor logado | seus próprios dados + relatórios **publicados** se `approved` |
| `admin` | operador NOXUND | aplicações, métricas, publicação, overrides |
| `service_role` | pipeline/server-side | escrita de raw/computed/eventos; **nunca exposta ao cliente** |

Pré-requisito: **RLS habilitado (`ENABLE ROW LEVEL SECURITY`) em todas as tabelas**; default deny. Ligação de identidade: `producers.id = auth.uid()` ou FK `auth_user_id` (OD-DB-08).

---

## 2. Recomendações por requisito da tarefa

### 2.1 Produtor só acessa o próprio acesso/eventos
- `producer_events`, `followups`, `wtp_responses`, `applications`: `SELECT` apenas onde `producer_id = auth.uid()`.
- `producer_events`/`wtp_responses`: **`INSERT` via server/service-role**, não direto do cliente — evita produtor forjar eventos de validação (intent/WTP) que distorcem métricas.
- Sem `UPDATE`/`DELETE` para `producer` em nenhuma dessas (append-only).

### 2.2 Produtor aprovado acessa relatórios publicados
- `reports`: `SELECT` só onde `status = 'published'` **e** o produtor é `approved` (`producers.status = 'approved'`).
- `report_items`: `SELECT` só se o `report` pai está `published` e o produtor é `approved`.
- Produtor **nunca** vê `draft`/`archived`.

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

## 3. Imutabilidade reforçada por permissão (não só convenção)

| Classe | Garantia recomendada |
|---|---|
| RAW (`raw_youtube_*`) | Sem `GRANT UPDATE/DELETE` a nenhum role de app; só `INSERT` por `service_role`. Opcional: trigger `BEFORE UPDATE` que levanta exceção. |
| EVENT (`producer_events`, `audit_events`) | Sem `UPDATE`/`DELETE` para ninguém via API; append-only. |
| SNAPSHOT (`report_items`, `reports` publicados) | Após `published`, sem `UPDATE` de conteúdo; só transição `published → archived` por admin. |

A imutabilidade do raw e do snapshot **não pode depender só do código de app** — deve ser garantida na camada de permissão/RLS.

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

## 6. Pontos que exigem decisão do Security Agent

1. Ligação identidade ↔ `auth.uid()` (OD-DB-08) e modelo de role admin (claim vs tabela `admins`).
2. `INSERT` de `producer_events`/`wtp_responses`: via service-role server-side (recomendado) vs RLS permitindo o próprio produtor inserir só os seus.
3. Política exata de `audit_events` (admin-only confirmado) e se `actor_id` pode ser nulo para ações de pipeline.
4. Estratégia de imutabilidade RAW: grants apenas vs grants + trigger defensivo.
5. Retenção/anonimização de PII pós-validação (fora do MVP? registrar como follow-up).

---

## 7. Status

⏳ **Pendente de Security & Privacy Agent.** Esta proposta de RLS **não está aprovada** até o Security revisar e (se for o caso) levantar/baixar veto com mitigação. Migration de RLS (Fase 9 do `migration-plan.md`) só avança com esse aval (matriz #3).
