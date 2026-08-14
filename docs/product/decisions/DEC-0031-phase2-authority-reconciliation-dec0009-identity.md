# DEC-0031 — Reconciliação de autoridade da Fase 2: identidade do `DEC-0009` e assento canônico da correção do SEC-0008

- **Data:** 2026-08-14
- **Status:** **Registrada — reconciliação de autoridade corrente.** Unidade **docs-only**: nenhum banco, migration, rollback, verify, workflow, Environment, secret, variável, script, dependência ou arquivo de runtime é criado ou alterado por esta decisão.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Governança de decisão / Registro de segurança / Rastreabilidade
- **Escopo:** o grafo de autoridade DEC/SEC da **Fase 2 (Versionamento)**. **Não** reescreve nenhum corpo histórico; **não** altera `DEC-0009-phase3-apply-completed.md` nem `DEC-0010-phase2-apply-completed.md`; **não** promove nenhum artefato histórico a autoridade corrente.
- **Base canônica:** `main` @ `f32c3058baad93ee44757afcec45fd6662a3ec19`
- **Relaciona:** `DEC-0009-phase3-apply-completed.md` (identidade corrente do número 0009) · `DEC-0010-phase2-apply-completed.md` (autoridade canônica da Fase 2) · `SEC-0008-phase2-apply-pipeline-audit.md` (registro corrigido aditivamente) · `SEC-0009-phase3-runs-artists-ddl-review.md` (atribuição reinterpretada aditivamente) · `SEC-0027-phase2-verify-parity-erratum.md` (assento canônico da correção) · `DEC-0022` §4 e `DEC-0023` §D-F (doutrina aditiva — "nunca reescrever o corpo original") · `DEC-0024-ADDENDUM-migration-ordering-policy.md` (precedente de registro aditivo)

---

## 1. Contexto

Ao reconciliar o grafo de autoridade DEC/SEC antes da higiene operacional PostgreSQL/Supabase, o Orchestrator estabeleceu, **a partir de evidência primária do repositório**, uma incoerência de autoridade na Fase 2 que não é um defeito da trilha de apply, e sim do **assento de uma correção de registro de segurança**.

A trilha de apply está correta e permanece intocada: **Fase 1 (`DEC-0008`) → Fase 2 (`DEC-0010`) → Fase 3 (`DEC-0009`) → Fase 4 (`DEC-0011`) → Fase 5 (`DEC-0012`)**. Nenhum documento corrente afirma que o fechamento da Fase 2 ocorreu sob o `DEC-0009` corrente.

O que existe é o seguinte, verificado:

