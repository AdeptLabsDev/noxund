# DATA-ENTITY-001 — Entity Resolution (regex-first + LLM assistida)

- **Tarefa:** `task_dataengine_define_entity_resolution`
- **Revisão pre-apply:** `task_entity_candidates_review_dataai_queue`
- **Re-review F01:** `task_entity_candidates_rereview_dataai_f01`
- **Retomada pós-apply:** `task_entity_resolution_realign_and_resume`
- **Owner:** Data/AI Pipeline Agent (`data_agent`)
- **Ação:** `define_entity_resolution`
- **Versão metodológica:** `entity-resolver-v1`
- **Data:** 2026-06-28
- **Estado:** schema `0006` aplicado/verificado (DEC-0015); spec re-alinhada; núcleo do resolver retomado em `services/data-engine` (§10.3)
- **Natureza:** spec + implementação local — nenhuma chamada LLM real, conexão ao banco, mutação de raw ou geração de número
- **Dependência:** `DATA-COLLECT-001` e raw completo em `raw_youtube_videos`
- **Fontes vinculantes:** `context/03_Data_AI_Agents_Methodology.md` §5; `context/NOXUND_Hotspot_Arquitetura_de_Agentes.md` Agente 3; `docs/product/mvp-backlog.md` Épico 5; DEC-0014; **DEC-0015**; `docs/database/HANDOFF-entity-resolution-candidates-apply-closeout.md`; `docs/database/DATA-AI-0007-phase5-approval.md` §§1 e 3; `docs/security/SEC-0017-entity-candidates-rls-review.md`; `docs/data/DATA-COLLECT-001-youtube-collection-spec.md`.

## 1. Resultado e limite desta especificação

Esta especificação fecha a metodologia da única zona generativa do pipeline: extrair um nome de artista já sustentado pelo título-fonte. Regex e validação determinística decidem; o LLM apenas propõe texto em casos ambíguos. Score, Velocity, Signals, Competition, ranking e Example continuam fora da IA.

O contrato lógico está definido nos §§2–9. A DEC-0014 encerrou `OPEN-DATA-ENTITY-001`: `video_artist_mappings` continua sendo a projeção canônica final, enquanto a tabela aditiva `entity_resolution_candidates` guarda somente o trabalho-em-progresso da revisão. Decisão/override humano vive em `audit_events`; quando consumido pelo scoring, o fato não determinístico é congelado em `artist_metrics.metrics_detail_json.overrides[]`.

A migration `20260620000006_entity_resolution_candidates.sql` está **aplicada e verificada em `production-db`**: run `28343949123`, commit `9a1ac52`, decisão DEC-0015. O apply já consumado não é repetido nesta tarefa. A Fase 9 continua vetada e `0007/producer_events` continua parked.

## 2. Entrada, pré-condições e saída lógica

### 2.1 Entrada por vídeo

| Campo | Origem | Regra |
|---|---|---|
| `run_id` | `raw_youtube_videos.run_id` | Run deve ter passado o gate de completude de DATA-COLLECT-001. |
| `video_id` | `raw_youtube_videos.video_id` | Compõe a chave natural e não pode mudar. |
| `source_title` | `raw_youtube_videos.title` | Título-fonte imutável; se nulo/vazio, não invocar LLM nem criar candidato: rejeitar e encaminhar ao fluxo de qualidade da coleta. |
| `resolver_version` | configuração do resolver | Sempre `entity-resolver-v1` nesta versão; nunca vazio. |

A FK live `(run_id, video_id) → raw_youtube_videos(run_id, video_id)` é a âncora de proveniência. O resolver não aceita título fornecido fora do raw nem de outra run.

### 2.2 Estado lógico da resolução

```json
{
  "run_id": "<uuid da coleta>",
  "video_id": "<id YouTube>",
  "resolver_version": "entity-resolver-v1",
  "source_method": "regex | llm_assisted | human_override | unknown",
  "candidate": "<span do título ou null>",
  "decision": "accepted | review_required | rejected",
  "final_name": "<nome sustentado pelo título ou null>",
  "needs_review": true,
  "reason_code": "<código determinístico>"
}
```

Este é um contrato lógico, não um novo schema. `needs_review` é o gate operacional. Não existe confiança numérica: o LLM não retorna score, percentual, ranking ou outro valor analítico. Dígitos só podem aparecer quando já pertencem ao nome copiado do título-fonte.

