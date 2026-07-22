# DATA-SG8-001 — Contrato de Design do SG-8 (Round 1 / Round 2, P5-REPRO-01)

- **Artefato:** contrato de design **docs-only** do gate SG-8 — o protocolo canônico de duas rodadas (Round 1 compute + Round 2 replay) sobre o dataset congelado, provando `P5-REPRO-01` antes de qualquer publish.
- **Autor (registro):** Product Orchestrator
- **Data:** 2026-07-22
- **Status:** **RATIFICADO — contrato vinculante de design do SG-8 (Product Lead, 2026-07-22).** Quatro revisões obrigatórias concluídas (Data/AI Pipeline · QA · Database · Security); **não implementado; não executado.**
- **Modo:** DOCS-ONLY. Zero código, zero runner, zero workflow, zero banco, zero schema, zero Environment, zero secret, zero GCP, zero dry-run, zero compute, zero SG-8. **Não** altera versões, hashes, rubrics ou regras de negócio — todas são referenciadas como **substrato congelado**.
- **Relaciona:** DEC-0017 (ratificações v1) · DEC-0023 (1º compute real = SG-8 Round 1 + Round 2; D-D/D-E) · DEC-0021 (RO-1) · DEC-0022 (pré-condição fail-closed no Channel Filter) · `DATA-AUDIT-001` (§1 N10/N11, §7) · `DATA-SCORING-001` · `DATA-OPP-001` · `DATA-CHANNEL-001` · `DATA-ENTITY-001`.
- **Substrato de código (congelado; referenciado, não modificado):** `pipeline.canonical_report` / `canonical_json` / `pipeline_digest` (a superfície de comparação do P5-REPRO-01); `entity_resolution.resolve` (`entity-resolver-v1`); `report_runs.status` (enum `created/collecting/processed/published/failed`).

> **Natureza deste documento.** Este é um **contrato**: define invariantes, semântica de identificadores, a superfície comparável, o protocolo de rodadas, as regras de write/atomicidade, os gates humanos e as fronteiras. **Não** projeta nem implementa o *runner* (código), o *workflow*, nem o schema. O runner é unidade **separada e posterior**, sob GO próprio, e deve satisfazer este contrato.

---

## §1. Objetivo, gate e definição de PASS / FAIL

**Objetivo.** O SG-8 é o gate de reprodutibilidade que antecede o primeiro publish. Ele prova, sobre **dado real** (não sintético), que o pipeline determinístico produz saída **byte-idêntica** em duas execuções independentes do mesmo dataset congelado — a instância viva do invariante `P5-REPRO-01` que o `test_repro_harness` já prova sinteticamente sobre o golden snapshot.

**Unidade de prova.** Uma **sessão SG-8** = exatamente **duas rodadas** (Round 1 e Round 2) sobre um único `source_collection_run_id`, produzindo os **dois relatórios fixos** ("Relatório 1 de 2", "Relatório 2 de 2") do MVP.

**PASS (P5-REPRO-01 satisfeito) — todas as condições, conjuntivas:**
1. Round 1 completou o compute real (resolução + Channel Filter + Scoring + Opportunity) sem itens `needs_review` pendentes no momento do downstream (§5).
2. Round 2 completou como replay **zero-LLM** sobre o snapshot de resolução congelado.
3. Para **cada** um dos dois relatórios, o **digest do payload canônico comparável** (§3) de Round 2 é **byte-idêntico** ao de Round 1.
4. As identidades congeladas (`rule_hash`, `rubric_hash`, `opportunity_hash`, `resolver_version`, golden digest do harness) estão **inalteradas** em relação aos valores travados (§2).

**FAIL — qualquer uma:**
- qualquer digest de Round 2 ≠ Round 1 (drift numérico/ordenação/rótulo);
- qualquer chamada à LLM na Round 2 (§5);
- qualquer item `needs_review` alcançando downstream em Round 1;
- qualquer identidade congelada divergente;
- falha parcial não recuperável sob as regras do §6.

**Bloqueio absoluto de publish.** Publish permanece **barrado** até PASS **e** autorização humana explícita subsequente. **Qualquer drift ⇒ FAIL ⇒ publish proibido** — sem exceção, sem "quase idêntico", sem tolerância. Nenhum resultado torna-se elegível a publish por decurso, por retry silencioso, ou por decisão de agente.

