# INFRA-0002 — `configure_env` + arm do Environment `youtube-collection` (SG-4)

- **Task:** `task_devops_configure_env_youtube_collection` · **Action:** `configure_env` (SENSÍVEL/humano-gated)
- **Owner agent:** `devops_agent` · **Co-assina:** Security (matrix #8)
- **Data:** 2026-07-02
- **Alvo:** projeto Supabase `pwbkplzyzmortwjjpcbg` (`us-east-1`) · YouTube Data API v3 (`channels.list`) · **novo** GitHub Environment `youtube-collection`
- **Gate:** **SG-4** de DEC-0018 / SEC-0020. Precedente de forma: `INFRA-0001` (env credenciado da Fase 1).
- **Estado:** **PLANO — não executa.** Zero secret provisionado, zero valor de secret, zero arm, zero dispatch, zero coleta. Este doc é o **contrato de provisionamento**; a injeção do valor real da key, o commit do arm marker e o dispatch são a **fronteira humana** (SG-6).

---

## 0. O que este documento é (e o que NÃO é)

É o **contrato do Environment `youtube-collection`** e do **ato de arm** que torna o pipeline `youtube-collection.yml` live-capable. Especifica:

1. os **artefatos versionados** (todos **sem secret**);
2. as **referências de secret/variable** (apenas **nomes**) a popular no Environment;
3. a **ordem de setup** das protection rules (a ordem importa — SEC-F18);
4. o plano **F-1** (restrição da key + alerta de quota + rotação);
5. a **confirmação OQ-2** (ausência de `FORCE RLS`; caminho de escrita least-privilege);
6. o **checklist de pré-arm** (§6) — o gate que precede o commit do marcador `.armed`.

**NÃO** contém valores de secret (só **nomes**). **NÃO** provisiona nada. **NÃO** cria `.github/collection/youtube-collection.armed`. **NÃO** dispara coleta. Os **valores** são injetados **out-of-band pelo Product Lead**, direto no cofre/CI, com evidência exigida (§6).

> **Non-negotiable (global rule #10 / onboarding §8.6):** secret nunca entra em payload, arquivo versionado, log ou contexto do Orchestrator. A `YOUTUBE_API_KEY` é a **1ª credencial portadora de custo** do CI (abuso = queima de quota/billing) — trato F-1 abaixo.

---

## 1. Artefatos versionados (sem secret)

| Artefato | Caminho | Papel | Estado |
|---|---|---|---|
| Pipeline gated | `.github/workflows/youtube-collection.yml` | Guard → collect → verify. Manual-only, fail-closed, **F-3 hardened** nesta entrega. | ✅ landado, **desarmado** |
| Collector (SG-5) | `services/data-engine/src/noxund_data_engine/channel_collection.py` | `channels.list` → INSERT em `raw_youtube_channels`. | ⬜ ausente (SG-5) |
| Testes §8 (SG-5) | `services/data-engine/tests/test_channel_collection.py` | §8.1–§8.6 (body-vs-envelope, CHECK/scrub, canary, quota fail, retry, DC2-01). | ⬜ ausente (SG-5) |
| Gate §7 (SG-5/7) | `supabase/tests/channel_data_post_collection_verify.sql` | Set-equality canais↔vídeos pós-coleta. | ⬜ ausente (SG-5) |
| **Arm marker** | `.github/collection/youtube-collection.armed` | Habilita o preflight de arm. Sua **ausência = desarmado**. | ⛔ **NÃO criado** (ato consciente do DevOps em SG-4, após §6 verde) |

Nenhum arquivo carrega credencial. O único literal no YAML é `SUPABASE_PROJECT_REF` (`pwbkplzyzmortwjjpcbg`) — **não-secret** (aparece na URL pública do projeto). A pipeline referencia secrets **por nome** via `secrets.*` / `vars.*`.

---

## 2. Referências de secret/variable a popular (NOMES, não valores)

Tudo abaixo vive **exclusivamente** no **GitHub Environment `youtube-collection`** (Settings → Environments). Populado **out-of-band pelo Product Lead**. Zero valor neste repo.

### 2.1 Secrets (Environment **secrets**)

Apenas **dois** secrets — least-privilege (SEC-F19). **`SUPABASE_ACCESS_TOKEN` NÃO entra** (o job não faz `db push`); **`SUPABASE_SERVICE_ROLE_KEY` NÃO entra** (bypass total de RLS — o secret de maior raio de explosão fica fora do CI).

| Nome (`secrets.*`) | Uso | Least-privilege / origem |
|---|---|---|
| `YOUTUBE_API_KEY` | Injetada no collector como env var; enviada como header `X-Goog-Api-Key` (never `?key=`). | GCP → APIs & Services → Credentials. **Restrição F-1 obrigatória (§4)**. Portadora de custo. |
| `SUPABASE_DB_PASSWORD` | String de conexão do `psql`/collector (session pooler, owner `postgres`). | Dashboard → Project → Database → Password. Único secret embutido na connection URL (mascarada em runtime via `::add-mask::`). |

> **SEC-F19 — service-role fora do CI.** A escrita usa o owner `postgres`/DB-password (§5). A `SUPABASE_SERVICE_ROLE_KEY` **não** é provisionada. Se já existir neste Environment, **removê-la** (§6).
>
> **OQ-1 — sem `SUPABASE_ACCESS_TOKEN`.** Este Environment é deliberadamente **incapaz de `db push`**: nunca compartilha blast radius com o token de migration do `production-db`. Não reusar `production-db`.

### 2.2 Coordenadas de conexão (Environment **variables** — NÃO são secret)

Separar as coordenadas não-secretas reduz o secret de DB a **um só** valor (a senha). Copiar do dashboard → Project → Database → **Connection string → Session pooler** (mesmas coordenadas do `production-db` — mesmo projeto).

| Nome (`vars.*`) | Exemplo | Nota |
|---|---|---|
| `SUPABASE_DB_HOST` | `aws-0-us-east-1.pooler.supabase.com` | **Session pooler** (IPv4) — runners do GitHub são IPv4; host direto `db.<ref>.supabase.co` é IPv6-only e falha. |
| `SUPABASE_DB_PORT` | `5432` | Session mode. **Não** usar o transaction pooler `6543`. |
| `SUPABASE_DB_USER` | `postgres.pwbkplzyzmortwjjpcbg` | Usuário do pooler. Default no YAML: `postgres.<ref>` (L207/263). |

---

## 3. Gate de execução + ordem de setup (a ordem importa — SEC-F18)

O run real é gated em **duas camadas humanas**: (a) dispatch manual + frase de confirmação + acknowledge de irreversibilidade (SG-6, `guard`); (b) **required reviewers** do Environment (DevOps + Security) — aprovação humana em tempo de execução, nos jobs `collect` e `verify`.

**Setup no GitHub (Product Lead/DevOps, fora do repo) — a ORDEM é vinculante (SEC-F18):**

1. `Settings → Environments → New environment → **youtube-collection**`.
2. **Deployment branch rules → restringir a `main`** — **ANTES** de adicionar qualquer secret. Um Environment **novo** referenciado sem esta regra é auto-criado **sem** proteção; um `workflow_dispatch` de branch arbitrária acessaria os secrets. *(O `guard` já tem um backstop `github.ref == refs/heads/main` que **não depende** desta regra — mas a branch rule é a 2ª camada obrigatória.)*
3. **Required reviewers = DevOps + Security** (agent-review-matrix.md #8).
4. **Só então** adicionar os **secrets** (§2.1) e as **variables** (§2.2).

Os passos 2–4 exigem **evidência out-of-band** (screenshot/confirmação) anexada ao co-sign de Security — não verificável no repo (§6).

---

## 4. F-1 — restrição da `YOUTUBE_API_KEY` + alerta de quota + rotação

Condição **bloqueante** de SG-4 (SEC-0019 / SEC-0020 §5). Ato de console GCP, **out-of-band**, evidência exigida.

### 4.1 Restrição de API (obrigatória)
- GCP Console → **APIs & Services → Credentials → [a key] → API restrictions → Restrict key → selecionar SOMENTE `YouTube Data API v3`**. A key não pode chamar nenhuma outra API Google.
- **Application restriction:** runners do GitHub **não têm IP de egress estático** → restrição por IP é inviável (registrar como aceito, não aplicável). A restrição de **API** acima é a mitigação primária; a segunda camada é o transporte por header + higiene de log (`X-Goog-Api-Key`, never `?key=` — OQ-6, já no YAML L48–50).

### 4.2 Alerta de quota
- GCP → **APIs & Services → YouTube Data API v3 → Quotas & System Limits** → alerta em fração da quota diária default (**10.000 unidades/dia/projeto**).
- **Contexto de custo real (runbook §6):** uma run consome ~**1010** unidades (dominada por `search.list` ~1000); o **delta desta coleta** (`channels.list`, 1 unidade/chamada, lotes ≤50) é **≤ ~10 unidades/run**. Um alerta bem abaixo do teto diário detecta abuso/loop muito antes de billing.

### 4.3 Política de rotação / revogação (SEC-F20)
- **Gatilhos de rotação:** (a) **pós-run** relevante, (b) **troca de pessoal**, (c) **periódica ≤ 90 dias**, (d) **suspeita de leak** (rotacionar **antes** de qualquer novo run e invalidar runs em andamento).
- Keys **temporárias/de teste** → **revogar imediatamente** após o uso.
- Após rotação, **atualizar o secret** `YOUTUBE_API_KEY` no Environment.
- **Pós-provisionamento:** remover do Environment todo secret não mais necessário.

---

## 5. Confirmação OQ-2 — ausência de `FORCE RLS` + caminho de escrita least-privilege

**Confirmado em repo (fato de banco, não só de YAML):**

- A migration Fase 4 `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (L177–186) faz `enable row level security` + `revoke all ... from anon, authenticated` nas 3 raw tables, com **zero policies** — e **nenhum** `FORCE ROW LEVEL SECURITY` em ponto algum das migrations (verificado por varredura no repo; todas as menções a "FORCE RLS" são de **ausência**).
- **Database ratificou** (OQ-2) — `docs/database/HANDOFF-channel-data-collection-review.md §2.5`: sem `FORCE RLS`, o owner `postgres` **ignora RLS** e pode `INSERT`; `UPDATE/DELETE/TRUNCATE` seguem barrados pelos triggers de imutabilidade. Caminho recomendado = **`postgres`/DB-password (session pooler)**, consistente com SEC-F19 (service-role fora do CI).
- **Security ratificou** — SEC-0019 (SEC-F19) e SEC-0020 §7: o YAML usa o caminho owner `postgres` (`DB_USER` default `postgres.<ref>`, L207/263) e **não** usa service-role. Consistente com a postura acordada.

**Escopo do termo "least-privilege" (honestidade):** aqui significa **minimização do conjunto de secrets** do Environment (sem token de migration, sem service-role key), não um role de banco reduzido — o papel de escrita continua sendo o owner `postgres`, exatamente como os verify scripts já operam (decisão ratificada OQ-2). Um **role dedicado INSERT-only** nas raw tables é um endurecimento **futuro possível, de domínio Database** (mudança de role/grant) — **fora do escopo de SG-4 e não exigido** por este gate. Nenhuma mudança de schema é necessária para provisionar este Environment.

---

## 6. CHECKLIST DE PRÉ-ARM — tudo VERDE antes de committar `.github/collection/youtube-collection.armed`

O marcador `.armed` é committado por DevOps como **ato consciente** — a **ausência** é o estado desarmado. **Silêncio ≠ aprovação.** Committar antes de qualquer item abaixo é violação de gate.

| # | Item | Responsável | Verificação | Estado |
|---|---|---|---|---|
| **1** | **F-3 aplicado** — guard sem `${{ inputs.* }}`/`${{ github.ref }}` em `run:` (env:-indireção; padrão `collect`/`verify`) | DevOps | **em repo** (grep: zero `${{ }}` em `run:` do guard) | ✅ **verde** (esta entrega) |
| **2** | **OQ-2 confirmado** — sem `FORCE RLS` + caminho `postgres`/DB-password | Database + Security | **em repo** (§5) | ✅ **verde** |
| **3** | **Environment provisionado** — branch rule `main` **1º** → required reviewers (DevOps+Security) → **então** secrets/vars (§3) | DevOps + Product Lead | **out-of-band** (screenshots §3) | ⬜ pendente |
| **4** | **F-1 aplicado** — key restrita à YouTube Data API v3 + alerta de quota + política de rotação (§4) | DevOps + Security | **out-of-band** (screenshots §4) | ⬜ pendente |
| **5** | **SG-5 landado** — collector + testes §8.1–§8.6 + verify SQL presentes | Data/AI + Security | **em repo** (o preflight de arm do `guard` também checa a existência dos 4 arquivos) | ⬜ pendente |
| **6** | **Security co-assina SG-4** — herda SEC-0020 para o YAML; audita as protection rules/secret handling do Environment | Security | co-sign anexado | ⬜ pendente |

**Só com 1–6 verdes:** DevOps commita `.github/collection/youtube-collection.armed`. **Mesmo armado**, o gate humano do Environment (required reviewers) continua valendo em **cada** `collect`/`verify` (SG-6). O arm marker é condição **necessária, não suficiente**.

---

## 7. Estado e próximo passo

- **Entregue nesta task (SG-4 — preparação):** F-3 hardening no YAML (desarmado); este contrato de provisionamento (§1–§5); plano F-1 (§4); confirmação OQ-2 (§5); checklist de pré-arm (§6). **Zero secret provisionado; `.armed` NÃO committado; nenhum dispatch.**
- **Fronteira humana (fora desta entrega):** injeção dos valores de secret + protection rules (§3), F-1 no console GCP (§4), co-sign de Security, e o **commit consciente do arm marker** — só após §6 verde. O **dispatch** real (SG-6) é ato humano separado, com required reviewers.
- **Vetos intransponíveis (não tocados):** Fase 9 / RLS Policies (raw default-deny); `0007`/producer_events **PARKED**; publish barrado até **P5-REPRO-01** (SG-8).

> Nada roda até §6 verde **e** um humano disparar o run gated com aprovação dos required reviewers. Este documento é plano, não execução.
