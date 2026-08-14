# SEC-0027 — Errata de segurança · Classificação da paridade do verify da Fase 2 (correção canônica do SEC-0008)

- **Task:** `task_a4b_chain_a_security_erratum` · **Action:** `record_erratum` · **Agent:** `security_agent`
- **Data:** 2026-08-14
- **Natureza:** **Errata aditiva.** Corrige o **raciocínio** de um registro de segurança histórico. **Não** reescreve o corpo do `SEC-0008`, **não** revoga seu veredito de gate, **não** altera nenhum artefato executável, de banco ou de pipeline.
- **Registro corrigido:** `docs/security/SEC-0008-phase2-apply-pipeline-audit.md` (2026-06-24) — **§0** e **§2**
- **Registro reinterpretado:** `docs/security/SEC-0009-phase3-runs-artists-ddl-review.md` (2026-06-25) — **§0**, **§0.1**, **§SEC-F21**
- **Autorizada por:** `DEC-0031` (reconciliação de autoridade da Fase 2)
- **Base canônica:** `main` @ `f32c3058baad93ee44757afcec45fd6662a3ec19`

---

## 0. Objeto e veredito

✅ **ERRATA REGISTRADA.** O `SEC-0008` contém uma **classificação factualmente incorreta** do comportamento de paridade do verify da Fase 2. A premissa técnica que sustentava essa classificação foi **falsificada empiricamente** pelo run gated **`28126499334`**, no mesmo dia da emissão do documento.