---

## §2. Taxonomia de identificadores + entradas congeladas + contrato read-only do raw

### §2.1 Separação inequívoca de identificadores

Cada identificador tem **um** papel; nenhum é sobrecarregado. A regra-mãe: **proveniência de dado** ≠ **identidade de execução** ≠ **ponteiro de artefato operacional**.

| Identificador | Papel | Escopo | Muda entre rodadas? | Entra no payload comparável (§3)? |
|---|---|---|---|:---:|
| `source_collection_run_id` | **Proveniência do dataset** — o raw congelado (500 vídeos + 146 canais), lido por ambas as rodadas. | Dado (imutável) | **NÃO** — é o mesmo `f0485de6-0d34-41cf-ab48-d46e483aa558` nas duas rodadas | **SIM** (deve casar) |
| `sg8_session_id` | Identidade de **uma tentativa SG-8** (o par Round 1 + Round 2). Nova sessão = nova tentativa completa. | Sessão | constante dentro da sessão | **NÃO** (metadado de execução) |
| `round_execution_id` | Identidade de **uma rodada** (um para Round 1, outro para Round 2). É o "identificador de execução distinto" que **não** representa dataset distinto. | Rodada | **SIM** (distinto por rodada) | **NÃO** (metadado de execução) |
| `resolution_snapshot_id` | Ponteiro para o **conjunto congelado de fatos de entity-resolution** (determinísticos + decisões humanas) produzido na Round 1 e **relido** pela Round 2. | Sessão | constante (Round 2 relê o de Round 1) | **NÃO** (ponteiro; seu *efeito* está nas linhas) |
| `report run_id` (×2) | Identidade de cada **relatório-artefato** (Relatório 1/2 e 2/2). É a `run_id` que `build_report`/`canonical_report` já carimbam. | Sessão (congelado) | **NÃO** — **os mesmos dois** `run_id` são reusados por ambas as rodadas | **SIM** (deve casar) |
| adaptador/LLM provenance ids | Provider, modelo, `prompt_version`, params, identidade do adaptador (§5.3). | Rodada 1 | n/a (Round 2 não invoca LLM) | **NÃO** (proveniência auditável, nunca hash de produto) |

**Decisão de contrato D-1 (report run_id congelado na sessão).** Os dois `report run_id` são fixados **uma vez** no nível da `sg8_session` e **reusados** por ambas as rodadas. Assim a superfície `canonical_report` existente permanece **inalterada** (nenhum novo hash, nenhuma mudança de código/regra), e Round 2 é um replay verdadeiro para dentro das mesmas identidades de relatório. O `round_execution_id` — que difere entre rodadas — **nunca** é passado ao pipeline nem entra na saída comparável. *(Alternativa considerada e rejeitada: excluir `run_id` do payload via uma superfície comparável sob medida — rejeitada por criar uma segunda superfície de hash divergente de `pipeline_digest`, violando o non-goal "não alterar hashes".)*

> **Payload compartilhado ≠ armazenamento compartilhado (ver §6.5 / D-10).** O `report run_id` reusado é uma identidade **lógica / de dado** que aparece no payload comparável das **duas** rodadas — é *exatamente* o que precisa casar para provar reprodutibilidade. Ele **não** implica linha ou artefato de armazenamento compartilhado: a materialização física de cada rodada (resultados, digests, atestações) é **particionada por `round_execution_id`**. Round 1 e Round 2 gravam em espaços **separados**; a Round 2 **jamais** atualiza ou sobrescreve qualquer artefato da Round 1.

### §2.2 Entradas congeladas (before == after; verificadas na abertura da sessão)

| Entrada | Valor congelado |
|---|---|
| `source_collection_run_id` | `f0485de6-0d34-41cf-ab48-d46e483aa558` (double-§7-passed: 500 vídeos + 146 canais) |
| `window_end` | o `window_end` congelado do run (referência temporal única; nunca wall clock) |
| `rule_version` / `rule_hash` | `channel-filter-v1` / `7a1e3c76…eaea7` |
| `rubric_version` / `rubric_hash` | `score_rubric_2026_06_v1` / `f0c465fb…3ca54` |
| `opportunity_version` / `opportunity_hash` | `opportunity-rules-2026_06_v1` / `ce7c7c1a…ba52f` |
| `resolver_version` | `entity-resolver-v1` |
| golden digest (harness `P5-REPRO-01`) | `c8e33fe8…74ca8` |