1. Em **2026-06-24**, o `SEC-0008` (audit da pipeline de apply da Fase 2) classificou a estritez do verify da Fase 2 — aceitar **só** `restrict_violation` — como *"mais estrito"* / *"mais forte que a Fase 1 (e correto)"*, apoiado na premissa de que o `service_role` **retinha** os grants de DML.
2. O run gated **`28126499334`** (head `f1cc622d`, merge do PR #2, **pré-hotfix**) falsificou essa premissa: `apply` passou, mas o job `verify` **falhou** com `permission denied for table rubric_versions` (`insufficient_privilege` / **42501**). O bloqueio chegou pelo *grant layer*, antes do trigger.
3. O hotfix **PR #3 / `a5e68b9`** restaurou a paridade de errcode (`restrict_violation OR insufficient_privilege`); o run gated seguinte, **`28129447446`** (head `5db56ef8`, **pós-hotfix**), passou **verde**. **São dois runs distintos** (ambos `run_attempt: 1`) e não devem ser confundidos: `28129447446` é a evidência de conclusão citada pelo `DEC-0010`, **não** o run da falha.
4. Um registro local da Fase 2, datado de **2026-06-24** (commit em 2026-06-25), foi autorado contendo a **correção explícita do SEC-0008**, sob o número `DEC-0009`. Esse commit **nunca foi promovido**: existe apenas em `42c595218c6a7ebaa958597aa8cc26b86925e1b5`, não é ancestral de `main`, e o número `DEC-0009` foi posteriormente vinculado, em `main`, ao fechamento da **Fase 3**.
5. Consequência: a **correção do SEC-0008 nunca teve assento de autoridade corrente**. Seu *conteúdo* chegou a `main` em 2026-06-25, no §0.1 do `SEC-0009` — mas ali é o reconhecimento do autor dentro de um documento de **outra fase**, atribuído a um "DEC-0009" que, em `main`, **não o contém**. Nenhum documento corrente estava vinculado ao próprio `SEC-0008` como sua correção.

Esta decisão fecha essa lacuna **de forma aditiva**, sem reescrever histórico e sem criar um segundo `DEC-0009` ativo.

## 2. Decisão (o que se registra)

**A. A identidade `DEC-0009` está canônica e permanentemente vinculada a `docs/product/decisions/DEC-0009-phase3-apply-completed.md`** (fechamento do gate board do apply da **Fase 3**). O arquivo permanece **inalterado**. Nenhuma decisão futura pode reutilizar o número `DEC-0009`.

**B. O registro histórico da Fase 2 em `42c595218c6a7ebaa958597aa8cc26b86925e1b5:docs/product/decisions/DEC-0009-phase2-versioning-completed.md` é PROVENIÊNCIA APENAS (`HISTORY-ONLY-NO-LAND`).** Ele **não** será promovido a `main` — nem sob o número `DEC-0009`, nem sob qualquer outra identidade DEC corrente renomeada. Permanece preservado e auditável no ref `checkpoint/phase2-verify-hotfix-local-2026-08-11` (local e em `origin`), protegido pelo ruleset **`20727975`** — *"Preserve recovery checkpoints"*, `enforcement: active`, regras `deletion` + `non_fast_forward` + `update`. *(A proteção é por **ruleset de repositório**; o endpoint legado `/branches/*/protection` retorna 404 para este ref e **não** deve ser usado como prova de ausência de proteção.)* Toda citação a ele deve usar **SHA de commit de 40 caracteres + caminho exato**, nunca um wikilink de DEC corrente.

**C. `docs/product/decisions/DEC-0010-phase2-apply-completed.md` é reafirmado como a autoridade canônica de conclusão da Fase 2**, incluindo a evidência do run `28129447446` e a resolução da `OD-PROV-02`. O arquivo permanece **inalterado**.

**D. O registro histórico órfão contém uma correção válida e materialmente correta do `SEC-0008`** — a §"Correção de registro — SEC-0008" — **mas essa correção nunca teve assento de autoridade canônica.** Ela não está no `DEC-0009` corrente (Fase 3) e **não está no `DEC-0010`**: o gate board do `DEC-0010` registra `SEC-0008 | ✅ sem bloqueio` sem ressalva sobre o raciocínio falsificado. Seu *conteúdo* existe em `main` no §0.1 do `SEC-0009`, porém sob atribuição incorreta e em documento de outra fase. **A lacuna é de assento e de atribuição, não de mérito.**

**E. `docs/security/SEC-0027-phase2-verify-parity-erratum.md` é criado como o assento canônico aditivo dessa correção.** A partir desta decisão, a autoridade corrente sobre a classificação do verify da Fase 2 é o `SEC-0027`.

**F. Os corpos históricos do `SEC-0008` e do `SEC-0009` são preservados byte-a-byte**, recebendo **apenas** um banner aditivo prefixado, na forma já praticada no repositório (`DATA-CHANNEL-001`, `DATA-CONST-001`) e vinculante por `DEC-0022` §4 e `DEC-0023` §D-F. **Nenhum byte histórico é removido ou reescrito**, e em particular **não** se faz substituição global de "DEC-0009" dentro dos corpos históricos.

**G. Nenhuma mudança operacional PostgreSQL/Supabase é autorizada por esta decisão.** Workflows, migrations, rollbacks, verifies, scripts de banco, arquivos de ambiente, nomenclatura de `SUPABASE_DB_URL`, runtime do collector, configuração de GitHub App e a instalação do Supabase GitHub App permanecem **intocados** e seguem `DEFER-POSTGRES-SUPABASE-HYGIENE`.

**H. Nenhuma reescrita de contexto de Fase B é autorizada.** `context/**` e o Canonical Context V2 permanecem fora de escopo (`DEFER-PHASE-B`).

## 3. Split canônico de atribuição

| Fato | Autoridade canônica corrente |
|---|---|
| Apply e verify da Fase 2 concluídos; run `28129447446`; resolução da `OD-PROV-02` | **`DEC-0010`** |
| Correção da classificação do verify feita pelo `SEC-0008` | **`SEC-0027`** |
| Identidade do número `DEC-0009` | **`DEC-0009-phase3-apply-completed.md`** (Fase 3) |
| Origem histórica da correção | `42c595218c6a7ebaa958597aa8cc26b86925e1b5:docs/product/decisions/DEC-0009-phase2-versioning-completed.md` — **proveniência apenas** |

As referências históricas a "DEC-0009" no corpo do `SEC-0009` (§0, §0.1, §SEC-F21) devem ser lidas **através** deste split, conforme o banner aditivo do próprio `SEC-0009`.

## 4. Evidência

| Item | Evidência |
|---|---|
| Base canônica | `main` @ `f32c3058baad93ee44757afcec45fd6662a3ec19` |
| `DEC-0009` corrente (Fase 3) | blob `0ae3cac74763ae445fb0347f91c5c0bbe0d3bea2` |
| `DEC-0010` (Fase 2) | blob `f441d895d753785d173fa876fc91466120e85527` |
| `SEC-0008` (corpo histórico preservado) | blob `49aa4ee48ed6d6d3ccb9644a8f025e2c44d43414` |
| `SEC-0009` (corpo histórico preservado) | blob `9308c1146ff2545152c2501dc9cdcc3849225e63` |
| Registro histórico órfão | `42c595218c6a7ebaa958597aa8cc26b86925e1b5:docs/product/decisions/DEC-0009-phase2-versioning-completed.md` (não-ancestral de `main`) |
| Run gated que falsificou a premissa | **`28126499334`** (head `f1cc622d`, merge do PR #2, pré-hotfix) — `apply` ✅, **`verify` ❌** com `permission denied for table rubric_versions` (`insufficient_privilege` / 42501) |
| Hotfix de paridade | PR **#3** / commit **`a5e68b9`** — *"align verify immutability assertions"* |
| Run gated verde (evidência do `DEC-0010`) | `28129447446` (head `5db56ef8`, merge do PR #3, pós-hotfix) — três jobs `success`. **Run distinto do anterior**; ambos `run_attempt: 1` |
| Ref de preservação do órfão | `checkpoint/phase2-verify-hotfix-local-2026-08-11` @ `42c595218c6a7ebaa958597aa8cc26b86925e1b5`, protegido pelo ruleset **`20727975`** ("Preserve recovery checkpoints", `active`: `deletion` + `non_fast_forward` + `update`) |

## 5. Impacto

- **Escopo:** exatamente **4 caminhos** (`DEC-0031`, `SEC-0027` adicionados; `SEC-0008`, `SEC-0009` prefixados aditivamente). Nenhum arquivo executável, de banco, de workflow ou de contexto é tocado.
- **Auditabilidade:** preservada integralmente. O raciocínio falsificado do `SEC-0008` permanece legível como registro do que era verdade em 2026-06-24; a correção passa a ser localizável a partir do próprio documento corrigido.
- **Colisão de identidade:** eliminada por construção — nenhum segundo `DEC-0009` ativo é criado, e o órfão permanece fora de `main`.
- **Não-negociáveis:** inalterados. Nenhum gate downstream é destravado. O **veto da Fase 9 — RLS Policies (`SEC-0001` §0)** permanece de pé.

## 6. Fora de escopo (esta decisão)

Cadeia B (sucessor do `DEC-0027` e reparo de referência do `DEC-0028`) · qualquer edição ao `DEC-0028`/`DEC-0029`/`DEC-0030` · higiene operacional PostgreSQL/Supabase · Canonical Context V2 · `packages/orchestrator/**` e binding de aprovação (`DEFER-PHASE-C`) · qualquer promoção de artefato executável histórico do SG-8 · qualquer commit, push, PR ou merge autorizado por este documento.

## 7. Sequenciamento (próximo)

1. **Cadeia A** (esta unidade) é revisada e mergeada **primeiro**; um novo baseline canônico de `main` é estabelecido em seguida.
2. **Cadeia B** — `DEC-0032` (rejeições de mecanismo de runner de migration, sucessor do §3 do `DEC-0027` histórico) + `DEC-0028-ADDENDUM` (proveniência das duas referências históricas ao DEC-0027 congeladas no corpo do `DEC-0028`) — **somente após** o merge da Cadeia A e o novo baseline.
3. **Higiene PostgreSQL/Supabase** — somente após ambas as cadeias.