Projeção de estado: `review_required` com candidato válido vira `entity_resolution_candidates.status = pending` e não cria mapping; autoaceite regex vira mapping final; decisão humana fecha/audita a fila e só aprovação válida cria mapping; rejeição fica sem mapping. `source_title` permanece no raw, `reason_code` não é escondido em `review_notes` e nenhum desses estados carrega métricas.

## 3. Normalização determinística

`normalize_for_match(text)` é parte de `entity-resolver-v1` e executa, nesta ordem:

1. rejeitar `null`; converter string vazia em vazio normalizado;
2. aplicar Unicode NFKC;
3. aplicar Unicode casefold;
4. substituir cada caractere Unicode de pontuação, símbolo ou separador por um espaço ASCII;
5. colapsar qualquer sequência de whitespace para um único espaço;
6. remover whitespace das extremidades.

Não remover letras, dígitos nem marcas diacríticas. A grafia exibida vem sempre do span original do título ou da decisão humana validada; a forma normalizada serve somente para comparação.

### Guardrail de substring

Um candidato é sustentado pelo título se, e somente se:

- `normalize_for_match(candidate)` não é vazio; e
- seus tokens aparecem como uma sequência contígua de tokens completos em `normalize_for_match(source_title)`.

Correspondência dentro de outra palavra não vale. A mesma função valida regex, saída LLM e edição humana. Falha gera `reason_code = candidate_outside_source_title`, decisão `rejected` e proíbe qualquer entrada downstream.

## 4. Etapa 1 — regex-first

O resolver identifica ocorrências Unicode/case-insensitive do padrão conceitual:

```text
<artist> whitespace+ type whitespace+ beat <word-boundary>
```

Para cada ocorrência, `<artist>` é o span não vazio imediatamente anterior a `type beat`, limitado pelo início do título ou pelo delimitador estrutural mais próximo (`|`, `:`, colchete/parêntese fechado ou dash cercado por whitespace). O span é trimado, mas sua grafia não é reescrita.

### 4.1 Autoaceite por regex

`method = regex` e `needs_review = false` somente quando todas as condições passam:

- existe exatamente uma ocorrência de `type beat` e exatamente um candidato;
- o candidato passa o guardrail do §3;
- não há indicador de múltiplos artistas: conectores isolados `x`, `&`, `/`, `feat`, `ft` ou lista por vírgula;
- o candidato não contém metadata residual: marcador `free`, `prod`, ano isolado, BPM/key, preço/licença ou bloco delimitado;
- lookup normalizado em `artists.canonical_name` e `artist_aliases.alias` retorna no máximo um artista.

Zero match, múltiplos matches, qualquer flag acima ou colisão de alias produz `reason_code` determinístico e segue ao fallback LLM. Um `&` legítimo em nome de artista continua seguro: apenas exige revisão, não é removido.

### 4.2 Canonicalização por regex

- Um único match em `artists`/`artist_aliases` reutiliza o `artist_id` existente.
- Nenhum match permite criar `artists.canonical_name` e alias apenas para candidato regex já autoaceito.
- Mais de um match nunca escolhe arbitrariamente: segue para revisão.

## 5. Etapa 2 — LLM somente como fallback ambíguo

O LLM só pode ser chamado depois da regex produzir uma razão de ambiguidade e depois de o replay lookup do §8 confirmar que não existe fato persistido para a chave natural. A entrada contém somente o título-fonte; não recebe views, likes, score, ranking, dados de canal ou conhecimento externo.

### 5.1 Prompt `entity-resolver-v1/llm-fallback-v1`

```text
SYSTEM
Você extrai um possível nome de artista de UM título de vídeo do YouTube.
Use somente caracteres/texto presentes no título recebido.
Não use conhecimento externo, não complete nomes e não traduza.
Se não houver exatamente um candidato plausível, retorne candidate=null.
Retorne somente JSON válido no schema solicitado.
Não retorne explicação, confiança, score, percentual, ranking ou campo numérico de avaliação.
Dígitos só podem aparecer quando copiados dentro do candidate como parte do nome.

USER
{"title":"<source_title verbatim>"}

OUTPUT SCHEMA
{"candidate": string | null}
additionalProperties=false
```