**Confirmação vinculante:** ambas as rodadas consomem **o mesmo** `source_collection_run_id` **`f0485de6-0d34-41cf-ab48-d46e483aa558`**. Um identificador de execução distinto por rodada **não** representa dataset distinto — a proveniência de dado é uma só.

### §2.3 Contrato read-only do raw

O raw (`raw_youtube_videos`, `raw_youtube_channels`, `report_runs` do `source_collection_run_id`) é **imutável** e lido **read-only** por ambas as rodadas. Nenhuma rodada altera, deleta ou re-coleta raw; recoleta seria um **novo** `source_collection_run_id` (fora desta sessão). A leitura é addressada por chave natural, ordenação total (`DATA-AUDIT-001` §2 N11).

---

## §3. Payload canônico comparável

A superfície de comparação do SG-8 é **exatamente** `pipeline.canonical_report` → `canonical_json` → `pipeline_digest` (já congelada; este contrato **não** a altera). Especificação formal:

### §3.1 Campos INCLUÍDOS (por relatório)
- `run_id` (report run_id — congelado na sessão, §2.1 D-1), `window_end` (isoformat), `pipeline_version`, `insufficient_opportunity`;
- bloco `provenance`: `resolver_version`, `rule_version`, `rule_hash`, `rubric_version`, `rubric_hash`, `opportunity_version`, `opportunity_hash`;
- `rows[]` ordenadas, cada linha com: `rank`, `artist_id`, `title`, `tag` (HOT), `score_display`, `score_value`, `signals`, `velocity_display`, `competition_level`, `competition_channel_count`, `example_video_id`, `example_url`, `selection_reason_json`, e as versões/hashes por linha.

### §3.2 Campos EXCLUÍDOS
- `sg8_session_id`, `round_execution_id`, `resolution_snapshot_id` (identidades de execução/ponteiros);
- **timestamps operacionais** (`created_at`, `executed_at`, latência) — **exceto** `window_end`, que é referência temporal **congelada de dado** e permanece incluída;
- **metadados operacionais**: quota consumida, contadores de retry, identidade do adaptador/provider/modelo, `prompt_version`, params da LLM (todos vão para a **proveniência auditável**, §5.3 — nunca para o digest);
- artefatos intermediários pesados (`metrics_detail_json` completo, filas) — reconstruíveis, fora da superfície de comparação por design.

### §3.3 Ordenação determinística
Chave natural estável em toda coleção: `rows` por `rank` (que deriva da chave de ranking total `final_score DESC → norm_velocity DESC → norm_signals DESC → artist_id ASC`, DEC-0017 item 2); vídeos por `video_id`; canais por `channel_id`; componentes na ordem canônica congelada. Nenhuma ordem de iteração de set/dict alcança a saída (`DATA-AUDIT-001` §2 N1/N8).

### §3.4 Serialização e digest
- **Serialização:** JSON canônico — `sort_keys=True`, `separators=(",",":")` (sem espaço), `ensure_ascii=False`; `Decimal` via `str(Decimal)` exato (função determinística do valor).
- **Digest:** `sha256(canonical_json(report))` hexdigest, **por relatório**. A sessão compara os **dois** digests de Round 2 contra os **dois** de Round 1 (emparelhados por `report run_id`).

### §3.5 Tratamento de UUIDs, timestamps e metadados
- **UUID de dado** (`source_collection_run_id`, report `run_id`): **incluído** — deve casar.
- **UUID de execução** (`sg8_session_id`, `round_execution_id`, `resolution_snapshot_id`, ids de adaptador): **excluído**.
- **Timestamp de dado** (`window_end`): **incluído**. **Timestamp operacional**: **excluído**.
- **Metadado operacional** (quota, retry, provider/modelo/prompt/params): **excluído do digest**, **obrigatório na proveniência** (§5.3, §6).

---

## §4. Protocolo de duas rodadas

