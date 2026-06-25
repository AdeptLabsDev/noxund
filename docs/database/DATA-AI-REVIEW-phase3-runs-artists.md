# DATA-AI-0003 - Data/AI Review - Fase 3 Runs + Artists

- **Revisor:** Data/AI Pipeline Agent
- **Tarefa:** `task_phase3_dataai_review_identity`
- **Action:** `define_entity_resolution`
- **Alvo:** `supabase/migrations/20260620000003_phase3_runs_artists.sql`
- **Handoff:** `docs/database/HANDOFF-phase3-runs-artists.md`
- **Natureza:** ratificacao de identidade/dedupe e placement de rubric; nenhum apply, nenhum Score, nenhum hash concreto e nenhum valor de metrica gerado.

---

## 0. Veredito

**Aprovado por Data/AI para o gate matrix #5. Sem veto metodologico ao DDL da Fase 3.**

O modelo `artists` + `artist_aliases` e coerente com o Entity Resolution do MVP: artistas sao identidades globais, metricas sao por run em `artist_metrics`, e conflitos de nome/alias devem ir para revisao humana em vez de serem resolvidos por inferencia silenciosa.

---

## 1. Regra de identidade e dedupe

**Ratifico `unique lower(canonical_name)` em `artists` e `unique lower(alias)` global em `artist_aliases`.**

Regra canonica Data/AI para Fase 3:

- `artists.canonical_name` representa a identidade canonica global do artista;
- `artist_aliases.alias` e unico globalmente, nao apenas por artista;
- o mesmo alias nunca deve apontar para dois artistas;
- se dois artistas reivindicam o mesmo alias, o pipeline deve marcar conflito e mandar para revisao humana;
- baixa confianca de Entity Resolution continua indo para fila de revisao, nao para merge automatico;
- merge/correcao humana deve ser registrado em `audit_events`.

Isto preserva joins deterministas para `video_artist_mappings`, `artist_metrics` e `report_items`: um alias ambiguo nao pode gerar duas leituras validas do mesmo input.

---

## 2. Mutabilidade deliberada de `artists` e `artist_aliases`

**Ratifico a ausencia deliberada de trigger de imutabilidade em `artists`/`artist_aliases`.**

Estas tabelas sao working set de identidade, nao raw snapshot. O MVP precisa permitir correcao humana de grafia, merge de duplicatas e ajuste de alias sem recoletar raw. Portanto:

- `artist_aliases.artist_id -> artists(id) ON DELETE CASCADE` e aceitavel para manter aliases acoplados ao artista;
- a mutabilidade operacional nao autoriza editar Score nem computed a mao;
- correcoes humanas exigem trilha em `audit_events`;
- `report_runs` permanece a ancora de proveniencia do raw, enquanto a reproducibilidade dos numeros vive em `artist_metrics` por `run_id` + `rubric_hash`.

Sem trigger aqui e uma decisao metodologica correta para permitir saneamento de identidade, desde que o audit trail humano seja aplicado nas fases que criarem `audit_events` e handlers administrativos.

---

## 3. Proveniencia de alias

**Ratifico o enum `artist_alias_source` com `regex`, `llm_assisted` e `human`.**

O enum cobre a proveniencia necessaria do metodo no MVP:

- `regex`: extracao deterministica/heuristica a partir do titulo;
- `llm_assisted`: unico ponto permitido de IA generativa, ainda sujeito a validacao de substring e revisao quando baixa confianca;
- `human`: correcao, merge ou alias criado por revisao humana.

Nenhum destes valores permite IA gerar numero, Score, Velocity, Signals, Competition, ranking ou Example.

---

## 4. Placement de `rubric_version` e `rubric_hash`

**Ratifico `rubric_version`/`rubric_hash` nullable em `report_runs` como ponteiro do publish, sem substituir o rubric por scoring em `artist_metrics`.**

Isto esta alinhado a DATA-AI-0001 / OD-DB-01:

- `report_runs` continua unificado no MVP;
- o raw e fechado por `run_id`;
- re-score do mesmo raw sob novo rubric grava/recompoe `artist_metrics` com chave logica `(run_id, artist_id, rubric_hash)`;
- `report_items.artist_metric_id` deve apontar para a linha exata de `artist_metrics` usada no snapshot publicado;
- `report_runs.rubric_*` pode ficar nullable ate publish e funcionar como ponteiro do rubric publicado/default da run;
- nao congelar `report_runs.rubric_*` nesta fase evita pre-decidir fluxo de re-score/re-publish.

O contrato de reproducibilidade continua sendo: mesmo raw + mesmo `rubric_hash` => computed identico. A auditoria por celula fica em `artist_metrics` e `report_items`, nao em `report_runs` sozinho.

---

## 5. Garantias e limites

- Nenhum numero foi gerado.
- Nenhum Score, hash concreto, ranking, Velocity, Signals, Competition ou Example foi calculado.
- O rubric 40/25/20/15 permanece intocado.
- Nenhuma mudanca de schema foi aplicada.
- A revisao Data/AI nao substitui Security #3 nem o gate humano/required reviewers do apply.
- Qualquer alteracao futura em pesos, componentes, normalizacao, regra publica de Score ou uso de IA fora do Entity Resolution deve escalar ao Product Orchestrator + Data/AI + QA.