O identificador do modelo e a configuração efetiva integram a configuração versionada do resolver. Alterar normalizador, regex, lista de ambiguidade, prompt, modelo ou configuração exige nova `resolver_version`; nunca editar o significado de `entity-resolver-v1`.

Contrato de escrita desta versão:

- `resolver_version = 'entity-resolver-v1'` em toda saída e persistência; `NULL`, vazio ou só whitespace falha antes do write;
- `prompt_version = 'llm-fallback-v1'` quando `method = 'llm_assisted'`; `NULL`, vazio ou só whitespace falha antes do write;
- o par versão/configuração é selecionado por allow-list de código, nunca aceito de texto do modelo nem do cliente;
- os CHECKs estruturais impedem versão vazia mesmo se o write-layer regredir; `DATA-ENTITY-F01` foi levantado no re-review do §10.3.

### 5.2 Validação e destino da saída

| Saída | Decisão |
|---|---|
| `candidate = null` | `rejected`, `reason_code = llm_no_single_candidate`; não criar mapping aceito. |
| candidate fora do título | `rejected`, `reason_code = candidate_outside_source_title`; não criar mapping. |
| candidate sustentado pelo título | `review_required`, `method = llm_assisted`, `needs_review = true`. |
| output inválido/extra | `rejected`, `reason_code = llm_contract_violation`; não tentar interpretar texto livre. |

**Política travada:** toda saída LLM válida exige revisão humana. Não existe caminho de autoaceite LLM e não existe confiança numérica gerada pelo modelo.

## 6. Fila e decisão humana

A fila física é `entity_resolution_candidates`, staging **mutável** e não canônica. A unidade ativa é `(run_id, video_id)`: o índice parcial único permite no máximo uma linha com `status = 'pending'` por vídeo/run. `resolver_version` continua obrigatório como atributo versionado dessa tentativa. Ao fechar o pendente, novas tentativas podem ser inseridas; linhas `approved`/`rejected` anteriores coexistem porque não participam do índice parcial.

Essa coexistência não transforma a tabela em log imutável. O write-layer não apaga nem reaproveita uma linha finalizada para outra tentativa, mas a trilha autoritativa da decisão é o `audit_events` append-only. Se já existe um pendente, o resolver o reutiliza e não chama o LLM novamente. Mudança de versão não contorna o dedup: primeiro fecha/audita o pendente corrente; só então cria nova tentativa.

### 6.0 Shape aplicado (DEC-0015)

- enum `entity_candidate_status = pending | approved | rejected`; método reutiliza `video_artist_method`;
- colunas: `id`, `run_id`, `video_id`, `proposed_name`, `artist_id`, `method`, `resolver_version`, `prompt_version`, `status`, `review_notes`, `reviewed_at`, `created_at`;
- 3 FK `ON DELETE RESTRICT`: `run_id → report_runs`, `artist_id → artists` (nullable) e composta `(run_id, video_id) → raw_youtube_videos`;
- 4 CHECK: prompt obrigatório para `llm_assisted`, `reviewed_at` obrigatório fora de pending, `resolver_version` non-blank e `prompt_version` non-blank quando presente;
- dedup `UNIQUE+PARTIAL (run_id, video_id) WHERE status='pending'`, índice parcial de drenagem por `created_at`, índice `(run_id,status)` e índice parcial de `artist_id`;
- staging mutável com **0 trigger**; default-deny vivo por RLS-on + revoke de `anon`/`authenticated`, **0 policy/VIEW**.

O run `28343949123` comprovou esse shape estrutural e empiricamente, inclusive F01, dedup, proveniência e default-deny. O código do resolver consome essas garantias; não tenta recriar constraints na aplicação.

### 6.1 Projeção lógica → fila física