### §4.1 Round 1 — o primeiro compute real
Sequência determinística, humano no loop nos pontos marcados (§8):
1. **Preflight RO-1** (§7) — ato vivo sobre o banco.
2. **Entity-resolution** (§5.1): resolução **determinística primeiro**; LLM **apenas** para itens não resolvidos; itens `needs_review` **bloqueiam** o downstream até decisão humana; fatos + decisões humanas **persistidos e congelados** ⇒ `resolution_snapshot_id`.
3. **Downstream determinístico**: Channel Filter (`channel-filter-v1`, fail-closed DEC-0022) → Scoring (`score_rubric_2026_06_v1`) → Opportunity (`opportunity-rules-2026_06_v1`), sobre os **dois** report run_id congelados.
4. **Persistência inelegível** (§6): resultados gravados em estado **pré-`published`**; digests canônicos (§3) computados e persistidos como evidência de Round 1.

### §4.2 Round 2 — replay de verificação, zero-LLM
1. **Preflight RO-1** (§7) — ato vivo sobre o banco.
2. **Reuso do snapshot congelado**: `resolution_snapshot_id` de Round 1 é relido **read-only**; `entity_resolution.resolve` atinge o ramo de **replay fact** para todo vídeo ⇒ nenhuma fila humana reaberta, nenhum candidato novo.
3. **Adaptador LLM hard-desabilitado**: Round 2 roda com adaptador que **falha fechado** em qualquer chamada (§5.2). Como todo item é replay, a LLM nunca é alcançada; se for, é **drift ⇒ FAIL**.
4. **Downstream determinístico idêntico** sobre os **mesmos** report run_id; digests canônicos computados **em memória/at-rest** e **comparados** contra os de Round 1 (§3.4).
5. **Veredicto** PASS/FAIL (§1). Round 2 grava **somente** sua própria evidência/atestação de comparação — **nunca** sobrescreve evidência de Round 1 (§6).

### §4.3 Execução ≠ dataset
`round_execution_id(Round 1)` ≠ `round_execution_id(Round 2)` **por construção**; ambos apontam para o **mesmo** `source_collection_run_id`. A distinção é de orquestração/auditoria, **jamais** de proveniência de dado. Esta é a razão exata pela qual identificadores de execução são **excluídos** do payload comparável (§3.2).

---

## §5. Fronteira LLM + proveniência obrigatória

### §5.1 Round 1 — LLM estritamente subordinada
Fiel a `entity_resolution.resolve` (`entity-resolver-v1`, `DATA-AUDIT-001` §2 N10):
- **Determinístico primeiro:** fatos de replay persistidos → fila `pending` → resolução regex/determinística. A LLM **nunca** é chamada antes desse estado ser checado.
- **LLM apenas para não resolvidos:** só itens sem resolução determinística alcançam a LLM.
- **LLM nunca decide aceitação e nunca emite número:** o candidato da LLM passa pelo guard determinístico de span de título (`candidate_is_supported`) e entra como **`PENDING` / `REVIEW_REQUIRED`** — **decisão humana obrigatória**.
- **`needs_review` bloqueia downstream:** nenhum item `needs_review` pode alcançar Channel Filter/Scoring/Opportunity. O downstream só roda quando **todos** os itens estão resolvidos (determinístico + confirmação humana). Fail-closed.
- **Fatos + decisões humanas congelados:** ao final, o conjunto (resoluções determinísticas + aceites/rejeições humanos) é **persistido e imutável** sob `resolution_snapshot_id`.

### §5.2 Round 2 — zero-LLM, falha fechada
- **Reusa** o `resolution_snapshot_id` congelado; **não reabre** a fila humana; **não** enfileira candidatos.
- **Zero chamadas à LLM.** O adaptador da Round 2 é um adaptador **proibido**: qualquer tentativa de chamada **levanta e falha a sessão** (FAIL), em vez de silenciosamente resolver. Defesa em profundidade: mesmo um bug lógico que alcançasse o ramo da LLM falha fechado, nunca produz número.

### §5.3 Proveniência obrigatória da LLM (Round 1)
Para **cada** invocação de LLM em Round 1, persistir com o snapshot (auditável; **excluído** do digest, §3.2):
- **provider** e **modelo** (ex.: família + id exato do modelo);
- **versão / identidade do modelo** (snapshot/version pin);
- **`prompt_version` / hash do prompt** (o `prompt_version` já carregado pelo resolver);
- **parâmetros relevantes** (ex.: temperature, top_p, max_tokens, seed/determinismo se aplicável, stop);
- **identidade do adaptador** (qual adaptador/rota executou a chamada).

