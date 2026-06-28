# DATA-AI-0005 - Data/AI Review - Fase 5 Computed Metrics + Relatorios

- **Revisor:** Data/AI Pipeline Agent (poder de veto metodologico; matrix #4/#5)
- **Tarefa:** `task_phase5_validate_reproducibility`
- **Action:** `validate_reproducibility`
- **Data:** 2026-06-27
- **Alvos:**
  - `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql`
  - `supabase/tests/phase5_post_apply_verify.sql`
  - `supabase/rollback/20260620000005_phase5_computed_metrics_reports.rollback.sql`
  - `docs/database/HANDOFF-phase5-design.md`
- **Natureza:** review de design pre-apply. Nenhum DDL foi autorado ou aplicado; nenhum Score,
  hash, ranking ou valor de metrica foi gerado.

---

## 0. Veredito

**VETO Data/AI pre-apply (`needs_review`). O gate matrix #4/#5 nao esta baixado.**

O desenho acerta a base de storage-only, a chave logica de `artist_metrics`, a FK composta
para `rubric_versions` e a separacao declarada COMPUTED/SNAPSHOT. Porem, as constraints
executaveis ainda nao sustentam quatro afirmacoes centrais do handoff:

1. `report_items` pode receber linha nova depois do publish;
2. um item pode apontar para metrica de outro run, outro artista ou outro rubric;
3. a metrica apontada por um item publicado pode ser alterada in-place;
4. `computed_from_video_ids` e somente uma referencia logica, sem FK/validacao ate o raw, e
   `metrics_detail_json` pode ser `NULL`.

Logo, hoje nao e verdade que `artist_metric_id` aponta necessariamente para a metrica exata e
congelada do snapshot, nem que toda celula publicada possui rastro garantido ate
`raw_youtube_videos`. Aplicar neste estado criaria divida de integridade que exigiria hotfix,
contrariando a licao de DEC-0009.

**OPEN DECISION metodologica:** escolher a representacao de integridade que congele somente a
linhagem ja publicada, sem transformar todas as tabelas COMPUTED em append-only. A recomendacao
Data/AI e um guard condicional para metricas referenciadas por report publicado/archived, ou um
snapshot completo e imutavel da linhagem no proprio item. FK `ON DELETE RESTRICT` isolada nao
protege contra `UPDATE`.

---

## 1. Resultado por requisito delegado

| Requisito | Resultado | Evidencia |
|---|---|---|
| COMPUTED sem freeze global | **Aprovado parcialmente** | Os quatro triggers criados atingem somente `reports`/`report_items`; mappings, eligibility e metrics nao recebem trigger de imutabilidade global. |
| Proveniencia COMPUTED por FK RESTRICT | **Veto parcial** | Mappings e eligibility possuem FK composta ate raw; metrics possui FK para run/artist/rubric, mas `computed_from_video_ids text[]` nao tem FK nem validacao de pertencimento ao mesmo run. |
| `unique(run_id, artist_id, rubric_hash)` | **Aprovado** | `artist_metrics_run_artist_rubric_uidx` existe e o verify cobre duplicidade. |
| Mesmo snapshot + mesmo rubric => mesmo relatorio | **Veto** | Um report nao congela seu par de rubric e seus items podem misturar metrics de run/artista/rubric diferentes. O verify nao testa rebuild/canonical projection. |
| OD-DB-07 `metrics_detail_json` | **Veto** | A coluna existe, mas e nullable; os probes inserem metrics sem detalhe e passam. Nao ha contrato verificavel de auditoria por scoring. |
| OD-DB-06 `artist_metric_id` | **Veto** | A FK por `id` preserva a existencia contra DELETE, mas nao coerencia run/artista/rubric nem o conteudo da metric contra UPDATE. |
| FK `(rubric_version, rubric_hash)` | **Aprovado** | `artist_metrics_rubric_fk` aponta para `rubric_versions(version, hash) ON DELETE RESTRICT`. |
| Storage-only / IA nao gera numero | **Aprovado** | Nao ha formula, generated column, trigger de calculo ou CHECK de faixa de Score/Velocity/Signals/Competition. O unico CHECK e de estado/published_at. `llm_assisted` aparece somente em Entity Resolution. |
| Snapshot freeze | **Veto** | UPDATE/DELETE/TRUNCATE sao cobertos parcialmente; INSERT pos-publish e movimento draft -> published nao sao bloqueados. |
| Rollback | **Sem veto Data/AI proprio** | Ordem filhos -> pais preserva dependencias; continua sujeito ao gate destrutivo e a runs descartaveis, como o arquivo declara. |

---

## 2. Achados bloqueantes e correcoes exigidas

### DATA-F5-01 - Snapshot aceita `INSERT` depois do publish (critico)

O trigger `report_items_snapshot_guard` e declarado apenas `BEFORE UPDATE OR DELETE`. Assim, um
caller com privilegio de escrita pode inserir novo `report_item` em report `published` ou
`archived`. Em UPDATE, o lookup usa `coalesce(old.report_id, new.report_id)`; como `OLD` existe,
um item de report draft tambem pode ser movido para um report publicado sem que o destino seja
checado.

**Correcao obrigatoria:** o guard deve cobrir INSERT/UPDATE/DELETE e validar explicitamente o pai
de `NEW` e, quando aplicavel, o pai de `OLD`. O verify precisa provar, como grant-holder e no
caminho service-role, que:

- INSERT em report published/archived falha;
- mover item de draft para published/archived falha;
- INSERT e UPDATE em report draft continuam validos.

### DATA-F5-02 - OD-DB-06 nao garante coerencia report -> metric (critico)

`report_items.report_id`, `artist_id` e `artist_metric_id` sao FKs independentes. O schema aceita:

- report do run A apontando metric do run B;
- item do artista A apontando metric do artista B;
- items do mesmo report apontando rubrics diferentes.

Isto quebra a chave de reproducibilidade e torna `artist_metric_id` apenas um ponteiro para
"alguma metric", nao para a metric exata usada naquele report.

**Correcao obrigatoria:** congelar o par `(rubric_version, rubric_hash)` no snapshot do report e
enforcar, por constraints compostas ou guard de integridade equivalente, que cada item use metric
com o mesmo `run_id`, `artist_id`, `rubric_version` e `rubric_hash` do report/item. O verify deve
rejeitar separadamente cada mismatch e aceitar o caso coerente.

### DATA-F5-03 - A metrica publicada continua mutavel (critico)

A FK `report_items.artist_metric_id -> artist_metrics.id ON DELETE RESTRICT` impede apagar a linha,
mas nao impede alterar `final_score`, componentes, `rubric_*`, `computed_from_video_ids` ou
`metrics_detail_json`. Portanto, apos publish, a mesma PK pode passar a descrever outro calculo e
o rastro historico deixa de representar os valores congelados em `report_items`.

**Correcao obrigatoria:** preservar o conteudo exato da linhagem publicada. A solucao preferida e
impedir UPDATE/DELETE somente de `artist_metrics` referenciada por item de report
published/archived, mantendo metrics nao publicadas livres para recompute. Alternativamente, o
snapshot deve copiar toda a identidade e evidencia necessarias para nao depender de uma metric
mutavel. O verify precisa provar tamper bloqueado na metric publicada e recompute permitido na
metric nao publicada.

Este guard condicional nao deve virar freeze global de COMPUTED: mappings, eligibility e metrics
continuam reconstruiveis; somente a evidencia ja publicada se torna inviolavel.

### DATA-F5-04 - Rastro de metrics/Example ate raw e apenas logico (alto)

As FKs compostas de `video_artist_mappings` e `channel_eligibility` ate o raw estao corretas.
Entretanto, `artist_metrics.computed_from_video_ids text[]` aceita IDs inexistentes ou de outro
run, e `report_items.example_video_id` tambem nao possui FK/validacao. A cadeia declarada nos
comments e no handoff nao e garantida pelo banco.

**Correcao obrigatoria:** representar os inputs de metric de forma referencial (por exemplo,
relacao normalizada) ou validar deterministicamente que cada video pertence a
`raw_youtube_videos(run_id, video_id)`. Aplicar a mesma garantia ao Example do snapshot. Todas as
FKs de proveniencia devem usar `ON DELETE RESTRICT`. O verify deve rejeitar video inexistente e
video de outro run tanto para metric quanto para Example.

### DATA-F5-05 - OD-DB-07 permite metric sem auditoria (alto)

`metrics_detail_json` e `computed_from_video_ids` sao nullable. O verify confere apenas a
existencia da coluna e cria varias linhas de `artist_metrics` sem nenhum dos dois campos. Assim,
uma linha pode carregar Score e ser publicada sem os dados necessarios para reconstruir Score,
Velocity, Signals, Competition e Example.

**Correcao obrigatoria:** tornar obrigatoria a evidencia de auditoria para metric publicavel. O
contrato Data/AI minimo deve cobrir:

- componentes, pesos, normalizacao, run e rubric;
- videos aceitos/rejeitados e motivos;
- inputs de velocity e mediana;
- channel IDs elegiveis e contagem de Competition;
- candidatos/top-3/desempate/selecionado do Example.

O DDL pode permanecer storage-only: nao deve recalcular nem validar thresholds. A forma minima e
`NOT NULL` + validacao estrutural no data-engine/publish; o verify deve rejeitar evidencia ausente
e aceitar um fixture completo. `selection_reason_json` do item publicado tambem nao pode ser
opcional quando ele e a prova deterministica da selecao.

### DATA-F5-06 - Versoes de inputs anteriores ao scoring nao fecham o rebuild (alto)

`channel_eligibility.rule_version` e nullable e `video_artist_mappings` nao registra versao da
regra/resolver. Alem disso, `human_override`/`reviewed_by_human` nao sao derivaveis somente do raw.
Sob uma versao nova do filtro/resolver, o mesmo raw + mesmo rubric pode produzir inputs diferentes
antes do scoring.

**Correcao obrigatoria:** definir a entrada completa do rebuild como raw imutavel + rubric +
versoes deterministicas de resolucao/filtro + decisoes humanas replayable em `audit_events`.
`rule_version` deve ser obrigatoria quando a eligibility participa de metric publicada, e as
versoes/overrides efetivos devem chegar a `metrics_detail_json`. Se o produto quiser manter a frase
curta "mesmo raw + mesmo rubric", essas versoes precisam fazer parte do config/hash canonico do
pipeline; caso contrario, a chave de reproducibilidade deve nomea-las explicitamente.

### DATA-F5-07 - Verify procura uma FK que a migration nao nomeia (alto)

O verify exige uma constraint chamada `report_items_artist_metric_fk`, mas a migration declara a
FK inline, sem esse nome; o nome automatico esperado pelo Postgres e outro. O verify pos-apply
falharia mesmo sem regressao funcional.

**Correcao obrigatoria:** alinhar o nome explicito no DDL ou fazer o verify identificar a FK pelas
colunas/tabela-alvo/acao `RESTRICT`. Adicionar ainda os probes negativos dos achados 01-05 e uma
assertion estrutural de ausencia de freeze global nas tabelas COMPUTED.

---

## 3. Pontos aprovados e que devem ser preservados

- A migration e atomica (`begin`/`commit`) e o rollback respeita a ordem de dependencia.
- `artist_metrics_run_artist_rubric_uidx` implementa a chave logica aprovada em DATA-AI-0001.
- `artist_metrics_rubric_fk` exige um par versionado real em `rubric_versions` e usa RESTRICT.
- Mappings e eligibility ligam `(run_id, source_id)` ao raw por FK composta RESTRICT.
- Nao existe trigger de imutabilidade global nas tres tabelas COMPUTED.
- Nao ha calculo numerico no banco. O enum de Competition apenas armazena vocabulario; nao
  escolhe nivel, threshold ou contagem.
- IA aparece somente no metodo de Entity Resolution; nenhum numero e produzido por LLM.
- RLS/policies/SECURITY DEFINER permanecem fora do merito deste veredito e seguem para Security #3.
- A Fase 9 continua fechada: zero `CREATE POLICY` executavel neste DDL.

---

## 4. Prova de reproducibilidade exigida no re-review

O DDL pode sustentar a reproducibilidade, mas nao prova sozinho que o data-engine gera conteudo
identico. Antes de baixar matrix #4/#5, o conjunto migration + verify deve demonstrar as
invariantes estruturais acima. Depois, o teste do pipeline deve executar duas vezes sobre a mesma
entrada completa e comparar uma projecao canonica, ordenada por report/rank/artista, contendo os
campos de negocio e evidencias. UUIDs e timestamps operacionais (`id`, `created_at`,
`published_at`) ficam fora da comparacao; divergencia em qualquer valor/evidencia e bug
metodologico bloqueante.

---

## 5. Handoff e sequencia de gates

- **Gate Data/AI #4/#5:** bloqueado por DATA-F5-01..07.
- **Apply/run_migration:** permanece proibido e gated.
- **Proximo owner:** `database_agent:design_schema`, para corrigir migration, verify e handoff
  antes de novo review Data/AI.
- **Depois da correcao:** Data/AI reexecuta `validate_reproducibility`; se aprovado, encadear
  `security_agent:review_rls` (matrix #3); depois Backend valida consumo de `artist_metric_id`;
  `run_migration` continua sendo a ultima tarefa, separada e com aprovacao humana.
- **Fase 9:** continua vetada; este review nao autoriza policies nem VIEW publica.

Nenhum dos quatro artefatos revisados foi modificado por Data/AI. Este arquivo e o unico artefato
criado nesta tarefa.