| `entity_resolution_candidates` | Regra do write-layer |
|---|---|
| `run_id`, `video_id` | Chave natural ligada por FK composta ao raw; `source_title` é relido do raw e não duplicado. |
| `proposed_name` | Somente o span que passou o guardrail do §3; nunca título inteiro, metadata, número analítico ou `artist_id`. |
| `artist_id` nullable | Pode apontar a artista já existente quando resolvido; nunca obriga criar artista provisório. |
| `method` | Método de origem da tentativa. Não é reescrito para fingir que uma edição humana foi a proposta original. |
| `resolver_version` | Versão determinística non-blank; nesta spec, `entity-resolver-v1`. |
| `prompt_version` | Obrigatória e non-blank para `llm_assisted`; nesta spec, `llm-fallback-v1`. |
| `status` | Transição operacional somente `pending → approved | rejected`; reversão/reuso é proibido no writer. |
| `review_notes` | Nota humana opcional e curta; nunca envelope de campos ausentes, secret ou PII. |
| `reviewed_at` | Carimbado ao fechar o item; não substitui o evento de auditoria. |

`reason_code`, `needs_review`, `decision` e `final_name` continuam no estado lógico. Não são escondidos em `review_notes`: antes da decisão, `reason_code` é reproduzível pelo raw + `resolver_version`; na decisão, os campos completos são persistidos no evento de auditoria e, se consumidos pelo scoring, no override congelado do §8.

Um resultado LLM sem candidato válido não cria linha na fila, porque `proposed_name` é obrigatório e só aceita span válido. O fato não determinístico rejeitado deve ser persistido em `audit_events` com ator pipeline/system, chave natural, versões, `candidate = null`, decisão e `reason_code`; assim o replay não rechama o modelo.

### 6.2 Fechamento humano e atomicidade

Itens pendentes são inelegíveis para Channel Filter, scoring, relatório e publish. A decisão é uma operação transacional do write-layer: fechar a linha da fila, inserir o evento append-only e, somente em aprovação válida, criar/reutilizar o artista canônico e gravar o único `video_artist_mappings` final.

| Decisão humana | Mapping final | Auditoria |
|---|---|---|
| aprovar candidato sem alteração | `method = llm_assisted`, `needs_review = false` | `audit_events.action = mapping.review_approved` |
| editar para outro span válido do título | `method = human_override`, `needs_review = false` | `audit_events.action = mapping.human_override` |
| rejeitar | nenhuma resolução elegível | `audit_events.action = mapping.review_rejected` |

Toda edição humana passa novamente pelo guardrail do §3. Nome fora do título é rejeitado mesmo por humano; não existe override desse guardrail.

O evento de auditoria registra `entity_table = video_artist_mappings`, `entity_id` quando houver mapping, `before_json`, `after_json` e motivo. `after_json` deve carregar `run_id`, `video_id`, `resolver_version`, `prompt_version` quando aplicável, `source_method`, `candidate`, `decision`, `final_name` e `reason_code`; o UUID polimórfico sozinho não satisfaz replay por chave natural.

### 6.3 Candidato fora das tabelas canônicas

- Regex autoaceito pode projetar diretamente a resolução final; não precisa criar item artificial de fila.
- Um candidato LLM `pending` ou qualquer candidato `rejected` **não cria** linha em `artists` nem em `video_artist_mappings`.
- `proposed_name` como STRING e `artist_id` nullable removem a necessidade estrutural de artista sentinela. A garantia cross-table é completada pelo contrato transacional do writer — não existe constraint SQL que impeça um cliente privilegiado de inserir diretamente em outra tabela.
- Aprovação/edição válida é o único caminho da fila para as tabelas canônicas; rejeição encerra e audita sem mapping.

### 6.4 Contrato Security vinculante do write-layer

Conforme SEC-0017:

1. nunca serializar `YOUTUBE_API_KEY`, credencial, request context ou PII em `review_notes`/`proposed_name`; `proposed_name` contém somente o span público validado;
2. `review_notes` e `proposed_name` não entram em logs, Sentry, exceções, telemetry nem `AgentResult` (higiene SEC-F10);
3. o job do resolver deve ter canary secret, espelhando SEC-0016: a fixture injeta um marcador no contexto secreto (fora do título) e falha se ele surgir em SQL bind de `review_notes`/`proposed_name`, log, erro ou artefato;
4. `review_notes` é interna e nunca chega ao produtor. Se surgir coluna estruturada/`jsonb`, SEC-F08 reabre antes do merge.

O writer retomado em `postgres_entity_resolution.py` usa SQL parametrizado e allow-list: candidatos automatizados entram somente como `llm_assisted/pending`, com `artist_id = NULL` e `review_notes = NULL`; erros de driver são substituídos por mensagem sanitizada. Nenhum título, candidato, nota ou diagnóstico livre é logado pelo módulo.