Esta proveniência é **pré-condição de PASS**: um snapshot com invocação de LLM sem proveniência completa é inválido.

---

## §6. Contrato de writes e atomicidade

### §6.1 O que cada rodada pode ler e escrever
- **Round 1** — **lê** raw (read-only, §2.3), fatos/fila de resolução; **escreve** (append/estado inelegível): fatos de resolução + decisões humanas (⇒ `resolution_snapshot_id`), resultados de compute e digests canônicos de Round 1, tudo em estado **pré-`published`**.
- **Round 2** — **lê** raw + `resolution_snapshot_id` congelado + evidência de Round 1 (read-only, para comparar); **escreve** **somente** sua própria evidência de comparação/veredicto, num espaço **particionado por seu `round_execution_id`** (distinto do de Round 1). **Não** escreve fatos de resolução, **não** cria relatórios novos, **não** atualiza nem sobrescreve nenhum artefato da Round 1.

### §6.2 Inelegibilidade antes do PASS
Nenhum resultado transita para `published` antes de PASS. Enquanto a sessão não passa, os relatórios permanecem em estado inelegível (pré-`published` no enum `report_runs.status`); publish é um gate **separado e posterior** (§1). "Computado" nunca implica "publicável".

### §6.3 Comportamento em falha parcial
- Falha **antes** de qualquer write (ex.: preflight RO-1 reprova, banco pausado) ⇒ **zero blast radius**: nada gravado, nada elegível; a sessão não avança.
- Falha **durante** Round 1 após writes parciais ⇒ os artefatos parciais ficam **inelegíveis e inertes** (nunca `published`, nunca comparados como se completos); a sessão é marcada não-PASS. Correção segue §6.4.
- Falha em Round 2 (incl. drift) ⇒ **FAIL**; evidência de Round 1 preservada intacta; nada publicado.

### §6.4 Retomada vs nova sessão
- **Retomada** só é admissível para etapas **idempotentes read-mostly** que não comprometeram a imutabilidade do snapshot (ex.: recomputar Round 2 a partir do mesmo `resolution_snapshot_id` congelado).
- Qualquer comprometimento do snapshot de resolução, dos report run_id congelados, ou da integridade dos writes de Round 1 ⇒ **nova `sg8_session_id`** (nova tentativa completa), **jamais** edição in-place da sessão anterior.

### §6.5 Proibição de sobrescrever evidência anterior
Evidências (fatos de resolução, resultados, digests, atestações) são **append-only e imutáveis**. Nenhuma rodada, retomada ou nova sessão **sobrescreve** evidência anterior; uma nova sessão **adiciona**, nunca substitui. Isto preserva a auditabilidade completa da cadeia (paralelo à imutabilidade do raw, `DATA-AUDIT-001`).

**Separação por rodada (imutabilidade entre rodadas).** As evidências de Round 1 e de Round 2 são **armazenadas separadamente, particionadas por `round_execution_id`**. Os **mesmos** dois `report run_id` podem — e devem — aparecer no payload canônico das **duas** rodadas (identidade lógica de dado, §2.1 D-1); isso **nunca** significa artefato de armazenamento compartilhado. A Round 2 **nunca** atualiza nem sobrescreve os artefatos da Round 1 — ela **adiciona** sua própria evidência sob seu `round_execution_id` e apenas **lê** a de Round 1 para comparar. Um write de Round 2 que colidisse com um artefato de Round 1 é violação de contrato ⇒ **FAIL**.

---

## §7. Preflight RO-1 (obrigatório antes de cada ato vivo)

Antes de **cada** ato que toque o banco (abertura de Round 1 **e** abertura de Round 2 — dois preflights por sessão), o ritual de 3 partes do **DEC-0021** é **obrigatório**:
1. **Probe DNS read-only** de `<project>.supabase.co` por agente — sem credencial;
2. **Verificação credenciada do Product Lead** — `select 1` + presença das tabelas de contrato (`report_runs`, `raw_youtube_videos`, `raw_youtube_channels`, tabelas de entity-resolution);
3. **Restore manual via dashboard se pausado** — ato exclusivo do Product Lead (o auto-pause de free tier é risco permanente; a sessão SG-8 pode ocorrer após 2026-07-22).

