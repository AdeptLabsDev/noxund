# DATA-AUDIT-001 — Closeout U2 (P2-01 · P2-02 · P2-04)

- **Unidade:** U2 — hardening hash-neutro que fecha os três P2 não-bloqueantes de `DATA-AUDIT-001` antes do primeiro compute real (DEC-0023 D-D/D-E).
- **Registrado por:** Product Orchestrator
- **Data:** 2026-07-21
- **Modo:** DOCS-ONLY. Zero código, zero banco, zero workflow, zero Environment, zero secret, zero schema, zero GCP, zero compute, zero merge. Este documento apenas **registra** o fechamento de findings já landados em `main`.
- **Fecha:** `DATA-AUDIT-001` findings **P2-01**, **P2-02**, **P2-04**.
- **Fechados por:** **PR #51** — merge `0cced4f`, commit de implementação `c40b96d` (`feat(data-engine): U2 — close DATA-AUDIT-001 P2-01/P2-02/P2-04 (hash-neutral hardening)`).
- **Fonte de verdade:** `docs/data/DATA-AUDIT-001-determinism-conformance.md` (§2 N6/N7, §3, §4 P2-01/02/04) · DEC-0017 (ratificações v1) · DEC-0023 (D-D não-bloqueantes / D-E sequenciamento / restrição SG-8-first).
- **Não introduz decisão nova.** Nenhuma constante de rule/rubric/opportunity mudou; nenhuma versão, nenhum hash e o golden digest permanecem byte-idênticos.

---

## 0. Sumário

O U2 fechou os três P2 que `DATA-AUDIT-001` classificou como hygiene/hardening não-bloqueante para o dataset corrente `f0485de6` (DEC-0023 D-D):

- **P2-02 (código):** `scoring.age_days` passa a levantar `ContractViolation` quando `published_at` é **estritamente posterior** a `window_end` — um vídeo "do futuro" é violação de contrato de coleta, não um vídeo fresco. `published_at == window_end` (idade 0) permanece válido; o floor de `effective_age_days` protege idades near-zero, nunca idades negativas.
- **P2-01 (teste):** `score_run(artists=())` é registrado como contrato legítimo — retorna resultado vazio **sem exceção** e ainda carimba `rubric_version`/`rubric_hash`. Fronteira congelada por teste.
- **P2-04 (teste):** o override de growth é `>` estrito — exatamente **+50%** (recent 3 vs prior 2) **não** eleva Competition a High; logo acima (+100%) eleva. Fronteira congelada por teste.

Por construção **hash-neutro**: P2-02 é uma pré-condição de contrato de input (como DEC-0022), **não** uma constante de rubric → sem bump de `rubric_version`; P2-01/P2-04 são cobertura de teste. Nenhum run bem-formado muda de output (§4).

---

## 1. Evidência (colhida em `main @ 0cced4f`)

