# SEC-0020 — Security Audit (audit_secrets) · Pipeline `youtube-collection.yml` (F-2 / SG-3, matrix #8)

- **Task:** `task_security_audit_youtube_collection_yaml` · **Action:** `audit_secrets` · **Agent:** `security_agent`
- **Data:** 2026-07-01
- **Matriz:** `agent-review-matrix.md` **#8** (deploy/mudança de ambiente → DevOps + Security) — **desvio de template**; **NÃO herda** o SEC-0019 (SG-1).
- **Alvo primário:** `.github/workflows/youtube-collection.yml` (PR #16)
- **Inputs revisados:**
  - `.github/workflows/youtube-collection.yml` (PR #16)
  - `docs/infra/HANDOFF-youtube-collection-pipeline.md`
  - `docs/security/SEC-0019-channel-data-collection-review.md` (SG-1, precedente do gate F-2)
  - `docs/product/decisions/DEC-0018-gated-channel-data-collection-track.md`
  - Precedente já liberado: `.github/workflows/entity-db-apply.yml` (SEC-0018)
- **Origem do gate:** **SEC-0019 F-2 / SG-3** — o YAML diverge do template e exige auditoria própria antes de poder ser **armado**.
- **Mandato:** **AUDIT-ONLY.** Sem execução, sem armar, sem provisionar secret, sem coleta. Não autoriza run. Poder de veto. **Silêncio ≠ aprovação. Zero valor de secret neste doc.**

---

## 0. Veredito

✅ **PIPELINE APROVADO — postura fail-closed e higiene de secret/credencial CORRETAS. #16 pode mergear (o YAML landa DESARMADO e inerte).** O workflow espelha fielmente a espinha gated já liberada (`entity-db-apply.yml`) e endereça **corretamente** o delta de template (F-2): novo secret `YOUTUBE_API_KEY` env-only, Environment dedicado least-privilege sem token de migration, 1º egress externo atrás de dupla-gate humana, escrita irreversível reconhecida por input explícito. **Confirmo o gate fail-closed de arm: DESARMADO por construção** — o marcador `.github/collection/youtube-collection.armed`, o collector e os testes/§7 estão **ausentes** (verificado), e o `guard` aborta todo dispatch enquanto faltarem. Landar este YAML na `main` **não coleta nada**.

⚠️ **Um finding de hardening (F-3, severidade BAIXA) — não bloqueia a postura fail-closed nem o merge do YAML desarmado, mas é CONDIÇÃO antes de SG-4/arm** (quando o pipeline se torna live-capable). O `guard` interpola `${{ inputs.* }}` e `${{ github.ref }}` **diretamente** em scripts `run:` (script-injection pattern), enquanto o padrão seguro (`env:`-indireção) **já é usado** para `RUN_ID` em `collect`/`verify` no mesmo arquivo. Fix trivial; recomendo dobrá-lo no próprio #16. Detalhe em §4.

⛔ **Este doc NÃO autoriza run.** Ele libera o **desvio de template do YAML** (F-2 = verde, com F-3 registrado). A coleta real permanece atrás de **SG-4** (`configure_env` — inclui **F-1**, sensível/humano-gated, Security co-assina), **SG-5** (collector + testes §8), **SG-6** (dispatch humano + frase + acknowledge + required reviewers), **SG-7** (§7 pós-run) e **SG-8** (P5-REPRO-01 antes do 1º publish).

---

## 1. Desvio de template — o que NÃO herda o SEC-0019 e por quê está endereçado

O YAML é um mirror fiel da espinha gated (`workflow_dispatch` + frase + Environment required reviewers + SEC-F18 + SEC-F17 SHA-pin + `contents:read` + URL mascarada + service-role não usada), **mas diverge materialmente** — por isso a auditoria separada (F-2):

| Dimensão do desvio | Risco novo | Endereçamento no YAML | Veredito |
|---|---|---|---|
| **`YOUTUBE_API_KEY`** (1ª credencial portadora de custo no CI, viaja em request) | Vazamento/abuso = queima de quota/billing | `secrets.YOUTUBE_API_KEY` **env-only** (L220), auto-mask do GitHub, header `X-Goog-Api-Key` (never `?key=`, L48–50/L219), body-only (scrub+CHECK SEC-F08 são do collector, SG-5) | ✅ (com **F-1** em SG-4) |
| **1º egress externo real** (`googleapis.com`) | Saída de rede a API de 3º | Só no job `collect`, atrás de Environment + required reviewers (L185) + arm gate (L138) | ✅ |
| **Escrita IRREVERSÍVEL** em raw imutável | Sem rollback; run ruim = run falha | Input explícito `acknowledge_irreversible` (L75–78, L108) + `verify` roda gate §7 set-equality (L270–282); DC2-01 fail-closed documentado (L52–55) | ✅ |
| **Environment NOVO `youtube-collection`** (topologia) | Misturar blast radius com token de migration | Dedicado, **sem `SUPABASE_ACCESS_TOKEN`** → **estruturalmente incapaz de `db push`** (L46–47, L197–198); OQ-1 honrado | ✅ |

**Conclusão §1:** o desvio está **corretamente isolado e mitigado**. O YAML **não** herda a liberação SG-1; esta auditoria (F-2) é a liberação própria do pipeline.

## 2. Higiene de secret/credencial — checklist do escopo (todos confirmados)

| Item de higiene | Veredito | Evidência (linha) |
|---|---|---|
| **SHA-pin (SEC-F17)** de todas as actions de 3º | ✅ | `checkout@34e1148…` (L99/188/245) — **byte-idêntico** aos 8 workflows de apply já em `main` (cleared SEC-0013/0015/0018). `setup-python@0b93645…#v5.3.0` (L191) — **idêntico** ao `data-engine-tests.yml`; corroborado no repo; SHA imutável independ? do tag. Nenhuma tag flutuante. |
| **`permissions: contents: read`** (least-privilege do GITHUB_TOKEN) | ✅ | Top-level (L80–81) → aplica a todos os jobs. Coleta escreve no **DB** (não no GitHub); `contents:read` é o mínimo (só checkout). Sem `id-token`/`packages`/write. |
| **SEC-F18 `main`-only** | ✅ **reforçado** | **Backstop no `guard`** (`github.ref == refs/heads/main`, L124–136) — **não depende** da branch rule do Environment existir (fecha o footgun do "Environment novo auto-criado sem proteção"). Branch rule do Environment vem em SG-4 como 2ª camada. |
| **Required reviewers DevOps+Security** | ✅ | `environment: youtube-collection` nos jobs `collect` (L185) e `verify` (L242) — aprovação humana em tempo de execução (SG-6). |
| **service-role NÃO usada (SEC-F19)** | ✅ | Nenhuma referência a `SUPABASE_SERVICE_ROLE_KEY`. Escrita via owner `postgres` (session pooler, L195–212); Environment sem `SUPABASE_ACCESS_TOKEN`. |
| **URL de conexão mascarada** | ✅ | `::add-mask::${url}` **antes** de escrever em `$GITHUB_ENV` (L211, L267); senha vem de `secrets.*` (auto-mask) e é URL-encoded via `jq @uri` (L209/265). |
| **Header `X-Goog-Api-Key` / never `?key=` (OQ-6)** | ✅ | Fixado em comentário normativo (L48–50, L219); **nenhum `?key=`** aparece no YAML. Transporte real é responsabilidade do collector (SG-5, testado em §8.3 canary). |
| **ZERO valor de secret no YAML** | ✅ | Só **nomes** (`secrets.YOUTUBE_API_KEY`, `secrets.SUPABASE_DB_PASSWORD`). Único literal é `SUPABASE_PROJECT_REF` (L91) — **não-secret** (aparece na URL pública do projeto). |

## 3. Gate fail-closed de arm — DESARMADO por construção (confirmado)

O controle **load-bearing**: landar o YAML na `main` **nunca** pode coletar. O `guard` (L138–177) roda **fora de qualquer Environment/secret** e aborta todo dispatch enquanto faltar **qualquer** dos 4 artefatos abaixo. **Verifiquei a ausência dos quatro:**

| Artefato exigido para "armado" | Caminho | Estado (verificado) |
|---|---|---|
| Marcador de arm explícito | `.github/collection/youtube-collection.armed` | **AUSENTE** ✅ (committado só em SG-4, ato consciente do DevOps) |
| Collector (SG-5) | `services/data-engine/src/noxund_data_engine/channel_collection.py` | **AUSENTE** ✅ |
| Testes §8 do collector (SG-5) | `services/data-engine/tests/test_channel_collection.py` | **AUSENTE** ✅ |
| Gate §7 pós-coleta (SG-5/SG-7) | `supabase/tests/channel_data_post_collection_verify.sql` | **AUSENTE** ✅ |

**Por que a colocação é correta (e não teatral):** o gate está no `guard`, que **não referencia Environment** — logo roda **antes** de qualquer acesso a secret e é imune ao footgun do "Environment novo referenciado é auto-criado pelo GitHub SEM required reviewers/branch rule". Mesmo que alguém dispare com o Environment ainda desprotegido, o `guard` aborta na preflight de arm **sem** ter tocado secret. **Defesa em profundidade real:** o arm marker é condição **necessária**, não suficiente — o gate humano do Environment (required reviewers) no `collect` continua valendo mesmo depois de armado (L177/183–185).

**Ordem fail-closed dentro do `guard`:** frase+acknowledge (L101–112) → UUID do `run_id` (L114–122) → SEC-F18 `main` (L124–136) → arm preflight (L138–177). Cada passo é `exit 1` em falha. ✅

## 4. Finding F-3 (severidade BAIXA · hardening) — script-injection no `guard`

**Onde.** O `guard` interpola expressões `${{ … }}` **diretamente** dentro de scripts `run:` (bash), o anti-pattern de script-injection do GitHub Actions:

- L104 — `if [ "${{ inputs.confirm }}" != "RUN-CHANNEL-COLLECTION" ]; then`
- L108 — `if [ "${{ inputs.acknowledge_irreversible }}" != "…" ]; then`
- L117 — `rid="${{ inputs.run_id }}"`
- L132 — `if [ "${{ github.ref }}" != "refs/heads/main" ]; then`

`${{ … }}` é expandido como **texto bruto antes** do shell parsear a linha. Um valor de input com metacaracteres de shell (ex.: `confirm` = `x" ; <cmd> ; "`) é **injetado** no script. `set -euo pipefail` **não** protege — a injeção ocorre na fase de parse.

**Por que a severidade é BAIXA (calibração honesta), não crítica:**
1. `workflow_dispatch` **exige acesso de escrita** ao repo → o ator já é colaborador de confiança, não anônimo/externo.
2. O `guard` roda com `permissions: contents: read` e **NENHUM Environment/secret** → código injetado no `guard` **não alcança** `YOUTUBE_API_KEY` nem `SUPABASE_DB_PASSWORD` (vivem só no Environment `youtube-collection`, acessado por `collect`/`verify`).
3. As **duas** gates que realmente protegem execução/secret **não são bypassáveis** pelo `guard`: (a) o `collect` referencia o Environment **independentemente** e exige aprovação dos required reviewers mesmo que o `guard` seja comprometido; (b) o arm marker é um arquivo **committado** (protegido por branch protection da `main`). Injeção no `guard` não commita marker nem aprova Environment.

**Por que ainda assim exijo o fix (padrão world-class · fix trivial):** o padrão **seguro já existe no mesmo arquivo** — `RUN_ID` é passado por `env:` (L221, L272) e usado como `"$RUN_ID"` (L236, L281). Não há razão para o `guard` usar o padrão inseguro. Deixar o anti-pattern num pipeline gated de coleta irreversível normaliza um vetor evitável.

**Mitigação exigida (antes de SG-4/arm; recomendo dobrar no #16):** rotear `inputs.confirm`, `inputs.acknowledge_irreversible`, `inputs.run_id` e `github.ref` por `env:` e referenciar como `"$VAR"` no script — exatamente como `collect`/`verify` já fazem com `RUN_ID`. Ex.:

```yaml
      - name: Validate confirmation + irreversibility acknowledgement
        env:
          CONFIRM: ${{ inputs.confirm }}
          ACK: ${{ inputs.acknowledge_irreversible }}
        run: |
          set -euo pipefail
          if [ "$CONFIRM" != "RUN-CHANNEL-COLLECTION" ]; then …
          if [ "$ACK" != "I-UNDERSTAND-RAW-IS-IRREVERSIBLE" ]; then …
```

**Classificação:** F-3 **não** bloqueia o merge do YAML desarmado (nada roda; o `guard` é secret-free; a postura fail-closed se mantém), **mas é condição verde de SG-4** antes de committar o arm marker. Registrado no gate checklist (§7).

## 5. F-1 permanece condição de SG-4 (não bloqueia o YAML)

Conforme SEC-0019, a `YOUTUBE_API_KEY` **DEVE** ser restrita à *YouTube Data API v3* no console GCP + **alerta de quota** + **política de rotação** (pós-run/pessoal/≤90d/leak) **antes** do 1º dispatch. Isso é ato de **`configure_env` (SG-4)**, fora do YAML — corretamente reconhecido no header do YAML (L30–32) e no handoff (§8.2). **Registrado como gate, não bloqueia esta liberação do #16.** Security **co-assina** SG-4.

## 6. Observações não-bloqueantes (defesa-em-profundidade / paridade com precedente)

- **`sudo apt-get install postgresql-client` no `verify` (L247–251)** — pacote apt não-pinado, dos mirrors oficiais do runner Ubuntu. **Idêntico ao precedente** `entity-db-apply.yml` (cleared SEC-0018). Aceito; nota de supply-chain de baixo risco.
- **`collect` **e** `verify` ambos em `environment: youtube-collection`** — required reviewers aprovam **duas vezes** (uma por job). É **mais** fricção, estritamente **não-menos** seguro (re-aprovação do verify). Paridade com `apply`+`verify` do precedente. Operacional, não-finding.
- **Máscara da URL vs. senha URL-encoded** — `::add-mask::${url}` cobre a URL inteira; a senha crua (de `secrets.*`) é auto-mascarada. O fragmento **percent-encoded** da senha só é coberto **no contexto da URL** (auto-mask casa a string exata do secret). O collector persiste **body-only** e nunca manuseia a DB URL como dado, então não há caminho de vazamento do fragmento isolado. **Padrão idêntico ao precedente**; aceito.

## 7. Estado do gate checklist SG (atualização deste doc)

| Gate | Conteúdo | Estado |
|---|---|---|
| **SG-1** | `audit_secrets` do DADO (SEC-0019) | ✅ verde |
| **SG-2** | Database (zero ALTER, FK/imutabilidade, DC2-01) | ✅ verde (OQ-2 a confirmar no provisionamento) |
| **SG-3** | DevOps `define_pipeline` (YAML) **+ F-2 `audit_secrets` do YAML (ESTE doc)** | ✅ **verde — YAML aprovado; F-3 (hardening) condiciona SG-4** |
| **SG-4** | DevOps `configure_env` (SENSÍVEL/humano): Environment + **F-1** (API-restriction/quota/rotação) + **F-3** (fix do guard) + confirmar **ausência de `FORCE RLS`** (OQ-2). Security co-assina. **Só então committar o arm marker.** | ⬜ pendente |
| **SG-5** | Collector + testes §8.1–§8.6 + gate §7 SQL | ⬜ pendente (ausente = desarmado) |
| **SG-6** | Dispatch humano + frase + acknowledge + required reviewers | ⬜ fronteira humana |
| **SG-7** | Gate §7 pós-run (set-equality) | ⬜ pós-run |
| **SG-8** | **P5-REPRO-01** antes do 1º publish | ⬜ pré-publish |

**Vetos intransponíveis:** Fase 9/RLS Policies (raw default-deny: RLS-on + revoke, zero policy/view — **não tocado** pelo YAML); `0007`/producer_events **PARKED**; publish barrado até P5-REPRO-01.

**Confirmação OQ-2 (side do YAML):** o YAML usa o caminho owner `postgres` (`DB_USER` default `postgres.${ref}`, L207/263) e **não** usa service-role — consistente com a postura acordada. A **ausência efetiva de `FORCE ROW LEVEL SECURITY`** é fato de banco, a confirmar no ato do `configure_env`/provisionamento (SG-4).

---

## AgentResult

```json
{
  "task_id": "task_security_audit_youtube_collection_yaml",
  "agent": "security_agent",
  "status": "completed",
  "summary": "audit_secrets do pipeline youtube-collection.yml (PR #16, F-2/SG-3, matrix #8 desvio de template) concluida AUDIT-ONLY. VEREDITO: PIPELINE APROVADO — postura fail-closed e higiene de secret/credencial corretas; #16 pode mergear (landa DESARMADO). Confirmados: SHA-pin SEC-F17 (checkout byte-identico aos 8 applies em main; setup-python identico ao data-engine-tests.yml), permissions contents:read, SEC-F18 main-only (backstop no guard + branch rule SG-4), required reviewers DevOps+Security nos jobs collect/verify, service-role NAO usada (SEC-F19, sem ACCESS_TOKEN -> incapaz de db push), URL mascarada (::add-mask::), header X-Goog-Api-Key/never ?key=, ZERO valor de secret (so nomes). Gate fail-closed de arm CONFIRMADO desarmado por construcao: .armed marker + collector + testes + verify SQL AUSENTES (verificado) -> guard aborta todo dispatch; guard roda fora de Environment/secret (imune ao footgun de Environment auto-criado sem protecao). FINDING F-3 (baixa/hardening): guard interpola ${{ inputs.* }}/${{ github.ref }} direto em run: (script-injection) enquanto collect/verify ja usam o padrao seguro env:->$VAR; nao bloqueia o merge desarmado (guard e secret-free, dispatch exige write, gates reais nao bypassaveis) mas e CONDICAO antes de SG-4/arm — recomendo dobrar o fix no #16. F-1 (API-restriction/quota/rotacao da key) permanece condicao de SG-4/configure_env. NAO autoriza run.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/security/SEC-0020-youtube-collection-pipeline-audit.md",
      "description": "Criado: audit_secrets do pipeline gated youtube-collection.yml (F-2/SG-3, matrix #8) — veredito do YAML, checklist de higiene (SHA-pin/contents:read/SEC-F18/SEC-F19/URL mascarada/X-Goog-Api-Key/zero secret), confirmacao do gate fail-closed de arm (desarmado por construcao), finding F-3 (script-injection no guard) e registro de F-1 como condicao de SG-4."
    }
  ],
  "errors": [],
  "findings": [
    {
      "id": "F-3",
      "severity": "low",
      "type": "hardening",
      "gate": "SG-4/arm (recomendo folding no #16)",
      "blocking_for": "arm (SG-4); NAO bloqueia o merge do YAML desarmado",
      "issue": "Job guard interpola ${{ inputs.confirm }} / ${{ inputs.acknowledge_irreversible }} / ${{ inputs.run_id }} / ${{ github.ref }} diretamente em scripts run: (script-injection pattern; L104/108/117/132). set -euo pipefail nao protege (injecao ocorre no parse). Mitigado por: dispatch exige write access, guard e secret-free (contents:read, sem Environment), e as gates reais (Environment required reviewers + arm marker committado) nao sao bypassaveis pelo guard.",
      "required_mitigation": "Rotear os 4 valores por env: e referenciar como \"$VAR\" no script — mesmo padrao ja usado para RUN_ID em collect/verify (L221/236, L272/281). Fix trivial; aplicar antes de committar o arm marker (SG-4)."
    },
    {
      "id": "F-1",
      "severity": "medium",
      "type": "carried_condition",
      "gate": "SG-4/configure_env",
      "blocking_for": "1st real run",
      "issue": "YOUTUBE_API_KEY portadora de custo sem API-restriction = superficie de abuso/billing (herdado de SEC-0019).",
      "required_mitigation": "Restringir a YouTube Data API v3 no console GCP + alerta de quota + politica de rotacao ANTES do 1o dispatch. Ato de configure_env (SG-4), fora do YAML; Security co-assina."
    }
  ],
  "next_recommendation": {
    "target_agent": "devops_agent",
    "action": "configure_env",
    "priority": "high",
    "reason": "F-2/SG-3 VERDE em SEC-0020: pipeline youtube-collection.yml aprovado (fail-closed, higiene de secret correta); #16 pode mergear desarmado. Proximo gate = SG-4 (SENSIVEL/humano-gated): provisionar Environment youtube-collection (YOUTUBE_API_KEY + DB conn least-privilege sem ACCESS_TOKEN, main-only branch rule ANTES dos secrets, required reviewers DevOps+Security), com F-1 (API-restriction YouTube Data API v3 + alerta de quota + rotacao) e confirmacao de ausencia de FORCE RLS (OQ-2). Aplicar F-3 (env:-indirecao no guard, folding recomendado no #16) e SG-5 (collector+testes) verdes ANTES de committar o arm marker .github/collection/youtube-collection.armed. Security co-assina SG-4 (evidencia out-of-band, precedente INFRA-0001). Nada roda ate SG-4/SG-5/SG-6 verdes + dispatch humano. Fase 9 VETADA; 0007 PARKED; publish barrado ate P5-REPRO-01."
  }
}
```