O preflight é **pré-condição de execução**: reprovar o preflight aborta a rodada **antes** de qualquer write (§6.3). Enquanto toda operação for **assistida** (humano no loop), free tier + liveness bastam; o gatilho de upgrade Pro (DEC-0021 item 3) **não** é disparado por entrar no SG-8.

---

## §8. Cadeia humana e pontos de aprovação

Nenhum ato abaixo é de agente; o Orchestrator é read-only na verificação.

| Ponto | Ato | Autoridade |
|---|---|---|
| **A0** | Ratificação deste contrato | Product Lead (após as 4 revisões) |
| **A1** | GO da sessão SG-8 (após runner implementado + revisado) | Product Lead |
| **A2** | Preflight RO-1 credenciado + restore (Round 1) | Product Lead |
| **A3** | Revisão da fila de entity-resolution — aceite/rejeição dos `needs_review` de Round 1 | Product Lead (decisão humana congelada) |
| **A4** | Preflight RO-1 credenciado + restore (Round 2) | Product Lead |
| **A5** | Leitura do veredicto PASS/FAIL da sessão | Product Lead (agentes entregam relatório read-only) |
| **A6** | Autorização de publish (gate separado, só após PASS) | Product Lead — **fora do escopo do SG-8** |

Revisões de conformância pós-execução: Data/AI (metodologia/determinismo) + QA (sem drift) + Security (postura de banco/secret se tocada) alimentam A5/A6.

---

## §9. Fronteira: design ↔ runner ↔ integração live ↔ execução

Quatro estágios, **sequenciais**, cada um com GO próprio:
1. **Design (este documento)** — docs-only. Define o contrato. **Não** toca código/banco.
2. **Implementação do runner** — código (unidade separada, PR próprio), com testes que provam o contrato **offline/sintético** (ex.: estende o `test_repro_harness` para a forma de duas rodadas + adaptador LLM proibido em Round 2). **Zero** banco, **zero** LLM real, **zero** dado real. Revisão Data/AI + QA (+ Security se tocar postura).
3. **Integração live** — fiação do runner ao banco/entity-resolution reais **desarmada/gated** (preflight RO-1, Environment se aplicável). Nenhuma execução ainda. Revisão Database + Security.
4. **Execução (a sessão SG-8)** — Round 1 + Round 2 vivos, humano no loop (§8), sob RO-1. Só aqui há compute real.

Cada fronteira é **inequívoca**: nada de estágio N+1 acontece sob o GO do estágio N. Este contrato autoriza **apenas** o estágio 1 (e sequer isso executa nada).

---

## §D. Decisões explícitas do contrato

| # | Decisão |
|---|---|
| **D-1** | `report run_id` (×2) congelados na `sg8_session` e reusados por ambas as rodadas; `round_execution_id` nunca entra na saída comparável (§2.1). Preserva `canonical_report`/`pipeline_digest` sem alteração. |
| **D-2** | Superfície comparável = `pipeline.canonical_report` **existente**, inalterada; digest por relatório = `sha256(canonical_json)` (§3). |
| **D-3** | `window_end` e `source_collection_run_id` são **dado congelado** (incluídos no digest); todos os demais timestamps/UUIDs de execução e metadados operacionais são **excluídos** (§3.2/§3.5). |
| **D-4** | Round 2 roda com **adaptador LLM proibido** (falha fechada em qualquer chamada), não só "sem chamar" (§5.2). |
| **D-5** | `needs_review` **bloqueia** downstream em Round 1; decisões humanas são congeladas no `resolution_snapshot_id` antes de qualquer compute downstream (§5.1). |
| **D-6** | Evidência é **append-only e imutável**; nova tentativa = **nova `sg8_session_id`**, nunca edição in-place (§6.4/§6.5). |
| **D-7** | Qualquer drift ⇒ **FAIL** ⇒ publish **absolutamente barrado**; sem tolerância (§1). |
| **D-8** | Proveniência de LLM (provider/modelo/versão/prompt-hash/params/adaptador) é **obrigatória** em Round 1 e **pré-condição de PASS**, mas **excluída** do digest (§5.3). |
| **D-9** | Dois preflights RO-1 por sessão (um por rodada), obrigatórios antes de cada ato vivo (§7). |
| **D-10** | **Imutabilidade entre rodadas.** Os mesmos dois `report run_id` aparecem no payload canônico das duas rodadas (identidade lógica, D-1), mas as evidências de Round 1 e Round 2 são **armazenadas separadamente, particionadas por `round_execution_id`**; Round 2 **nunca** atualiza/sobrescreve artefatos de Round 1 — só os lê para comparar (§2.1 / §6.1 / §6.5). |