**Escopo da correção — deliberadamente estreito.** Esta errata corrige **apenas** o raciocínio do `SEC-0008` sobre a estritez do verify: em **§0**, a oração *"e é **mais estrito** que o da Fase 1"* (primeiro parágrafo); e **§2** integralmente. **A última frase do §0 — a reafirmação de que o veto da Fase 9 (RLS Policies, `SEC-0001` §0) permanece intacto — NÃO é superseded e permanece plenamente vigente.** **Não invalida o `SEC-0008` como um todo.** Permanecem **válidos e não tocados** todos os seus demais achados verificados: SHA-pin sem tag mutável, mascaramento da URL de banco, `permissions: contents: read`, ausência de service-key no CI (SEC-F19), `workflow_dispatch`-only + frase `APPLY-PHASE2` + required reviewers do Environment `production-db`, ausência de secret em SQL/workflow/handoff, ausência de tabela de marketplace, e os controles herdados SEC-F18/SEC-F20. O **veredito de gate `audit_secrets` (matrix #8) permanece BAIXADO** — a pipeline nunca foi o defeito.

## 1. A classificação falsificada

O `SEC-0008` afirmou, em **§0**:

> "o verify satisfaz a condição do **SEC-0007 §4** … e é **mais estrito** que o da Fase 1."

e, em **§2** ("Verify de paridade (SEC-0007 §4) — SATISFAZ, e com rigor extra"):

> "**Por que isto é mais forte que a Fase 1 (e correto):** a Fase 1 tolerava `restrict_violation OR insufficient_privilege`; a Fase 2 exige **só `restrict_violation`**. Como a migration revoga apenas de `anon`/`authenticated`, o `service_role` **retém** os grants de DML — então o **único** mecanismo que bloqueia truncate/update/delete é o **trigger**."

**A premissa em negrito é falsa neste projeto.** O `service_role` **não retinha** capacidade de DML sobre as tabelas criadas por essas migrations. Como consequência, a conclusão derivada dela — que a estritez extra era um endurecimento correto — também é falsa.

O mesmo §2 chegou a descrever o cenário real, mas classificou-o incorretamente:

> "**Fail-closed confirmado:** se num ambiente o `service_role` não tiver o grant, o `truncate` levantaria `insufficient_privilege` — **não** capturado → o job falha (sinal a investigar). Erra para falhar, nunca para um falso 'passou'. Correto."

O cenário previsto **era o cenário real e permanente** do projeto, não uma contingência de ambiente. O resultado não foi um "sinal a investigar": foi um **falso-negativo de teste** que reprovou um schema correto.

## 2. Evidência da falsificação

A Fase 2 teve **dois** runs gated distintos do `phase2-db-apply.yml`, ambos `run_attempt: 1` (não são re-tentativas do mesmo dispatch). **Distinguir os dois é indispensável e não é opcional:** eles compartilham data, workflow e resultado de `apply` (ambos ✅), diferindo apenas no *head* e no resultado do `verify`. São facilmente confundíveis, e confundi-los **inverte o sentido da evidência** — o run verde passaria a ser lido como prova da falha:

| Run | Head | Momento | `apply` | `verify` | Papel |
|---|---|---|---|---|---|
| **`28126499334`** | `f1cc622d` (merge do PR #2) | 2026-06-24 20:10:04Z · **pré-hotfix** | ✅ success | ❌ **failure** | **É este o run que falsificou a premissa do `SEC-0008`.** |
| `28129447446` | `5db56ef8` (merge do PR #3) | 2026-06-24 21:03:19Z · **pós-hotfix** | ✅ success | ✅ success | Run verde subsequente (dispatch próprio, não re-tentativa); é a evidência de conclusão citada pelo `DEC-0010`. **Não** é o run da falha. |

Detalhe do run falsificador **`28126499334`**:

| Item | Evidência |
|---|---|
| Jobs | `Confirm intent` ✅ · `Apply Phase 2 migration` ✅ · **`Post-apply verification (§4 structural + §5 empirical)` ❌ failure** |
| Erro observado | `permission denied for table rubric_versions` |
| Classificação do erro | **`insufficient_privilege` / SQLSTATE `42501`** — bloqueio no *grant layer* |
| Consequência mecânica | a mutação foi barrada **antes** de alcançar o trigger; o bloco `except` do verify capturava **apenas** `restrict_violation`; o `do $$` levantou; `ON_ERROR_STOP=1` reprovou o job |
| Estado real do schema | **correto o tempo todo** — a imutabilidade estava provada, apenas por um mecanismo diferente do previsto pelo teste |

## 3. Interpretação correta (autoridade corrente)

1. A exigência de **só `restrict_violation`** no §5 do `phase2_post_apply_verify.sql` **não era hardening**. Era uma **regressão de paridade** em relação ao verify da Fase 1, que aceitava deliberadamente os dois errcodes.
2. **Bloqueio por *grant* OU por *trigger* comprovam imutabilidade igualmente.** O verify deve aceitar ambos.
3. **Nenhuma garantia é afrouxada** ao alargar o errcode: a existência do trigger continua provada **separadamente** pela checagem estrutural §4.
4. O estado de grant do `service_role` é **dependente de ambiente**; um verify que assume um mecanismo de bloqueio específico produz falso-negativo quando o outro mecanismo atua primeiro.

Esta lição foi subsequentemente incorporada **antes do apply** nas Fases 3, 4 e 5 (`SEC-F21`/`SEC-F22`, `SEC-0010`, `SEC-0012` §4, `SEC-0014` §2) e permanece vigente.

## 4. Proveniência do reparo

O reparo técnico já ocorreu no momento do incidente e **não é alterado por esta errata**:

- **PR #3** / commit **`a5e68b9`** — *"align verify immutability assertions"* — restaurou `restrict_violation OR insufficient_privilege` nos 3 blocos de imutabilidade do §5, em paridade com a Fase 1. O run gated seguinte, **`28129447446`** (head `5db56ef8`, merge do PR #3), passou **verde** nos três jobs.

## 5. Split canônico de atribuição

Esta errata **não** reivindica a evidência de conclusão da Fase 2, que já tem autoridade própria:

| Fato | Autoridade canônica |
|---|---|
| Apply/verify da Fase 2 concluídos; run `28129447446`; `OD-PROV-02` resolvida | **`DEC-0010-phase2-apply-completed.md`** |
| **Correção da classificação do `SEC-0008`** | **`SEC-0027`** (este documento) |
| Identidade do número `DEC-0009` | `DEC-0009-phase3-apply-completed.md` (**Fase 3**) |
| Origem histórica da correção | `42c595218c6a7ebaa958597aa8cc26b86925e1b5:docs/product/decisions/DEC-0009-phase2-versioning-completed.md` — **proveniência apenas, não autoridade corrente** |

⚠️ **Registro explícito, para não se perder:** o `DEC-0010` **não contém** a correção do `SEC-0008`. Seu gate board registra `SEC-0008 | ✅ sem bloqueio` sem ressalva quanto ao raciocínio falsificado — ele cita o *reparo* (PR #3 / `a5e68b9`), mas não corrige a *classificação*.

**Precisão necessária, porque a distinção é o objeto desta errata:** não é verdade que a correção estivesse ausente de `main`. Seu **conteúdo** está em `main` desde 2026-06-25, no **§0.1 do `SEC-0009`** (ver §6). O que faltava era **assento de autoridade**: o §0.1 é o reconhecimento do autor dentro de um documento de *outra* fase, e **atribui a correção a um "DEC-0009" que, em `main`, não a contém**. Nenhum documento corrente estava vinculado ao próprio `SEC-0008` como sua correção. Este documento é o **primeiro assento canônico** dessa correção — e o `SEC-0008` passa a apontar para ele.

## 6. Reinterpretação do SEC-0009 (atribuição, não mérito)

O `SEC-0009` (2026-06-25) escreveu, em **§0.1** — *"Reconciliação honesta com DEC-0009 (correção do meu SEC-0008)"*:

> "DEC-0009 corrigiu o registro do meu **SEC-0008** …"

e cita "DEC-0009" também em **§0** e no achado **SEC-F21**.

**O mérito técnico do `SEC-0009` está integralmente correto e não é tocado.** O autor identificou a regressão de paridade **antes do apply** da Fase 3 e a transformou em achado bloqueante — exatamente o comportamento desejado. O que mudou foi apenas a **identidade** do documento citado:

- naquele momento, "DEC-0009" denotava o **registro local da Fase 2** (hoje o órfão em `42c595218c6a7ebaa958597aa8cc26b86925e1b5`), que continha a correção;
- em `main`, o número `DEC-0009` foi posteriormente vinculado ao fechamento da **Fase 3**, que **não** menciona o `SEC-0008`.

**Leitura canônica das citações históricas do `SEC-0009`:** evidência do run da Fase 2 → **`DEC-0010`**; correção do `SEC-0008` → **`SEC-0027`**; origem histórica → o órfão, por SHA + caminho.

## 7. Preservação histórica

Os corpos do `SEC-0008` e do `SEC-0009` são preservados **byte-a-byte**, verbatim, abaixo de seus respectivos banners aditivos. **Nenhum byte histórico foi removido, reescrito ou substituído** — em particular, **não** houve substituição de "DEC-0009" dentro dos corpos históricos. Isso segue a doutrina aditiva vinculante do repositório (`DEC-0022` §4; `DEC-0023` §D-F — *"anotar SUPERSEDED / adicionar adendo; nunca reescrever o corpo original"*) e a forma de banner já praticada em `DATA-CHANNEL-001` e `DATA-CONST-001`.

## 8. O que esta errata NÃO afirma

- **Não** afirma que a pipeline de apply da Fase 2 era insegura — não era; o gate `audit_secrets` segue corretamente baixado.
- **Não** afirma que o schema da Fase 2 estava errado — estava correto, e a evidência do run o comprova.
- **Não** afirma que o `DEC-0010` contém esta correção — comprovadamente não contém (§5).
- **Não** afirma que o `SEC-0009` errou tecnicamente — não errou; apenas citou uma identidade que depois foi revinculada.
- **Não** autoriza qualquer mudança operacional de PostgreSQL/Supabase, migration, rollback, workflow, Environment ou secret.
- **Não** destrava nenhum gate downstream. O **veto da Fase 9 — RLS Policies (`SEC-0001` §0)** permanece de pé.