| Item | Veredicto | Evidência |
|---|:---:|---|
| P2-01/02/04 vivos em `main` | ✅ | `c40b96d` ⊂ merge `0cced4f` (PR #51); `HEAD == origin/main == 0cced4f` |
| `published_at > window_end` → `ContractViolation` | ✅ | `ContractViolation: published_at must not be after window_end` (`scoring.py`, `age_days`) |
| `published_at == window_end` permanece válido | ✅ | `age_days = 0`; `effective_age_days = 1` (floor aplicado, sem raise) |
| growth exatamente +50% não aciona gatilho estrito | ✅ | `growth_trigger(recent=3, prior=2) → (False, 0.5)`; `growth_trigger(recent=4, prior=2) → (True, 1)` |
| input vazio do scoring → vazio sem exceção | ✅ | `score_run(artists=()) → scores=()`, `rubric_version=score_rubric_2026_06_v1` carimbado |
| suíte completa **175/175 GREEN ×2** | ✅ | `Ran 175 tests ... OK` em duas execuções independentes |
| repro harness **21/21 ×2** | ✅ | `Ran 21 tests ... OK` em duas execuções independentes |
| count guard atualizado e consistente | ✅ | `172 → 175`; breakdown `18+19+28+37+13+39+21 = 175` == contagens live por módulo (entity-res 18 · channel-filter 19 · scoring 28 · opportunity 37 · channel-collection 13 · video-collection 39 · repro-harness 21) |

### Identidades — inalteradas (before == after)

| Identidade | Valor (inalterado) |
|---|---|
| `rule_version` | `channel-filter-v1` |
| `rubric_version` | `score_rubric_2026_06_v1` |
| `opportunity_version` | `opportunity-rules-2026_06_v1` |
| `rule_hash` | `7a1e3c76c4bd6b666939f0b1c84e257ea77e9d05c26dcfd2164e2f74cedeaea7` |
| `rubric_hash` | `f0c465fbf790d1ca445e62ca13b58312bdb31c1b99a3caaf7b0be3eef083ca54` |
| `opportunity_hash` | `ce7c7c1ad5d400ff6dcf9822e436db0def9cde75ffa555568acc0219b1fba52f` |
| golden digest (`P5-REPRO-01`) | `c8e33fe85034e2c406bb189249ff829d8928a5b085d192c73220afcb89674ca8` |

O golden digest foi recomputado sobre o golden snapshot: **byte-idêntico em duas execuções** e **igual ao `GOLDEN_DIGEST`** travado.

---

## 2. P2-02 — fail-closed para `published_at > window_end`

- **Antes (finding):** idade bruta negativa era silenciosamente floorada a 1 dia e pontuada como vídeo fresco — violação de contrato de coleta mascarada (`DATA-AUDIT-001` §2 N6, §4 P2-02).
- **Depois (U2):** `age_days` calcula a idade a partir de um `timedelta` inteiro (sem float) e levanta `ContractViolation("published_at must not be after window_end")` quando a idade bruta é `< 0`. `effective_age_days` propaga o raise (chama `age_days` antes do floor).
- **Fronteira preservada:** `published_at == window_end` → idade 0 → **válido**, floorado a `AGE_FLOOR_DAYS = 1` pelo caminho normal. Idades near-zero válidas (horas antes de `window_end`) continuam floorando a 1, não levantam.
- **Natureza:** pré-condição de contrato de input (paralela a DEC-0022 no Channel Filter), **não** uma constante de rubric → **sem** `rubric_version` bump; `rubric_hash` e golden digest inalterados.

---

## 3. P2-01 e P2-04 — fronteiras congeladas por teste

- **P2-01** — `test_empty_run_scores_empty_without_raising`: `score_run(run_id, artists=(), window_end)` retorna `scores == ()` **sem** levantar e ainda estampa `rubric_version` e `rubric_hash` (run vazio honesto, pinado). Fecha a assimetria observada em `DATA-AUDIT-001` §2 N7 / §3 (scoring silencioso vs. Opportunity fail-closed), registrando o resultado vazio como **contrato legítimo** e travando-o com teste.
- **P2-04** — `test_growth_trigger_exactly_50pct_does_not_fire`: `growth_trigger(recent_7d=3, prior_7d=2)` → `(False, Decimal("0.5"))`; `growth_trigger(recent_7d=4, prior_7d=2)` → `(True, Decimal("1"))`. Trava o `>` estrito na fronteira exata de +50% que `DATA-AUDIT-001` §3 marcou como não exercitada.

Ambos são **cobertura de teste** — nenhuma mudança de comportamento de produção, nenhum output de run bem-formado alterado.

---

## 4. Zero alteração de outputs para dados bem-formados

- **P2-02** só dispara em um input que já é violação de contrato de coleta (`published_at > window_end`). No dataset `f0485de6`, coletado em janela de 30 dias, **nenhum vídeo** satisfaz essa condição — logo, nenhum run bem-formado tem seu output alterado; o efeito é converter um caso antes mascarado em falha explícita.
- **P2-01** e **P2-04** são exclusivamente testes.
- Consequência direta: `rule_version`/`rubric_version`/`opportunity_version`, `rule_hash`/`rubric_hash`/`opportunity_hash` e o golden digest permanecem **byte-idênticos** (§1). O U2 é hash-neutro e digest-neutro **por construção**, exatamente como DEC-0023 D-D previu.

---

## 5. Correção de atribuição — P1-02 vs DEC-0021

Para evitar drift de registro: **DEC-0021 pertence exclusivamente ao RO-1** (mitigação do auto-pause do Supabase — liveness + restore manual obrigatórios antes de toda execução que toque o banco; keep-alive automatizado rejeitado; gatilho vinculante do upgrade Pro). **DEC-0021 não fecha `self_channel` (P1-02).**

O fechamento de **P1-02** (`self_channel` landado como gate ativo, antes formalmente não ratificado) está registrado em `DATA-AUDIT-001` **§6 (Adendo 2026-07-16)** e se apoia em:

1. a **emenda da DEC-0017** de 2026-07-01 (commit `4be9519`, via PR #12) — `self_channel = MANTER` (Product Lead);
2. a **DEC-0019 §1** (2026-07-02) — `self_channel` ratificado como parte de `channel-filter-v1`, sem mudança de código nem de `rule_hash`;
3. a **reconfirmação do Product Lead** em 2026-07-16.

DEC-0021 e a reconciliação de P1-02 tramitaram na **mesma unidade documental** (PR #48), mas são registros distintos — a coincidência de PR não os funde. Este closeout apenas fixa a atribuição correta; **não** altera o texto de `DATA-AUDIT-001` §6.

---

## 6. Restrições pré-SG-8 (registradas)

Vinculantes para a primeira Round canônica do SG-8 / P5-REPRO-01 (DEC-0023: 1º compute real = SG-8 Round 1 + Round 2 replay). Registradas aqui, **não** executadas:

1. **Mesmo dataset nas duas rodadas.** Round 1 e Round 2 usam o **mesmo** `source_collection_run_id` **`f0485de6-0d34-41cf-ab48-d46e483aa558`** (dataset double-§7-passed: 500 vídeos + 146 canais).
2. **Identificador de execução ≠ dataset.** Os identificadores de execução das rodadas **podem ser distintos**, mas **não representam datasets distintos** — ambas as rodadas leem o mesmo raw congelado; a distinção de identificador de execução é de orquestração, nunca de proveniência de dados.
3. **LLM na Round 1 — escopo estrito.** A Round 1 permite LLM **exclusivamente** na entity-resolution de itens **não resolvidos deterministicamente** (fatos persistidos + fila pendente checados primeiro; o LLM nunca decide aceitação nem emite número — candidatos entram como `REVIEW_REQUIRED`, sob guard determinístico de span de título). Nenhuma outra zona invoca LLM.
4. **Round 2 — zero-LLM integral.** A Round 2 é **integralmente zero-LLM**: replay determinístico sobre os fatos de resolução congelados, provando reprodutibilidade byte-idêntica sobre dado real.

---

## 7. Fora de escopo deste closeout / não autorizado

- **NÃO** projeta nem implementa o **runner do SG-8** (a orquestração "2 reports canônicas = 2 execuções sobre o mesmo dataset"). Permanece `not landed` — unidade própria, sob GO próprio.
- **NÃO** toca banco, workflow, Environment, secrets, schema ou GCP.
- **NÃO** autoriza merge deste PR nem qualquer execução do SG-8.
- `0007`/`producer_events` permanece **PARKED**; Fase 9/RLS **VETOED**; publish barrado até SG-8/P5-REPRO-01.