## §Q. Questões abertas (para revisores / Product Lead)

> **Todas RESOLVIDAS em 2026-07-22 por decisão do Product Lead — ver §R.** O texto original de cada questão é preservado abaixo (marcação de resolução, sem reescrita).

- **Q-1 — Persistência do snapshot de resolução.** *(RESOLVIDO 2026-07-22 — ver §R.)* O `resolution_snapshot_id` exige tabela/coluna nova ou é expressável sobre o modelo de entity-resolution já landado (fatos de replay + fila)? Se exigir schema, isso é trabalho **Database** no estágio 3 (fora deste contrato) e deve nascer de decisão registrada. *(Owner: Database.)*
- **Q-2 — Estado inelegível exato.** *(RESOLVIDO 2026-07-22 — ver §R.)* Qual valor do enum `report_runs.status` representa "computado mas inelegível a publish" para a sessão SG-8 (`processed`?), e como distinguir Round 1 vs Round 2 sem poluir a superfície comparável? *(Owner: Database + Data/AI.)*
- **Q-3 — Determinismo do provider de LLM.** *(RESOLVIDO 2026-07-22 — ver §R.)* A proveniência (§5.3) é suficiente para auditoria, mas o provider é não-determinístico por natureza; o contrato já isola isso (LLM só gera candidato `PENDING`, humano decide, Round 2 é replay). Confirmar que nenhuma configuração de provider pode vazar para um número. *(Owner: Data/AI + Security.)*
- **Q-4 — Reexecução de Round 2.** *(RESOLVIDO 2026-07-22 — ver §R.)* Recomputar Round 2 a partir do mesmo snapshot é retomada idempotente (§6.4) — confirmar que nenhuma condição de corrida com o estado inelegível de Round 1 exige nova sessão. *(Owner: QA + Database.)*
- **Q-5 — Credencial da LLM (independente da YouTube API key).** *(RESOLVIDO 2026-07-22 — ver §R.)* A credencial da LLM (Round 1) e a **YouTube API key são independentes**: chaves distintas, escopos distintos, **ciclos de rotação distintos**. O deadline ≈ **2026-10-13 pertence exclusivamente à YouTube key** (rotação A7, SEC-0026) e **não** define nem governa a rotação da futura credencial da LLM, que terá política própria a definir. A credencial da LLM e sua postura de secret entram no estágio 3 (integração live); confirmar que **nenhuma** das duas rotações, independentes entre si, interfere na janela SG-8. *(Owner: Security.)*

---

## §R. Reconciliação Q-1…Q-5 + definições derivadas (Product Lead, 2026-07-22)

As cinco questões de §Q estão **RESOLVIDAS** por decisão do Product Lead (2026-07-22). O texto original de §Q permanece **intacto acima** (marcado como resolvido, sem reescrita). Esta seção registra as decisões e as definições derivadas; ela **estende** as decisões §D (D-1…D-10) — **nenhuma** é revertida.

### §R.1 Decisões Q-1…Q-5

| Q | Decisão (Product Lead, 2026-07-22) |
|---|---|
| **Q-1** | **Registro leve e dedicado** de `resolution_snapshot`, **sem duplicar** os fatos de entity-resolution já existentes. O snapshot é **imutável** e identificado por `resolution_snapshot_id`, carregando: `sg8_session_id`, `source_collection_run_id`, identidade do resolver (`resolver_version`), `fact_count`, `content_hash` **canônico** e `frozen_at`. |
| **Q-2** | **NÃO** usar `report_runs.status` para representar elegibilidade SG-8. Estado e elegibilidade pertencem à **`sg8_session`**; publish só é permitido com a sessão em **`PASSED`**. **NÃO** adicionar `computed_pending_repro` a `report_runs`. |
| **Q-3** | A garantia é **determinismo condicionado ao `resolution_snapshot` congelado**, **NÃO** independência absoluta do provider. **Toda** saída da LLM exige **decisão humana**. Persistir: **provider**, **modelo exato**, **prompt hash**, **parâmetros** e **adapter version**. `temperature=0` **não** é tratado como prova de determinismo. |
| **Q-4** | **Uma única** Round 2 persistida por `sg8_session_id`. **PASS ou FAIL tornam a sessão terminal**; nova tentativa canônica exige **nova sessão**. Retry **técnico** só pode ocorrer **antes do commit** e **sem** evidência persistida. |
| **Q-5** | **Secret e Environment dedicados ao SG-8**, separados de `youtube-collection`, com **required reviewer**, **credenciais mínimas**, **rotação própria** e **modelo pinado por identificador exato** — **nunca** por alias "latest". |

