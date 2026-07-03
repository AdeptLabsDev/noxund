# SEC-0006 — Security Re-audit · Ambiente credenciado da Fase 1 (pós-remediação)

> **Pointer (2026-06-24, não altera o veredito):** os gates downstream que o §6 listava como
> ⏳ — DEC-0007 (b) PR mergeado + INFRA-0001 §3 required reviewers — foram **fechados**; a Fase 1
> foi **aplicada e verificada** em CI (run `27956757153`). Registro de fechamento: **DEC-0008**.
> O veredito desta re-auditoria (✅ SEM BLOQUEIO) permanece como foi emitido em 2026-06-21.

- **Task:** `task_phase1_security_reaudit_secrets_env` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-06-21
- **Escopo:** PR atualizado, branch `infra/phase1-credentialed-apply-env` — pós `task_phase1_devops_harden_apply_pipeline` + ações out-of-band do Product Lead.
- **Anterior:** `SEC-0005` ⛔ (DEC-0007 §2a não satisfeita: SEC-F17/F18 bloqueantes, SEC-F19/F20 condições).
- **Mandato:** DEC-0007 §2a · matrix #8 · INFRA-0001 §5/§7 · HANDOFF-phase1-harden-apply-pipeline.

---

## 0. Veredito

✅ **SEM BLOQUEIO.** Os 2 bloqueantes (SEC-F17, SEC-F18) e as 2 condições (SEC-F19, SEC-F20) do SEC-0005 estão **fechados**. **DEC-0007 §2a satisfeita** → gate (a) do quadro SEC-0005 §6 **BAIXADO**.

Libera o caminho **DEC-0007 §2b** (PR revisado + mergeado na `main`, sem push direto) → e, downstream, `database_agent:run_migration` (gated). **Nenhum apply/merge nesta tarefa** (auditoria read-only).

*(Vetos à parte, intactos: **Fase 9 — RLS Policies**, SEC-0001 §0. Este aval cobre só o ambiente credenciado de apply da Fase 1.)*

---

## 1. SEC-F17 (SHA-pin) — FECHADO e VERIFICADO EXTERNAMENTE

| Verificação | Resultado |
|---|---|
| 3 `uses:` por commit SHA completo (40 hex) + comentário de versão | ✅ L64, L67, L111 |
| Zero tag mutável (`@vN`/`@main`/`@master`/`@latest`) no workflow | ✅ grep em `.github/` → vazio |
| **SHA ↔ release tag oficial (não fabricado)** — verificado na **API do GitHub** | ✅ **bate exato:** `actions/checkout@v4.3.1` → `34e114876b0b11c390a56381ad16ebd13914f8d5`; `supabase/setup-cli@v1.7.1` → `ab058987d8d6c725971f6cf9d0b5c98467e30bd1` |

Não confiei na atestação: consultei `api.github.com/repos/{owner}/{repo}/commits/{tag}` para os dois e os SHAs pinados são os commits reais das tags oficiais. Vetor de exfiltração via supply chain (tag repointada) **fechado**. Follow-up de processo: re-pinar conscientemente a cada bump (INFRA §5.1).

---

## 2. SEC-F19 (service key fora do CI) — FECHADO

| Verificação | Resultado |
|---|---|
| `secrets.SUPABASE_SERVICE_ROLE_KEY` / `SERVICE_KEY` no CI | ✅ grep em `.github/` → vazio (passo de API removido; workflow termina no `verify`/psql L142) |
| Prova de SEC-F16 permanece autoritativa | ✅ em banco via `set role service_role` no `phase1_post_apply_verify.sql` — **não usa** a service key |
| Verificação pós-apply §4/§5 intacta | ✅ job `verify` presente e inalterado |
| Docs reconciliadas | ✅ INFRA-0001 §2.1 (2 secrets + nota) e §4.2 (prova de banco) atualizadas |

O secret de maior raio de explosão (bypass total de RLS) está fora da superfície do CI — e deixa de compor com qualquer risco residual de supply chain.

---

## 3. SEC-F18 (escopo do Environment + sequência) — FECHADO por atestação + rotação

