# SEC-0021 — Security CO-SIGN (audit_secrets) · Environment `youtube-collection` protection + secret handling (SG-4)

- **Task:** `task_security_cosign_configure_env_youtube_collection` · **Action:** `audit_secrets` (co-sign of DevOps `configure_env`) · **Agent:** `security_agent`
- **Data:** 2026-07-02
- **Matriz:** `agent-review-matrix.md` **#8** (deploy/mudança de ambiente → DevOps + Security). Precedente de forma: **INFRA-0001** (env credenciado da Fase 1) e seu co-sign **SEC-0005/SEC-0006**.
- **Gate:** **SG-4** de DEC-0018. Item **#6** do checklist de pré-arm de `INFRA-0002 §6`.
- **Alvos revisados (design/config audit — NÃO toquei GitHub/GCP):**
  - `docs/infra/INFRA-0002-youtube-collection-env.md` (contrato de `configure_env`/arm)
  - `docs/infra/HANDOFF-configure-env-youtube-collection.md`
  - `.github/workflows/youtube-collection.yml` (guard F-3 aplicado; desarmado)
  - `docs/security/SEC-0020-youtube-collection-pipeline-audit.md` (auditoria do YAML que HERDO)
  - `docs/security/SEC-0019-channel-data-collection-review.md` (SG-1) · `docs/security/SEC-0016-collection-spec-secrets-audit.md` (SEC-F23)
  - `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (RLS/CHECK das raw tables)
- **Mandato:** **AUDIT-ONLY.** Não provisiono o Environment, não injeto/echo/print valor de secret, não crio `.armed`, não dispatch, não rodo coleta, não toco GCP/GitHub. Poder de veto. **Silêncio ≠ aprovação. Zero valor de secret neste doc.** O que não puder ser verificado do repo é marcado **OPEN** (evidência out-of-band exigida), nunca assumido PASS.

---

## 0. Veredito

✅ **CO-SIGN COM CONDIÇÕES.** A preparação de SG-4 entregue pelo DevOps (F-3 no YAML + `INFRA-0002`) é **corretamente desenhada** e, onde o repo permite verificar, **verde por construção**: F-3 fechado (zero `${{ }}` em `run:` do guard), superfície de secret mínima (apenas os dois secrets nomeados), OQ-2 confirmado em banco, pipeline **desarmado por construção**, e o checklist de pré-arm §6 completo com toda ação sensível atrás da fronteira humana. **Herdo SEC-0020** para o YAML e confirmo que o único finding aberto daquela auditoria (**F-3**) está **fechado** nesta entrega.

⛔ **Este doc NÃO arma nem autoriza run.** O provisionamento real do Environment (ordem SEC-F18), a injeção dos valores de secret e o F-1 no console GCP são **atos humanos out-of-band** que eu **não posso verificar do repo** — ficam **OPEN**, condicionados a **evidência out-of-band** anexada antes do arm. Co-assino a **preparação e o plano**; as condições **C1–C5** (§7) devem estar **verdes com evidência** antes que um humano commite `.armed`, injete secret ou dispare o run.

**Calibração honesta:** dos 5 itens do meu escopo, **3 são PASS repo-verificável** (F-3/disarmed, superfície de secret no YAML, OQ-2) e **2 são PASS-de-design + OPEN-de-execução** (ordem SEC-F18 e F-1 no GCP — desenho correto, execução não verificável aqui). Nenhum **FINDING** novo bloqueante contra a entrega do DevOps.

---

## 1. Item 1 — Ordem de proteção do Environment (SEC-F18) → ✅ PASS (design + backstop no YAML) · ⏳ OPEN (execução out-of-band)

**Exigência:** a branch rule (`main`-only) deve ser aplicável **ANTES** que qualquer secret exista; required reviewers = DevOps + Security; nenhum secret pode ser alcançável de um ref não-`main`.

| Sub-controle | Veredito | Evidência |
|---|---|---|
| Ordem de setup documentada corretamente | ✅ PASS (design) | `INFRA-0002 §3`: (1) criar Environment → (2) **branch rule `main`-only ANTES de qualquer secret** → (3) required reviewers DevOps+Security → (4) **só então** secrets/vars. A ordem é declarada **vinculante** (SEC-F18) e a §3 explica o footgun (Environment novo auto-criado **sem** proteção se referenciado antes da regra). |
| **Nenhum secret alcançável de ref não-`main`** (independe da branch rule existir) | ✅ **PASS (repo-verificável)** | O `guard` (job sem `environment`/secret) roda o backstop `DISPATCH_REF != refs/heads/main → exit 1` (YAML L135–153, via `env:`). `collect`/`verify` têm `needs: guard` (L198/L257) → se o guard falha, **nunca** tocam secret. Logo um dispatch de branch arbitrária **não alcança** `YOUTUBE_API_KEY`/`SUPABASE_DB_PASSWORD` mesmo que a branch rule ainda não exista. Defesa-em-profundidade real, não dependente de provisionamento. |
| Required reviewers = DevOps + Security | ✅ PASS (design) · ⏳ OPEN (execução) | `INFRA-0002 §3` passo 3 + `collect`/`verify` com `environment: youtube-collection` (L202/L259) → aprovação humana em runtime. A **existência efetiva** dos reviewers no Environment é out-of-band. |
| Branch rule `main`-only como **2ª camada** efetivamente aplicada | ⏳ **OPEN** | Não verificável do repo (Settings → Environments). Exige evidência out-of-band (screenshot §3, checklist §6 item #3). |

**Conclusão item 1:** o **desenho** da ordem SEC-F18 está correto e a sub-invariante crítica — "nenhum secret de ref não-`main`" — é **garantida pelo YAML** independentemente do provisionamento (backstop + `needs: guard`). A **aplicação real** da branch rule/reviewers no Environment é a parte out-of-band → **OPEN** (condição **C1**).

## 2. Item 2 — Superfície de secret (least-privilege) → ✅ PASS (repo-verificável) · ⏳ OPEN (Environment provisionado)

**Exigência:** apenas `YOUTUBE_API_KEY` + `SUPABASE_DB_PASSWORD`; **sem** `SUPABASE_ACCESS_TOKEN` (⇒ incapaz de `db push`); **sem** service-role key (SEC-F19). Sinalizar qualquer secret além dos dois.

| Sub-controle | Veredito | Evidência |
|---|---|---|
| Apenas **dois** secrets referenciados no YAML | ✅ **PASS (repo-verificável)** | Grep de `secrets.*` no YAML retorna **exatamente**: `SUPABASE_DB_PASSWORD` (L216, L272) e `YOUTUBE_API_KEY` (L237). Nenhum terceiro secret. `INFRA-0002 §2.1` nomeia **só** esses dois. |
| **Sem `SUPABASE_ACCESS_TOKEN`** → estruturalmente incapaz de `db push` (OQ-1) | ✅ **PASS (repo-verificável)** | Zero referência a `secrets.SUPABASE_ACCESS_TOKEN` no YAML (as duas menções ao nome — L46, L214 — são **comentários** afirmando a ausência). `INFRA-0002 §2.1` exclui explicitamente. Blast radius do token de migration do `production-db` **não** compartilhado. |
| **Sem service-role key** (SEC-F19) | ✅ **PASS (repo-verificável)** | Zero referência a `SUPABASE_SERVICE_ROLE_KEY`/`service_role` no YAML. `INFRA-0002 §2.1` deixa o secret de maior raio de explosão **fora** do CI; escrita via owner `postgres`/DB-password. |
| Coordenadas não-secretas isoladas em `vars.*` | ✅ PASS (design) | `INFRA-0002 §2.2`: `SUPABASE_DB_HOST`/`PORT`/`USER` como **variables** (não secret) — reduz o secret de DB a **um** valor (a senha). Consistente com o YAML (L217–219/L273–275). |
| Environment provisionado contém **só** os dois secrets (+ vars), sem secret estranho | ⏳ **OPEN** | Não verificável do repo. `INFRA-0002 §2.1/§6` manda **remover** service-role se presente. Exige evidência out-of-band de que o Environment provisionado **não** carrega nada além dos dois (condição **C2**). |

**Conclusão item 2:** a superfície de secret **no artefato versionado** é mínima e correta — repo-verificável. **Nenhum secret além dos dois** aparece no YAML; **flag:** nenhum a sinalizar. A confirmação de que o Environment **provisionado** espelha essa lista (sem stray secret) é out-of-band → **OPEN** (condição **C2**).

## 3. Item 3 — Herança do YAML (SEC-0020) + F-3 + DISARMED → ✅ PASS (repo-verificável) · o item mais forte

**Exigência:** F-3 (env:-indireção) ⇒ **zero `${{ }}`** em `run:` do guard; guard **genuinamente desarmado** (nenhuma coleta/API/arm alcançável sem o passo humano).

| Sub-controle | Veredito | Evidência |
|---|---|---|
| **F-3 aplicado — zero `${{ }}` em `run:` do guard** | ✅ **PASS (repo-verificável)** | Todas as ocorrências de `${{` no arquivo estão em blocos `env:` (L109–110, L126, L141) ou em **comentários** (L104, L125, L137, L139) — **nenhuma** dentro de um corpo `run:`. Os 3 steps do guard consomem `CONFIRM`/`ACKNOWLEDGE_IRREVERSIBLE`/`RUN_ID`/`DISPATCH_REF` via `env:` e referenciam como `"$VAR"` (L111–121, L127–133, L142–153). **Fecha o finding F-3 de SEC-0020 §4** — o único condicionante aberto daquela auditoria para o arm. |
| Guard roda **sem Environment/secret** | ✅ PASS | Job `guard` não tem `environment:` (L94–194) → imune ao footgun do "Environment novo auto-criado sem proteção"; o gate de arm executa **antes** de qualquer acesso a secret. |
| **DISARMED por construção** — arm marker + artefatos SG-5 ausentes | ✅ **PASS (repo-verificável)** | Verificado ausentes: `.github/collection/youtube-collection.armed`, `services/data-engine/src/noxund_data_engine/channel_collection.py`, `services/data-engine/tests/test_channel_collection.py`, `supabase/tests/channel_data_post_collection_verify.sql`. O preflight de arm (L155–194) faz `exit 1` enquanto **qualquer** faltar. Landar o YAML na `main` **não coleta nada**. |
| Nenhuma API/egress/coleta/arm alcançável sem passo humano | ✅ PASS | Egress `googleapis.com` só no `collect` (L231–253), atrás de `needs: guard` + `environment` (required reviewers). Arm = arquivo committado sob branch protection da `main`. Injeção de valor de secret + `.armed` + dispatch = fronteira humana. |
| Higiene de secret herdada (SEC-0020) | ✅ PASS | SHA-pin SEC-F17 (checkout/setup-python), `permissions: contents: read`, URL mascarada (`::add-mask::` antes de `$GITHUB_ENV`, L228/L285), `YOUTUBE_API_KEY` env-only auto-mask, header `X-Goog-Api-Key`/never `?key=`. Inalterado nesta entrega; **herdo o PASS de SEC-0020 §2/§3**. |

**Conclusão item 3:** ✅ **PASS integral, repo-verificável.** Herdo SEC-0020 para o YAML e confirmo que **F-3 está fechado** e o pipeline **permanece desarmado por construção**. Nenhuma mutação de comportamento além da env:-indireção do guard.

## 4. Item 4 — F-1 (GCP-side): restrição da key + quota + rotação → ✅ PASS (design adequado) · ⏳ OPEN (execução no console GCP)

**Exigência:** avaliar adequação do plano de restringir a key à YouTube Data API v3 + alerta de quota + política de rotação (review de desenho — não posso tocar GCP).

| Sub-controle | Adequação | Avaliação |
|---|---|---|
| **Restrição de API** à *YouTube Data API v3* | ✅ Adequado (design) | `INFRA-0002 §4.1`: API restriction limitando a key a **uma** API. Uma key restrita a uma API é inútil para o resto da superfície Google se vazar — é a **mitigação primária correta**. |
| **Application restriction (IP)** inviável em runner GitHub | ✅ Aceito honestamente | Runners GitHub não têm IP de egress estático → restrição por IP registrada como **aceita/não-aplicável** (`§4.1`). **Residual honesto:** uma key vazada, ainda que API-restrita, pode queimar quota/billing de **qualquer** origem. Compensado por: API única de baixo custo (≤~10 un/run), **alerta de quota** como detecção e **rotação**. **Adequado ao risco**, não defeito. |
| **Alerta de quota** | ✅ Adequado (design) | `INFRA-0002 §4.2`: alerta em fração da quota diária default (10.000 un/dia); delta desta coleta ≤~10 un/run → alerta bem abaixo do teto detecta abuso/loop cedo. |
| **Política de rotação/revogação** (SEC-F20) | ✅ Adequado (design) | `INFRA-0002 §4.3`: gatilhos pós-run/troca-de-pessoal/≤90d/suspeita-de-leak; revogar keys temporárias; atualizar o secret pós-rotação; remover secrets desnecessários pós-provisionamento. Cobertura completa. |
| Transporte por header (2ª camada) | ✅ PASS (herdado) | `X-Goog-Api-Key`, never `?key=` (OQ-6) — já no YAML, herdado de SEC-0016/SEC-0020. |

**Conclusão item 4:** o **plano F-1 é adequado** (design review). A **aplicação real no console GCP** é out-of-band e **não verificável do repo** → **OPEN**; exige evidência out-of-band (screenshot §4, checklist §6 item #4) antes do arm (condição **C3**). A única postura errada seria provisionar uma key portadora de custo **sem** API-restriction — o plano **não** comete esse erro.

## 5. Item 5 — Checklist de pré-arm (INFRA-0002 §6) → ✅ PASS (completo; toda ação sensível atrás da fronteira humana)

| # | Item do checklist | Estado (minha verificação) |
|---|---|---|
| 1 | **F-3 aplicado** (guard sem `${{ }}` em `run:`) | ✅ **verde — repo-verificável** (§3 acima) |
| 2 | **OQ-2 confirmado** (sem `FORCE RLS` + caminho `postgres`/DB-password) | ✅ **verde — repo-verificável**: grep em `supabase/migrations` → **zero** `FORCE ROW LEVEL SECURITY`; migration L177–186 faz `enable row level security` + `revoke all … from anon, authenticated` nas 3 raw tables (default-deny); Database (`HANDOFF-channel-data-collection-review §2.5`) + Security (SEC-0019 §3/OQ-2) ratificaram. Owner `postgres` ignora RLS (sem FORCE) e INSERTa; UPDATE/DELETE/TRUNCATE barrados por triggers de imutabilidade. |
| 3 | **Environment provisionado** (branch rule `main` 1º → reviewers → secrets/vars) | ⏳ **OPEN** — out-of-band (condição **C1/C2**) |
| 4 | **F-1 aplicado** (API-restriction + quota + rotação) | ⏳ **OPEN** — out-of-band (condição **C3**) |
| 5 | **SG-5 landado** (collector + testes §8.1–§8.6 + verify SQL) | ⏳ **OPEN** — verificado **ausente** no repo (condição **C4**); o preflight do guard também exige a existência dos 4 arquivos |
| 6 | **Security co-assina SG-4** | ✅ **este doc (SEC-0021)** — co-sign-com-condições |

**Propriedades de gate que confirmo:** (a) o `.armed` é **ato consciente** do DevOps; **ausência = desarmado**; "silêncio ≠ aprovação". (b) O marcador é condição **necessária, não suficiente** — mesmo armado, os required reviewers do Environment continuam gateando **cada** `collect`/`verify` (SG-6). (c) Toda ação **SENSÍVEL** (injeção de valor de secret, commit de `.armed`, dispatch) permanece **fora** desta entrega, na fronteira humana. O checklist está **completo e corretamente ordenado**.

**Conclusão item 5:** ✅ **PASS** no desenho/completude do checklist. Os itens 3/4/5 **OPEN** são a fronteira humana/outros-agentes por design — **não** são findings contra o DevOps.

---

## 6. Findings

| ID | Severidade | Tipo | Estado | Nota |
|---|---|---|---|---|
| **F-3** (de SEC-0020) | baixa | hardening | ✅ **FECHADO** nesta entrega | env:-indireção nos 3 steps do guard; zero `${{ }}` em `run:` — repo-verificável. Era o único condicionante de SEC-0020 para o arm. |
| **F-1** (de SEC-0019/SEC-0020) | média | condição carregada | ⏳ **OPEN** (condição **C3**) | Plano adequado (§4); execução no GCP é out-of-band, exige evidência antes do arm. |

**Nenhum finding novo** contra a preparação de SG-4. O IP-application-restriction inviável em runner GitHub é **residual aceito** (§4), não finding.

## 7. Condições que devem estar VERDES (com evidência) antes que um humano arme

**Nenhum `.armed`, nenhuma injeção de secret, nenhum dispatch antes de C1–C5 verdes.**

- **C1 — Ordem SEC-F18 (out-of-band):** Environment `youtube-collection` criado com **branch rule `main`-only ANTES de qualquer secret** → **required reviewers = DevOps + Security**. Evidência out-of-band anexada (screenshot §3). *(O backstop do guard já garante "nenhum secret de ref não-`main`" no nível do YAML; C1 é a 2ª camada exigida.)*
- **C2 — Superfície de secret provisionada (out-of-band):** o Environment contém **exatamente** `YOUTUBE_API_KEY` + `SUPABASE_DB_PASSWORD` (secrets) + `SUPABASE_DB_HOST/PORT/USER` (vars). **Sem** `SUPABASE_ACCESS_TOKEN`, **sem** `SUPABASE_SERVICE_ROLE_KEY` (remover se presente). Evidência out-of-band.
- **C3 — F-1 no GCP (out-of-band):** key restrita à **YouTube Data API v3** + alerta de quota + política de rotação documentada. Evidência out-of-band anexada (screenshot §4).
- **C4 — SG-5 landado (repo-verificável):** `channel_collection.py` + `test_channel_collection.py` (§8.1–§8.6) + `channel_data_post_collection_verify.sql` presentes e verdes. **Hoje ausentes.** O preflight de arm do guard também os exige.
- **C5 — Arm consciente + gate humano de runtime:** DevOps commita `.armed` **só após C1–C4 verdes**; **mesmo armado**, required reviewers gateiam cada `collect`/`verify`; o **dispatch** (SG-6) é ato humano separado com frase + acknowledge de irreversibilidade.

**Verificável do repo (já verde):** F-3 (§3), OQ-2 (§5 item 2), superfície de secret **no YAML** (§2), desarme por construção (§3). **Verificável só out-of-band (OPEN):** C1, C2, C3, e C4 até o SG-5 landar.

---

## 8. Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_security_cosign_configure_env_youtube_collection` · **Owner:** Security · **Data:** 2026-07-02 · **Prioridade:** P1

**Objetivo:** co-assinar SG-4 (item #6 do pré-arm) — auditar, como design/config review, as protection rules + secret handling do Environment `youtube-collection` de `INFRA-0002`, herdando SEC-0020 para o YAML.

**Resultado:** ✅ **CO-SIGN COM CONDIÇÕES.** 3 itens PASS repo-verificável (F-3/desarmado, superfície de secret no YAML, OQ-2), 2 itens PASS-de-design + OPEN-de-execução (ordem SEC-F18, F-1 no GCP). F-3 (único condicionante aberto de SEC-0020) **fechado**. Nenhum finding novo. Condições **C1–C5** (§7) bloqueiam o arm.

**Arquivos criados:** `docs/security/SEC-0021-youtube-collection-env-audit.md` (esta auditoria + handoff).
**Arquivos intocados (constraint AUDIT-ONLY):** nenhum Environment/secret provisionado; `.github/collection/youtube-collection.armed` **NÃO** criado; YAML/migrations/collector inalterados; zero dispatch; zero coleta; zero toque em GCP/GitHub.

**Impacto no escopo:** MVP travado mantido. Toca secrets/API keys/env → é exatamente a revisão de Security exigida (matrix #8). Não toca número/copy pública. Fase 9/RLS **VETADA**; `0007`/producer_events **PARKED**; publish barrado até **P5-REPRO-01** — **não** tocados.

**Validação executada (repo-verificável):** grep `${{` no YAML (só em `env:`/comentários, zero em `run:` do guard); grep `secrets.*` (só os dois secrets); grep `SUPABASE_ACCESS_TOKEN`/`service_role` (só comentários de ausência); grep `FORCE ROW LEVEL SECURITY` em migrations (zero); ausência de `.armed`/collector/testes/verify SQL. **Não executável aqui (OPEN):** provisionamento do Environment, F-1 no GCP — exigem evidência out-of-band.

**Riscos:** residual aceito — key portadora de custo sem IP-restriction (inviável em runner GitHub), compensada por API-restriction + quota alert + rotação (§4). Nenhum risco novo introduzido (audit-only).

**Revisões necessárias:** [x] Security co-sign SG-4 (este doc). [ ] Evidência out-of-band de C1/C2/C3 (Product Lead/DevOps). [ ] SG-5 (Data/AI) para C4.

**Próximos passos:** (1) Product Lead/DevOps provisiona o Environment na ordem SEC-F18 + injeta valores + aplica F-1 no GCP → anexa evidência (C1–C3). (2) Data/AI landa SG-5 (C4). (3) DevOps commita `.armed` **só** com C1–C5 verdes. (4) SG-6 dispatch humano + required reviewers. (5) SG-7 §7 pós-run → SG-8 P5-REPRO-01 antes do 1º publish.

**Open decisions / bloqueios:** C1–C5 (§7) são os bloqueios do arm. Nenhuma OPEN DECISION nova.

---

## AgentResult

```json
{
  "task_id": "task_security_cosign_configure_env_youtube_collection",
  "agent": "security_agent",
  "status": "completed",
  "summary": "CO-SIGN de SG-4 (item #6 do pre-arm de INFRA-0002) concluida AUDIT-ONLY. VEREDITO: CO-SIGN COM CONDICOES. Itens repo-verificaveis VERDES: (item 3) F-3 aplicado — zero ${{ }} em run: do guard (todas as interpolacoes em env:/comentarios), guard desarmado por construcao (.armed + collector + testes + verify SQL AUSENTES, verificado) — FECHA o unico finding aberto de SEC-0020; heranca de SEC-0020 (SHA-pin, contents:read, URL mascarada, X-Goog-Api-Key) confirmada. (item 2) superficie de secret minima no YAML: SO SUPABASE_DB_PASSWORD + YOUTUBE_API_KEY (grep), SEM SUPABASE_ACCESS_TOKEN (incapaz de db push, OQ-1) e SEM service-role (SEC-F19). (item 5/#2) OQ-2 confirmado em repo: zero FORCE ROW LEVEL SECURITY nas migrations; raw tables RLS-on + revoke anon/authenticated (default-deny); caminho owner postgres. Itens PASS-de-design + OPEN-de-execucao (out-of-band, nao verificavel do repo): (item 1) ordem SEC-F18 — branch rule main-only ANTES dos secrets + required reviewers DevOps+Security bem desenhada; a sub-invariante 'nenhum secret de ref nao-main' JA e garantida no YAML pelo backstop do guard + needs:guard (repo-verificavel), mas a aplicacao da branch rule/reviewers e out-of-band; (item 4) F-1 no GCP — plano adequado (API-restriction YouTube Data API v3 + quota alert + rotacao; IP-restriction inviavel em runner GitHub = residual aceito), execucao out-of-band. Nenhum finding novo. Condicoes C1-C5 devem estar verdes com evidencia out-of-band antes que um humano commite .armed/injete secret/dispatch: C1 ordem SEC-F18, C2 Environment so com os 2 secrets, C3 F-1 no GCP, C4 SG-5 landado (hoje ausente), C5 arm consciente + required reviewers em cada collect/verify. NAO provisionei, NAO injetei/echo secret, NAO criei .armed, NAO dispatch, NAO coleta, NAO toquei GCP/GitHub. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0021-youtube-collection-env-audit.md",
      "description": "Co-sign de SG-4 (audit_secrets, matrix #8): protection rules + secret handling do Environment youtube-collection. Per-item PASS/FINDING/OPEN com control IDs (SEC-F17/F18/F19/F20/F23), F-3 fechado, heranca de SEC-0020, plano F-1 avaliado, OQ-2 confirmado, checklist §6, veredito CO-SIGN COM CONDICOES + condicoes C1-C5, e handoff."
    }
  ],
  "errors": [],
  "cosign_verdict": "co-sign-with-conditions",
  "conditions": [
    "C1 (out-of-band): Environment youtube-collection com branch rule main-only ANTES de qualquer secret -> required reviewers DevOps+Security; evidencia out-of-band (INFRA-0002 §3). Backstop do guard ja garante 'nenhum secret de ref nao-main' no YAML.",
    "C2 (out-of-band): Environment contem EXATAMENTE YOUTUBE_API_KEY + SUPABASE_DB_PASSWORD (secrets) + SUPABASE_DB_HOST/PORT/USER (vars); SEM SUPABASE_ACCESS_TOKEN, SEM service-role (remover se presente); evidencia out-of-band.",
    "C3 (out-of-band): F-1 no console GCP — key restrita a YouTube Data API v3 + alerta de quota + politica de rotacao; evidencia out-of-band (INFRA-0002 §4).",
    "C4 (repo-verificavel): SG-5 landado — channel_collection.py + test_channel_collection.py (§8.1-§8.6) + channel_data_post_collection_verify.sql presentes/verdes; hoje AUSENTES; o preflight do guard tambem os exige.",
    "C5: DevOps commita .armed SO apos C1-C4 verdes; mesmo armado, required reviewers gateiam cada collect/verify; dispatch (SG-6) e ato humano separado com frase + acknowledge de irreversibilidade."
  ],
  "findings": [
    {
      "id": "F-3",
      "severity": "low",
      "type": "hardening",
      "status": "closed",
      "gate": "SG-4/arm",
      "issue": "SEC-0020 §4: guard interpolava ${{ inputs.* }}/${{ github.ref }} direto em run: (script-injection).",
      "resolution": "FECHADO nesta entrega: env:-indirecao nos 3 steps do guard (CONFIRM/ACKNOWLEDGE_IRREVERSIBLE/RUN_ID/DISPATCH_REF via env:, usados como \"$VAR\"); grep confirma ZERO ${{ }} em run: do guard."
    },
    {
      "id": "F-1",
      "severity": "medium",
      "type": "carried_condition",
      "status": "open",
      "gate": "SG-4/configure_env (condicao C3)",
      "blocking_for": "arm / 1st real run",
      "issue": "YOUTUBE_API_KEY portadora de custo; plano de API-restriction/quota/rotacao adequado (INFRA-0002 §4) mas execucao no console GCP e out-of-band e nao verificavel do repo. IP-application-restriction inviavel em runner GitHub = residual aceito.",
      "required_mitigation": "Aplicar F-1 no GCP + anexar evidencia out-of-band ANTES do arm."
    }
  ],
  "next_recommendation": {
    "target_agent": "devops_agent",
    "action": "configure_env",
    "priority": "high",
    "reason": "SG-4 CO-ASSINADO com condicoes em SEC-0021: preparacao do DevOps corretamente desenhada; F-3 FECHADO (zero ${{ }} em run: do guard) e pipeline desarmado por construcao — verificado em repo; superficie de secret minima (so os 2 secrets, sem ACCESS_TOKEN/service-role) e OQ-2 (zero FORCE RLS, default-deny) confirmados em repo. Residual = fronteira humana out-of-band: provisionar o Environment na ordem SEC-F18 (branch rule main-only ANTES dos secrets -> required reviewers DevOps+Security -> so entao secrets/vars), garantir que o Environment contem SO os 2 secrets, aplicar F-1 no GCP (restricao YouTube Data API v3 + quota alert + rotacao) — todos com evidencia out-of-band (C1/C2/C3). SG-5 (Data/AI: collector + testes §8 + verify SQL) e pre-condicao do arm (C4; o preflight do guard checa a existencia dos 4 arquivos). SO com C1-C5 verdes o DevOps commita .github/collection/youtube-collection.armed; mesmo armado, required reviewers gateiam cada collect/verify e o dispatch (SG-6) e ato humano separado. Nada roda ate la. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01."
  }
}
```
</content>
</invoke>
