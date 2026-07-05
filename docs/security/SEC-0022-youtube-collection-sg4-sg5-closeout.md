# SEC-0022 — Security CO-SIGN closeout · SG-4 provisionado + SG-5 fechado · Environment `youtube-collection`

- **Task:** `task_security_cosign_closeout_youtube_collection` · **Action:** `audit_secrets` (closeout do co-sign de `configure_env`) · **Agent:** `security_agent` · **Compilado por:** Product Orchestrator (parity documental)
- **Data:** 2026-07-04
- **Matriz:** `agent-review-matrix.md` **#8** (deploy/mudança de ambiente → DevOps + Security).
- **Gate:** **SG-4** de DEC-0018 (item **#6** do pré-arm de `INFRA-0002 §6`) + fechamento funcional de **SG-5**.
- **Supersede:** **SEC-0021** (co-sign-com-condições) — resolve suas condições **C1–C4**; **C5** (arm consciente) permanece por design.
- **Mandato:** **RECORDS/AUDIT-ONLY, docs-only.** Não provisiono, não injeto/echo/print valor de secret, **não crio `.armed`**, não dispatch, não coleto, não toco GCP/GitHub/workflow/migration/`0007`. **Zero valor de secret neste doc. Nenhum screenshot. Nenhuma connection string completa.** O que é verificável do repo/API é marcado como tal; o que é out-of-band é registrado como **atestado** (evidência privada, fora do repo).

---

## 0. Veredito

✅ **CO-SIGN FECHADO — APPROVE WITH NOTES.** A preparação de SG-4 foi **provisionada** e **co-assinada por Security**; **SG-5 está funcionalmente fechado** em `main`. As condições **C1–C4** de SEC-0021 estão **resolvidas** (por verificação de API/repo + atestação assinada do Product Lead para os itens GCP). **Nenhum finding novo.**

⛔ **Este doc NÃO arma nem autoriza run.** `.github/collection/youtube-collection.armed` permanece **ausente** (verificado). O **commit consciente do `.armed`** (condição **C5**) e o **dispatch humano** (SG-6) seguem na **fronteira humana** — fora deste registro.

**Calibração honesta:** os controles de protection-rules/secret-surface são **verificados por API** (valores nunca expostos); o **F-1 no GCP** é **PASS por atestação** (execução out-of-band, não verificável do repo), com evidência privada mantida fora do repositório.

---

## 1. SG-4 — Environment `youtube-collection` provisionado (fecha C1/C2/C3)

Verificado na configuração **viva do GitHub** via API (somente metadados; **nenhum valor de secret lido/exposto**):

| Controle | Estado | Como verificado |
|---|---|---|
| **Branch policy `main`-only** | ✅ | `deployment_branch_policy = custom`, padrão único = `main` (API). Consistente com SEC-F18 (branch rule antes dos secrets). |
| **Required reviewer configurado** | ✅ | `required_reviewers = User:AdeptLabsDev` (API) — gate humano em runtime nos jobs `collect`/`verify`. |
| **Secrets mínimos (nomes)** | ✅ | Exatamente `{YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}` (API, **nomes**). Espelha `INFRA-0002 §2.1`. |
| **Ausência de `SUPABASE_ACCESS_TOKEN`** | ✅ | Não presente (API). ⇒ Environment estruturalmente **incapaz de `db push`** (OQ-1); blast radius do token de migration do `production-db` **não** compartilhado. |
| **Ausência de `SUPABASE_SERVICE_ROLE_KEY`** | ✅ | Não presente (API). Secret de maior raio de explosão **fora** do CI (SEC-F19); escrita via owner `postgres`/DB-password. |
| **Vars corretas (nomes)** | ✅ | `SUPABASE_DB_HOST`, `SUPABASE_DB_PORT`, `SUPABASE_DB_USER` presentes (API, **nomes**). Coordenadas **não-secretas** (session pooler IPv4, porta em **session mode** `5432` — não o txn pooler `6543`; user `postgres.<ref>`), como documentado em `INFRA-0002 §2.2`. Valores não reproduzidos aqui (não-secretos, mas mantidos por nome para higiene). |
| **Ordem de setup SEC-F18** (branch rule antes dos secrets) | ✅ (atestado) | Product Lead atesta a ordem correta; o backstop do guard (`DISPATCH_REF != refs/heads/main → exit 1` + `needs: guard`) já garante "nenhum secret de ref não-`main`" no próprio YAML (repo-verificável, SEC-0021 §1). |

→ **Resolve C1** (ordem + branch rule + reviewers), **C2** (superfície de secret provisionada = só os 2 secrets + as 3 vars, sem token/service-role).

## 2. F-1 (GCP) — aprovado por atestação out-of-band (fecha C3)

Ato de console GCP, **não verificável do repo**. Registrado por **atestação assinada** do Product Lead, com **evidência privada mantida fora do repositório** (labels E4a restrição de API, E4b alerta de quota, e notas de rotação redigidas):

- **Restrição de API:** key limitada **somente** à *YouTube Data API v3* (mitigação primária — key vazada é inútil para o resto da superfície Google).
- **Application/IP restriction:** marcada **não-aplicável** — runners GitHub não têm IP de egress estático. **Residual aceito** (SEC-0021 §4), compensado por: API única de baixo custo (≤ ~10 unidades/run), **alerta de quota** e **rotação**.
- **Alerta de quota:** configurado na YouTube Data API v3.
- **Política de rotação/revogação (SEC-F20):** documentada — pós-run relevante, troca de pessoal, periódica ≤ 90 dias, suspeita de leak, e revogação imediata de keys de teste.

→ **Resolve C3.** **Nenhum valor de secret** e **nenhum screenshot** entram no repo — a evidência permanece privada, out-of-band.

## 3. SG-5 — funcionalmente fechado em `main` (fecha C4)

| Fato | Registro |
|---|---|
| **Merge** | PR **#31** (`feat: add gated channel collection collector`) mergeado em `main` (merge `ea41693`). |
| **CI verde** | `data-engine-tests.yml`: resolver suite **132/132** ×2 (determinismo) + P5-REPRO-01 harness **21/21** ×2 + golden digest byte-idêntico — **success** no merge de `main`. |
| **Approvals** | Revisão 4-way no PR #31: **Security / Database / DevOps / Data-AI = APPROVE** (contratos travados pré-código; §8.1–§8.6 verdes). |
| **Preflight de arm** | Os 3 artefatos que o guard exige existem e estão tracked em `main`: `services/data-engine/src/noxund_data_engine/channel_collection.py`, `services/data-engine/tests/test_channel_collection.py`, `supabase/tests/channel_data_post_collection_verify.sql`. |
| **Count guard** | `data-engine-tests.yml` atualizado 119 → 132 (aprovado por DevOps + Data-AI). |

**Nota de parity (motivo deste doc):** SG-5 foi revisado como **PR reviews** (4-way APPROVE) e provado por **CI**, mas não havia um SEC-doc autônomo de fechamento em `docs/security/`. **SEC-0022 registra esse fechamento** — o gap era **documental**, não funcional.

→ **Resolve C4** (SG-5 landado/verde).

## 4. Exceção não-bloqueante — reviewer único (separação de deveres por papel)

`GET /orgs/AdeptLabsDev/teams` → **404**: **não existem teams**. O único colaborador/admin é **`AdeptLabsDev`**, que também é o `required_reviewer` do `production-db`. Portanto, **"DevOps" e "Security" do `matrix #8` são encarnados pela mesma identidade GitHub `User:AdeptLabsDev`** — realidade operacional.

- **Registro honesto:** a separação de deveres é feita por **papel/agente** (personas distintas no runtime `@noxund/orchestrator`), **não** por identidade GitHub distinta. Numa conta single-operator o gate humano existe, mas **colapsa numa pessoa**.
- **Por que não é bloqueante:** o gate humano é **multi-fator** e re-aplicado a **cada** `collect`/`verify` — dispatch de `main` + frase `RUN-CHANNEL-COLLECTION` + acknowledge `I-UNDERSTAND-RAW-IS-IRREVERSIBLE` + aprovação do required reviewer do Environment + arm marker sob branch protection. **NOTE**, não FINDING.
- **Evolução:** se um segundo colaborador/team (`security`/`devops`) for criado, o `matrix #8` passa a ter separação real de identidade. Até lá, é `AdeptLabsDev` nos dois papéis.

## 5. Estado das condições C1–C5 (de SEC-0021)

| Cond. | Descrição | Estado | Base |
|---|---|---|---|
| **C1** | Ordem SEC-F18 — branch rule `main`-only antes dos secrets → required reviewers | ✅ **verde** | API (branch policy + reviewer) + atestação da ordem |
| **C2** | Environment contém só os 2 secrets + 3 vars; sem `ACCESS_TOKEN`/service-role | ✅ **verde** | API (nomes de secrets/vars) |
| **C3** | F-1 no GCP (restrição YouTube Data API v3 + quota + rotação) | ✅ **verde** | Atestação out-of-band (evidência privada) |
| **C4** | SG-5 landado (collector + testes §8 + verify SQL, verdes) | ✅ **verde** | PR #31 + CI 132/132 + 4-way APPROVE (§3) |
| **C5** | Arm consciente + gate humano de runtime | ⏳ **pendente por design** | `.armed` ausente; commit é ato humano do DevOps; dispatch = SG-6 |

## 6. O que permanece na fronteira humana (NÃO feito aqui, por design)

- **`.armed` AUSENTE** (verificado). Sua criação é o **ato consciente do DevOps**, só após C1–C4 verdes. **Não criado por este doc.**
- **SG-6 — dispatch humano:** de `main`, com `RUN-CHANNEL-COLLECTION` **e** `I-UNDERSTAND-RAW-IS-IRREVERSIBLE`, **e** aprovação do required reviewer do Environment `youtube-collection`. É a **única** coisa que coleta de fato.
- **SG-7** (gate §7 pós-run) → **SG-8 / P5-REPRO-01** antes do 1º publish.
- **Vetos de pé (não tocados):** Fase 9 / RLS Policies **VETADA**; `0007`/producer_events **PARKED**; publish barrado até **P5-REPRO-01**.

## 7. Validação executada (docs-only)

- **API (metadados, zero valor):** branch policy `main`-only; `required_reviewer`; **nomes** de secrets = `{YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}`; ausência de `ACCESS_TOKEN`/`SERVICE_ROLE`; **nomes** de vars = `{HOST, PORT, USER}`; org sem teams (reviewer = `AdeptLabsDev`).
- **Repo:** SG-5 tracked em `main` (4 arquivos); `.armed` **ausente**; `0007` **parked/untracked** (intocado).
- **Atestação:** F-1 no GCP (evidência privada, fora do repo) — não verificável do repo; registrado como atestado.
- **Não executado (proibido/impossível aqui):** ler valores de secret; abrir screenshots; provisionar; armar; dispatchar; tocar GCP/GitHub/workflow/migration/`0007`.

---

## 8. Handoff (per `docs/agents/handoff-template.md`)

**Tarefa:** `task_security_cosign_closeout_youtube_collection` · **Owner:** Security (compilado pelo Product Orchestrator) · **Data:** 2026-07-04 · **Prioridade:** P1

**Objetivo:** fechar, para parity documental, o co-sign de SG-4 (item #6) e o fechamento funcional de SG-5; resolver as condições C1–C4 de SEC-0021.

**Resultado:** ✅ **CO-SIGN FECHADO (APPROVE WITH NOTES).** C1/C2 por API, C3 por atestação, C4 por PR #31/CI/approvals. NOTE não-bloqueante: reviewer único `AdeptLabsDev` (separação por papel/agente). C5 (arm) permanece na fronteira humana.

**Arquivos criados:** `docs/security/SEC-0022-youtube-collection-sg4-sg5-closeout.md` (este doc). **Nenhum outro arquivo tocado.**

**Arquivos intocados (constraint):** nenhum workflow/migration/collector; `.github/collection/youtube-collection.armed` **NÃO** criado; `0007` **PARKED** intocado; zero valor de secret/screenshot no repo; zero dispatch/coleta; zero toque em GCP/GitHub além de leitura de metadados de config.

**Impacto no escopo:** MVP travado mantido. Toca registro de secrets/env → é a revisão de Security exigida (matrix #8), em forma de closeout. Não toca número/copy pública. Fase 9 VETADA; `0007` PARKED; publish barrado até P5-REPRO-01.

**Revisões:** [x] Security co-sign SG-4 (SEC-0021 + este closeout). [x] SG-5 4-way APPROVE (PR #31). [ ] Arm consciente do DevOps (C5) — fronteira humana.

**Próximos passos:** (1) DevOps commita `.armed` **só** com C1–C4 verdes (agora satisfeitas) — decisão consciente humana. (2) SG-6 dispatch humano + required reviewer. (3) SG-7 §7 pós-run → SG-8 P5-REPRO-01 antes do 1º publish.

**Open decisions:** nenhuma nova. C5 (arm) é o único gate restante e é humano por design.

---

## AgentResult

```json
{
  "task_id": "task_security_cosign_closeout_youtube_collection",
  "agent": "security_agent",
  "status": "completed",
  "summary": "Closeout de SG-4/SG-5 (parity documental) — CO-SIGN FECHADO, APPROVE WITH NOTES. SG-4 provisionado e verificado por API (valores nunca expostos): Environment youtube-collection com branch policy main-only, required_reviewer=User:AdeptLabsDev, secrets = SO {YOUTUBE_API_KEY, SUPABASE_DB_PASSWORD}, SEM SUPABASE_ACCESS_TOKEN (incapaz de db push, OQ-1) e SEM SUPABASE_SERVICE_ROLE_KEY (SEC-F19), vars {HOST,PORT,USER} presentes (nomes; session pooler, porta 5432 session-mode, user postgres.<ref>). F-1 no GCP (restricao YouTube Data API v3 + quota alert + rotacao; IP-restriction N/A = residual aceito) aprovado por ATESTACAO out-of-band, evidencia privada mantida FORA do repo. SG-5 funcionalmente fechado em main via PR #31: CI 132/132 x2 + repro 21/21 + golden digest byte-identico; 4-way APPROVE (Security/Database/DevOps/Data-AI); os 3 artefatos do preflight de arm tracked em main; count guard 119->132. Resolve condicoes C1-C4 de SEC-0021. NOTE nao-bloqueante: sem GitHub teams, DevOps+Security ambos = User:AdeptLabsDev; separacao de deveres por papel/agente, nao por identidade; mitigada pelo gate humano multi-fator re-aplicado a cada collect/verify. .armed permanece AUSENTE (verificado) — C5 (arm consciente do DevOps) e o dispatch humano SG-6 (main + RUN-CHANNEL-COLLECTION + I-UNDERSTAND-RAW-IS-IRREVERSIBLE + required reviewer) seguem na fronteira humana. Docs-only: zero valor de secret, zero screenshot, nenhuma connection string completa; nada de workflow/migration/collector/.armed/0007 tocado; zero dispatch/coleta.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0022-youtube-collection-sg4-sg5-closeout.md",
      "description": "Closeout do co-sign de SG-4 (audit_secrets, matrix #8) + fechamento funcional de SG-5. Resolve C1-C4 de SEC-0021 (C1/C2 por API, C3 por atestacao, C4 por PR #31/CI/approvals). Registra reviewer unico (NOTE nao-bloqueante), ausencia de ACCESS_TOKEN/service-role, .armed ausente, e SG-6 humano pendente. Zero valor de secret."
    }
  ],
  "errors": [],
  "cosign_verdict": "approve-with-notes",
  "notes": [
    "Reviewer unico User:AdeptLabsDev encarna DevOps+Security (sem teams no GitHub); separacao de deveres por papel/agente, nao por identidade — nao-bloqueante.",
    "F-1 no GCP aprovado por atestacao out-of-band; evidencia privada fora do repo; nao verificavel do repo."
  ],
  "next_recommendation": {
    "target_agent": "devops_agent",
    "action": "record_decision",
    "priority": "high",
    "reason": "SG-4 co-assinado e fechado (SEC-0022): C1-C4 de SEC-0021 resolvidas (C1/C2 por API, C3 por atestacao, C4 por SG-5 landado). O UNICO gate restante antes de coleta e a condicao C5: o commit CONSCIENTE de .github/collection/youtube-collection.armed pelo DevOps — ato humano deliberado, so apos confirmacao do Product Lead; NUNCA feito por agente. Mesmo armado, os required reviewers do Environment gateiam cada collect/verify e o dispatch (SG-6) exige main + RUN-CHANNEL-COLLECTION + I-UNDERSTAND-RAW-IS-IRREVERSIBLE. Nada roda ate la. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01."
  }
}
```