**Decisão de evidência (a barra que a tarefa me pediu para fixar):** a **confirmação escrita do Product Lead satisfaz** a barra para este bloqueante Alta. Razões:
1. **Barra que eu mesmo defini** em SEC-0005 §3/§4: "screenshot **ou** confirmação". Aceitar a confirmação não é mover a trave — é honrar o critério publicado.
2. **Controle out-of-band por desenho:** deployment branch rules / reviewers são config do GitHub, **não verificáveis no repo** e proibido eu tocar valores. Para um controle fora do alcance do artefato auditado, a **atestação do dono responsável** (o Product Lead) é a forma de evidência correta.
3. **Rotação elimina a janela de exposição:** o ponto decisivo. Os secrets foram populados **antes** da branch rule (exposição potencial reconhecida em INFRA §7). O Product Lead atestou: regra `= main` configurada **+** `SUPABASE_ACCESS_TOKEN` rotacionado (novo token, secret atualizado, antigo **revogado**) **+** `SUPABASE_DB_PASSWORD` resetado e atualizado. Mesmo que tenha havido janela, **as credenciais que poderiam ter vazado já estão inválidas**.

| Item atestado (Product Lead) | Aceito |
|---|---|
| Deployment branch rule do `production-db` = `main` | ✅ |
| Sequência de exposição remediada por rotação dos 2 secrets (token novo+revogação; senha resetada) | ✅ — fecha o risco residual |
| `SUPABASE_SERVICE_ROLE_KEY` removida do Environment | ✅ (reforça SEC-F19 no plano de vault) |
| Required reviewers confirmados (AdeptLabsDev encarna DevOps+Security em runtime) | ✅ |

**Residual não-bloqueante (belt-and-suspenders):** a eficácia da branch rule é **re-confirmável de forma independente no 1º run** — um `workflow_dispatch` a partir de uma branch ≠ `main` deve ser **negado** ao acessar o Environment. Registrar essa observação no primeiro apply (eu sou required reviewer em runtime e verei a origem do run). Não trava o merge.

---

## 4. SEC-F20 (rotação/revogação) — FECHADO (documentado + rotação inicial executada)

- ✅ Política documentada em INFRA-0001 §5.2: gatilhos (pós-apply, troca de pessoal, periódica ≤90d), revogação imediata de tokens de teste pós-apply, access token escopado ao mínimo, conduta em suspeita de leak.
- ✅ Rotação inicial **executada** (atestada em §3).
- 🔁 **Gatilho permanente registrado:** revogar tokens temporários/de teste **imediatamente após o apply** — follow-up pós-apply (não bloqueia o merge).

---

## 5. Re-varredura de secrets — PASSA (re-confirmado)

`sbp_` / `eyJ` / `-----BEGIN` / URL com credencial → sem ocorrências reais. Único `eyJ` é substring de hash `integrity` do `pnpm-lock.yaml` (não é JWT); as demais menções dos padrões estão só no texto do SEC-0005. Nenhum `.env` real rastreado (só `.env.example` com chaves vazias). **Zero secret em arquivo versionado.**

Pontos fortes do SEC-0005 §5 preservados: `permissions: contents: read`, manual-only + frase `APPLY-PHASE1`, required reviewers, URL mascarada, apply atômico, verificação §4/§5 autoritativa em banco.

---

## 6. Quadro consolidado do `run_migration` (atualiza SEC-0005 §6 / DEC-0007)

| Gate | Estado |
|---|---|
| Veto técnico do Security (SQL) — SEC-0004 | ✅ baixado |
| Aprovação humana da migration — DEC-0006 | ✅ concedida |
| `audit_secrets` sem bloqueio — DEC-0007 (a) | ✅ **BAIXADO — este doc (SEC-0006)** |
| PR revisado + mergeado na `main` — DEC-0007 (b) | ⏳ próximo passo (sem push direto, #12) |
| Required reviewers em CI — INFRA-0001 §3 | ⏳ em tempo de execução (1º run) |

**Próximo passo:** DEC-0007 §2b — PR revisado (DevOps + Security, matrix #8) e mergeado na `main`. Depois, `database_agent:run_migration` (gated) dispara `phase1-db-apply.yml` → apply + verify §4/§5, com os required reviewers (inclusive Security) aprovando o run e a origem `main` re-confirmando SEC-F18.

**Follow-ups pós-apply (registrados, não bloqueiam):** revogar tokens de teste (SEC-F20); confirmar no 1º run que dispatch de branch ≠ `main` é negado (SEC-F18 residual). Veto da Fase 9 (RLS) segue de pé (SEC-0001 §0).