## 7. Projeção física compatível hoje

Para uma resolução final que o schema consegue representar:

| `video_artist_mappings` | Origem |
|---|---|
| `run_id`, `video_id` | chave natural do raw |
| `artist_id` | artista canônico aprovado |
| `extracted_name` | candidato/final name sustentado pelo título |
| `method` | `regex`, `llm_assisted` ou `human_override` conforme §§4–6 |
| `resolver_version` | `entity-resolver-v1`, não vazio |
| `needs_review` | `false` somente após autoaceite regex ou decisão humana |
| `review_notes` | motivo humano legível e sanitizado; não é envelope para campos ausentes, secret ou PII |

A unique key `(run_id, video_id)` mantém um mapping canônico. Tentativas intermediárias não viram mappings adicionais. A fila não é fonte da verdade final e não é consultada para reconstruir métrica já congelada. Recompute de computed é permitido, mas fatos LLM/humanos precisam sobreviver conforme §8.

## 8. Replay e P5-REPRO-01

### 8.1 Ordem obrigatória

1. Carregar raw por `(run_id, video_id)` e validar `resolver_version` non-blank/registrada.
2. Em replay de scoring/publicação, carregar primeiro o fato congelado em `metrics_detail_json.overrides[]`; a fila mutável não participa dessa reconstrução.
3. Fora desse snapshot, consultar o evento append-only LLM/humano por `(run_id, video_id, resolver_version)` e validar o payload natural completo do §6.2.
4. Se não houver decisão final, consultar o pendente corrente por `(run_id, video_id)`. Versão igual reutiliza o candidato sem LLM; versão diferente bloqueia nova tentativa até o item corrente ser fechado/auditado.
5. Se existir mapping regex determinístico coerente ou decisão persistida, reproduzi-lo sem chamar LLM.
6. Somente na ausência de qualquer fato persistido, regex pode ser reexecutada porque é determinística.
7. LLM só pode ser invocada na primeira resolução real. Resultado válido entra na fila; resultado inválido/null é auditado como rejeição. Nunca invocar em replay/P5-REPRO-01.

### 8.2 Evidência congelada no scoring

Cada decisão não determinística consumida pelo scoring entra em `artist_metrics.metrics_detail_json.overrides[]`:

```json
{
  "run_id": "<uuid>",
  "video_id": "<id YouTube>",
  "resolver_version": "entity-resolver-v1",
  "source_method": "llm_assisted | human_override",
  "candidate": "<span ou null>",
  "decision": "approved | edited | rejected",
  "final_name": "<span válido ou null>",
  "reason_code": "<código>"
}
```

Regex autoaceita é reconstruível por raw + `resolver_version` e não exige override. `metrics_detail_json.versions.resolver_version` preserva a versão do Entity Resolver. `metrics_detail_json.versions.rule_version` preserva separadamente a versão do Channel Filter; não é hoje uma coluna de `video_artist_mappings`.

`audit_events` é o registro append-only da decisão/override; `overrides[]` é a cópia congelada consumida pelo cálculo. `entity_resolution_candidates` é somente a fila operacional e jamais substitui qualquer um deles, mesmo que mantenha linhas finalizadas por conveniência/auditoria operacional.

P5-REPRO-01 deve usar os mesmos fatos armazenados nas duas rodadas e afirmar zero chamadas ao adaptador LLM. Qualquer divergência de mapping, ordem, evidência ou chamada não esperada bloqueia publish.

Na implementação retomada, `EntityResolver` consulta `ReplayFactStore` antes de `CandidateQueue`; fato final ou pending reaproveitado impede nova chamada. `PostgresAuditReplayFacts` persiste/recarrega payload allow-listed por `run_id+video_id+resolver_version`; `PostgresCandidateQueue` espelha o conflito parcial do pending. A leitura de `metrics_detail_json.overrides[]` pertence ao runner de scoring/P5, não à fila nem ao adaptador LLM.

## 9. Fail-closed e Stop Conditions

