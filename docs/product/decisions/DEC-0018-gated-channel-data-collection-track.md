## DEC-0018 — Trilha gated de coleta de Channel Data: reviews de Security (SG-1) + Database (SG-2) **verdes**, gate checklist SG-0..SG-8 registrado; coleta real **NÃO autorizada** (pendente DevOps `define_pipeline`/`configure_env` + dispatch humano)

- **Data:** 2026-07-01
- **Status:** **Registrada — fato consumado (design/review-only).** As reviews de Security e Database da trilha gated (autorizada a iniciar em DEC-0017 item 7) foram concluídas **sem defeito**; a coleta real permanece **barrada** até o restante do gate checklist passar + dispatch humano.
- **Decisor:** Product Lead (disparou `security_agent` + `database_agent`, retornou os `AgentResult`) · registrada pelo Product Orchestrator · autoria DevOps (runbook/handoff), Security (SEC-0019), Database (HANDOFF review)
- **Área:** Coleta (Channel Data) / Segurança & Privacidade (SEC-F23/secret/Environment) / Database (integridade, zero ALTER) / Processo de gate
- **Relaciona:** DEC-0017 (item 6 DC2-01, item 7 autorização), DATA-COLLECT-002, `docs/infra/RUNBOOK-channel-data-collection.md` + `HANDOFF-gated-channel-data-collection.md` (DevOps), `docs/security/SEC-0019-channel-data-collection-review.md`, `docs/database/HANDOFF-channel-data-collection-review.md`

### Contexto
DEC-0017 item 7 autorizou **iniciar** a trilha gated de coleta de Channel Data (`channels.list → raw_youtube_channels`) em modo design/review-only. DevOps autorou o runbook + handoff; o Product Lead disparou as reviews de Security e Database, que retornaram `completed` sem defeito.

### Decisão (o que se registra)

**1. Database — gate SG-2 VERDE (design-only, ZERO ALTER).** `DATA-COLLECT-002 §4.1` é byte-idêntico ao `raw_youtube_channels` aplicado (Fase 4 L128–140); **INSERT-only** sobre shape congelado; **NULL≠0** estrutural. Unicidade `(run_id, channel_id)` + FK composta `ON DELETE RESTRICT` + imutabilidade (triggers) + CHECK anti-segredo de topo como **backstop** confirmados. **DC2-01 fail-closed é IMPOSTO pelo schema** (`raw_json NOT NULL` + FK RESTRICT ⇒ linha-fantasma e veredito órfão impossíveis); tombstone futuro = **tabela irmã aditiva**, nunca `ALTER` no raw. **OPP-04/OPP-05/CHANNEL-03 = DEFER** na forma aditiva sem ALTER (chaves aceitas por F5-05A/F5-06A; `reason` permanece `text`). Sem conexão/apply/secret.

**2. Security — gate SG-1 (dado/secret design) LIBERADO (SEC-0019).** SEC-F23/PII pública **aceitável** (default-deny, minimizado); CHECK **SEC-F08** ratificado (defesa top-level; scrub **body-only** é o autoritativo). Desenho da `YOUTUBE_API_KEY` **aprovado**: Environment dedicado least-privilege, **SEC-F18** main-only, SEC-F19, header `X-Goog-Api-Key`, **zero valor de secret**. Quota ≤ ~10 un/run sem DoS. DC2-01 fail-closed sem vazamento parcial. **Não autoriza execução.**

**3. Findings de Security que CONDICIONAM o 1º run real** (não bloqueiam o design):
- **F-1 (medium · SG-4/`configure_env`):** key portadora de custo sem API-restriction = superfície de abuso/billing → **restringir à YouTube Data API v3 + alerta de quota + rotação ANTES do 1º dispatch**.
- **F-2 (medium · SG-3/`define_pipeline`):** o YAML diverge do template (novo secret/Environment + 1º egress a terceiro) → exige **`audit_secrets` de Security SEPARADO do YAML (matrix #8)**, que **não herda** o SEC-0019.

**4. Governança.** A ação `review_deploy_env` está **fora da allow-list** do `security_agent`; foi executada sob `audit_secrets` + `threat_model` (Owns; matrix #8) e **registra-se como `audit_secrets`** no decision log. (Mesma pegada de ratificação do OPP-08/CHANNEL-04.)

**5. Item aberto OQ-2 (Database → Security):** confirmar postura de `postgres`/DB-password e a **ausência de `FORCE RLS`** — a confirmar no SG-2/Security antes do 1º run.

### Gate checklist SG-0..SG-8 (fonte: SEC-0019; fail-closed — nada roda até SG-0..SG-6 verdes + dispatch humano)
| Gate | Conteúdo | Estado |
|---|---|---|
| **SG-0** | Pré-requisito: SEC-F23 de vídeos fechado (residuais) | herdado |
| **SG-1** | `audit_secrets` do DADO (SEC-0019): SEC-F23/PII + CHECK SEC-F08 + desenho da key | ✅ **verde** |
| **SG-2** | Database review: zero ALTER, FK/unicidade/imutabilidade, DC2-01 (+ OQ-2) | ✅ **verde** (OQ-2 a confirmar) |
| **SG-3** | DevOps `define_pipeline` autora `youtube-collection.yml` **+ F-2 (audit_secrets do YAML)** | ⬜ pendente |
| **SG-4** | DevOps `configure_env` (SENSÍVEL/humano): Environment + **F-1 (API-restriction/quota/rotação)** | ⬜ pendente |
| **SG-5** | Testes do job | ⬜ pendente |
| **SG-6** | **Dispatch humano** + frase de confirmação + required reviewers | ⬜ pendente (fronteira humana) |
| **SG-7** | Gate pós-run de completude de canais (set-equality; 1 linha/canal) | ⬜ pós-run |
| **SG-8** | **P5-REPRO-01** — bloqueante **antes do 1º publish** | ⬜ pré-publish |

### Impacto / non-negotiables
Nenhum desvio. **Coleta real NÃO autorizada**; zero coleta/apply/secret/conexão executados. `channel_eligibility`/`raw_youtube_channels` já vivos (zero ALTER). **Fase 9 vetada**; **`0007` parked**; **publish barrado até P5-REPRO-01 (SG-8)**.

### Reversibilidade
Alta — só documentos de review/design. Nada aplicado, coletado ou publicado.

### Sequenciamento (próximo)
1. **`delegate_task` → `devops_agent` (`define_pipeline`)**: autorar `youtube-collection.yml` **gated** (workflow_dispatch + Environment dedicado + required reviewers + SEC-F18 main-only + SHA-pin/SEC-F17 + `contents: read` + URL mascarada + header `X-Goog-Api-Key`), **design-only, sem execução** (SG-3).
2. **Security `audit_secrets` SEPARADO do YAML** (F-2, matrix #8) + **`configure_env`** com API-restriction/quota/rotação (F-1, SG-4).
3. **Dispatch humano** (SG-6) só após SG-0..SG-5 verdes. **P5-REPRO-01** (SG-8) antes de qualquer publish.
4. Fase 9 vetada; `0007` parked.