### §R.2 Definições derivadas (normativas)

- **DD-1 — Elegibilidade de publish.** Deriva **exclusivamente** de `sg8_session.status = PASSED`. Nenhuma outra tabela, status ou decurso confere elegibilidade. Isto **reconcilia §6.2**: `report_runs.status` pode acompanhar o ciclo de vida do relatório, mas a elegibilidade de publish do SG-8 vem **apenas** de `sg8_session.status = PASSED` — nunca de `report_runs.status`.
- **DD-2 — Estado SG-8 fora do payload.** O estado da `sg8_session` e todos os metadados operacionais (`sg8_session_id`, `round_execution_id`, `resolution_snapshot_id`, proveniência de LLM, timestamps operacionais) permanecem **fora** do payload canônico comparável (reafirma §3.2/§3.5 · D-3).
- **DD-3 — Terminalidade.** Nenhuma sessão terminal (`PASSED`/`FAILED`) pode ser **reaberta** (reafirma §6.4 · D-6 · Q-4).
- **DD-4 — Append-only.** `fatos`, `resolution_snapshot`s, `rodadas` e `evidências` são **append-only e imutáveis**; nenhum é atualizado in-place (reafirma §6.5 · D-6 · D-10).
- **DD-5 — Unidade de schema futura.** A futura unidade de schema (estágio 3) **deverá** possuir **migração, verify e rollback próprios** (paralelo ao padrão do repositório), sob revisão **Database + Data Integrity**, nascendo de decisão registrada. Este contrato **não** cria schema.

### §R.3 Revisões obrigatórias desta reconciliação

Reconciliação docs-only (o Product Lead já decidiu Q-1…Q-5); revisão de conformância:

- [ ] **Database** (registro `resolution_snapshot` Q-1 · `sg8_session` elegibilidade Q-2 · append-only DD-4 · schema-unit DD-5)
- [ ] **Data/AI Pipeline** (determinismo condicionado Q-3 · estado fora do payload DD-2)
- [ ] **QA** (terminalidade/retry Q-4/DD-3 · elegibilidade DD-1)
- [ ] **Security** (secret/Environment dedicados + rotação própria + modelo pinado Q-5)

---

## Revisões obrigatórias

Quatro revisões obrigatórias — **todas concluídas** — + ratificação humana (A0), 2026-07-22:

- [x] **Data/AI Pipeline** (obrigatória — metodologia, determinismo, fronteira LLM, superfície comparável) — **APPROVE WITH NOTES**
- [x] **QA** (obrigatória — PASS/FAIL sem drift, falha parcial, retomada, cobertura offline do runner) — **APPROVE WITH NOTES**
- [x] **Database** (obrigatória — writes/atomicidade, inelegibilidade, snapshot, imutabilidade) — **APPROVE PENDING** (Q-1/Q-2 = pré-condições obrigatórias do estágio 3)
- [x] **Security** (obrigatória — postura de banco/secret/LLM, RO-1, proveniência, acesso fechado) — **APPROVE WITH NOTES**
- [x] **Product Lead** — **RATIFICA (A0)** — ratificado 2026-07-22

## Non-goals (explícitos)

- **Não** implementa o runner (código) — estágio 2, separado.
- **Não** cria workflow.
- **Não** toca banco, schema, Environment, secrets ou GCP.
- **Não** executa dry-run, compute-live ou SG-8.
- **Não** altera versões, hashes, rubrics ou regras de negócio (todas referenciadas como substrato congelado).
- `0007`/`producer_events` permanece **PARKED**; Fase 9/RLS **VETOED**; publish barrado até PASS (§1).