- Mapping com `needs_review = true`, candidato rejeitado ou sem decisão humana não segue downstream.
- Pendente/rejeitado não cria artista nem mapping canônico; falha na transação de auditoria impede fechar o item.
- Falha do LLM não cai para chute, alias arbitrário ou nome externo; vira rejeição/revisão explícita.
- Colisão de aliases, múltiplos artistas ou falta de evidência nunca é resolvida por ordem de banco.
- Pedido para o LLM gerar confiança numérica ou qualquer número do relatório retorna `needs_review`.
- A fila guarda nomes, não métricas: zero Score, Velocity, Signals, Competition, ranking ou Example em coluna, nota, prompt ou output do modelo.
- Versão `NULL`/vazia/whitespace, transição reversa de status ou segundo pendente falham antes de qualquer chamada downstream.
- Secret/PII em bind/log/erro é falha bloqueante do canary; `review_notes` nunca é fallback de serialização.
- Mudança de guardrail, escopo, fonte ou uso de IA fora da Entity Resolution exige nova versão/revisão.
- Nome que falha o guardrail é forbidden decision e sempre rejeitado.

## 10. CLOSED-DATA-ENTITY-001 + estado pós-apply

### 10.1 Resolução da DEC-0014

| Divergência original | Resolução vinculante |
|---|---|
| `confidence` em mapping | Removido. Revisão é binária; IA não gera número. |
| `rule_version` em mapping | Removido. `resolver_version` versiona Entity Resolution; `rule_version` pertence ao Channel Filter. |
| evidence/override no mapping | Não criar coluna. Decisão/override fica em `audit_events`; cópia consumida pelo scoring congela em `metrics_detail_json.overrides[]`. |
| fila durável com `artist_id NOT NULL` no mapping | Resolvido pela tabela aditiva `entity_resolution_candidates`, com `proposed_name` STRING e `artist_id` nullable. |

`OPEN-DATA-ENTITY-001` está encerrado como decisão de produto/schema. Nenhum campo faltante é serializado em `review_notes`; artista sentinela/provisório continua proibido.

### 10.2 Schema vivo confirmado por DEC-0015

- ✅ dedup do pendente: índice parcial único `(run_id, video_id) WHERE status='pending'`; linhas finalizadas coexistem, e a trilha autoritativa continua no `audit_events` append-only;
- ✅ replay: fila = WIP mutável; decisão/override = `audit_events`; verdade consumida pelo scoring = `metrics_detail_json.overrides[]` com chave natural;
- ✅ candidato off-canonical: STRING + FK raw + `artist_id` nullable suportam revisão sem artista/mapping provisório; contrato cross-table do §6.3 é vinculante;
- ✅ fila de nomes: zero Score/Velocity/Signals/Competition/ranking/Example e guardrail de span do §3 preservado;
- ✅ Security: contrato sem secret/PII, higiene SEC-F10 e canary SEC-0016 absorvidos no §6.4;
- ✅ **`DATA-ENTITY-F01` levantado:** CHECKs nomeados rejeitam `resolver_version`/`prompt_version` presentes em branco; `llm_prompt_chk` continua exigindo prompt no caminho LLM, enquanto regex preserva `prompt_version = NULL`.
- ✅ apply/verify: run `28343949123`, commit `9a1ac52`; migration `0006` viva em `production-db`, rollback não executado e `0007` fora do apply.

### 10.3 Retomada do resolver

✅ **SPEC RE-ALINHADA E NÚCLEO RETOMADO.**

Artefatos locais:

1. `entity_resolution.py`: normalizador/guardrail, regex-first, contrato JSON LLM estrito, replay-before-LLM e emissão de pending;
2. `postgres_entity_resolution.py`: fila com SQL parametrizado/dedup parcial, FK delegada ao schema vivo, audit replay por chave natural e erros sanitizados;
3. `tests/test_entity_resolution.py`: casos regex/LLM/guardrail, dedup/replay, versões F01, write-layer sem `artist_id`/`review_notes` e canary SEC-F10/SEC-0016;
4. nenhum adapter externo foi chamado e nenhuma conexão foi aberta. Catálogo real, driver/conexão e adapter LLM serão injetados no job do pipeline.

O schema já aplicado não é alterado por essa retomada. A Fase 9 permanece vetada e nenhum número entra na zona generativa.

## 11. Casos de validação obrigatórios

O núcleo local cobre os casos de extração, LLM restrito, replay/dedup, F01 e canary. Casos de decisão humana, integração real com Postgres/LLM e P5 permanecem gates do runner — testes unitários não fingem execução externa.

| Caso | Resultado esperado |
|---|---|
| único `<artist> type beat`, variação de case/pontuação | regex aceita após normalização; `needs_review=false`. |
| dois artistas, dois matches ou metadata residual | não autoaceitar; acionar LLM. |
| LLM retorna span contido no título | guardrail passa, mas `needs_review=true`. |
| LLM retorna nome externo, `null` ou JSON inválido | rejeição persistida para replay; nenhuma fila inválida nem mapping elegível. |
| segundo `pending` para mesmo `(run_id, video_id)` | `unique_violation`; reutilizar o pendente existente e não chamar LLM. |
| pendente anterior fechado | novo pendente pode ser criado; `approved`/`rejected` anterior coexiste sem ser reusado. |
| humano aprova sem editar | `llm_assisted`, review fechada e auditada. |
| humano edita para outro span válido | `human_override`, review fechada e auditada. |
| humano edita para texto externo | rejeitar; guardrail não pode ser sobrescrito. |
| candidato pending/rejected | zero novas linhas em `artists` e `video_artist_mappings`. |
| `resolver_version` `NULL`/vazia/whitespace | write-layer e CHECK rejeitam; probe de `DATA-ENTITY-F01`. |
| `llm_assisted` com `prompt_version` `NULL`/vazia/whitespace | write-layer e CHECK rejeitam; probe de `DATA-ENTITY-F01`. |
| `(run_id, video_id)` ausente/outro run | FK rejeita fila e mapping. |
| replay com evento/override armazenado | output idêntico e mock LLM com zero chamadas; fila mutável não substitui fato congelado. |
| override sem `run_id + video_id` | rejeitar antes do scoring; CHECK F5-06A também rejeita na métrica. |
| canary secret/PII no contexto | marcador ausente de binds, banco, log, erro, Sentry e `AgentResult`; teste falha se vazar. |
| log do resolver | allow-list sem `proposed_name`, `review_notes` ou título-fonte (SEC-F10). |
| solicitação de Score/confiança numérica via LLM | retornar `needs_review`; nenhum número produzido. |

## 12. Revisões e fora do escopo

- **Product Orchestrator:** `OPEN-DATA-ENTITY-001` encerrado pela DEC-0014.
- **Database:** autoria do schema e mitigação design-only de `DATA-ENTITY-F01` concluídas.
- **Security:** SEC-0017 aprovado sem bloqueio; contrato e carry-forwards incorporados nesta spec.
- **Data/AI:** ✅ spec pós-apply re-alinhada e núcleo do resolver retomado nesta tarefa.
- **Apply:** ✅ já concluído e registrado pela DEC-0015; esta tarefa não reaplicou nem conectou ao banco.
- **Fase 9:** não destravada; policies/VIEW pública continuam sob veto separado.
- **P5-REPRO-01:** continua bloqueante antes do primeiro publish.

Fora do escopo: rodar regex/LLM sobre dados reais, instalar SDK/modelo, criar secret, gerar números, Channel Filter, scoring, Opportunity, multi-keyword ou multi-nicho.

## 13. Sequenciamento pipeline-first após esta retomada

| Etapa | Dependência de entrada | Saída/gate |
|---|---|---|
| 1. Integrar Entity Resolver | run completo de DATA-COLLECT-001; catálogo canônico; conexão server-side; adapter LLM restrito | regex aceito → mapping canônico; LLM válido → pending; rejeição → audit fact; canary e testes verdes antes de job real |
| 2. Channel Filter | somente mappings finais `needs_review=false`; fila pending não entra | `channel_eligibility` com `rule_version`; canais distintos alimentam Competition sem duplicar Signals |
| 3. Scoring + Opportunity | eligibility + raw imutável + fatos replayable | código determinístico com `rubric_version` + `rubric_hash`; overrides copiados para evidência congelada; IA gera zero número |
| 4. P5-REPRO-01 | fixture completa das etapas 1–3 | duas rodadas canônicas, byte-idênticas nos campos de negócio/evidência e **zero chamadas LLM no replay**; falha bloqueia o 1º publish |

`producer_events` (`0007`) não entra nessa cadeia até captura virar gargalo (DEC-0013). Fase 9, marketplace e features de Fase 2 continuam fora.
