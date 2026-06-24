# DATA-AI-0002 - Data/AI Review - Fase 2 Versionamento

- **Revisor:** Data/AI Pipeline Agent
- **Tarefa:** `task_phase2_dataai_validate_reproducibility`
- **Action:** `validate_reproducibility`
- **Alvo:** `supabase/migrations/20260620000002_phase2_versioning.sql`
- **Natureza:** validacao estrutural de reproducibilidade; nenhum apply, nenhum Score, nenhum hash concreto e nenhum valor de metrica gerado.

---

## 0. Veredito

**Aprovado por Data/AI para o gate matrix #5. Sem veto metodologico ao DDL da Fase 2.**

O DDL cria somente a estrutura de versionamento (`rubric_versions` e `outcome_weight_versions`) e preserva o contrato de que Score, rubric e pesos sao calculados/interpretados pelo data-engine, nao pelo banco. O `config_json` fica opaco ao Database; o `hash` e armazenado, mas computado fora do banco pelo Data/AI.

---

## 1. Fidelidade ao rubric do SSOT

O seed template comentado em `supabase/migrations/20260620000002_phase2_versioning.sql` linhas 126-141 captura fielmente a estrutura do rubric travado:

- componentes do SSOT: `velocity_normalized`, `signals`, `engagement_recency_weighted`, `channel_diversity`;
- pesos do SSOT preservados como `0.40`, `0.25`, `0.20`, `0.15`;
- `weights_sum` declarado como `1.00`;
- normalizacao capturada no componente `velocity_normalized` e no texto de medida relativo a amostra;
- fonte documentada como decisao de produto, sem redecidir metodologia.

Isto e suficiente para a Fase 2 porque esta migration nao executa seed nem implementa formula. A formula completa continua pertencendo ao data-engine deterministico; se o schema futuro exigir maior detalhe em `config_json`, isso deve ser uma nova decisao Data/AI + PO + QA, nao uma inferencia do Database.

---

## 2. Contrato do `rubric_hash`

Ratifico o contrato do DDL: `rubric_hash` e deterministico, computado pelo data-engine sobre a serializacao canonica do `config_json`, e o Database nao fabrica hash nem gera numero.

Regra canonica Data/AI para `config_json -> rubric_hash`:

- entrada: objeto logico `config_json` antes do insert, nao `jsonb::text` emitido pelo Postgres;
- serializacao: JSON canonico estilo JCS/RFC 8785;
- bytes: UTF-8;
- objetos: chaves ordenadas recursivamente por ordem lexicografica Unicode;
- arrays: ordem preservada como definida no config;
- whitespace: nenhum espaco insignificante;
- strings/booleans/null: forma JSON canonica;
- numeros: representacao JSON canonica minima do valor, sem depender de formatacao SQL como casas decimais exibidas;
- digest: SHA-256 dos bytes canonicos, codificado em hex lowercase;
- escopo do digest: somente `config_json`; `version`, `active_from` e `created_at` nao entram no hash.

Consequencia esperada: duas versoes textuais diferentes com o mesmo `config_json` canonico produzem o mesmo hash; a identidade operacional usada por Fase 5 continua sendo o par `(rubric_version, rubric_hash)`.

---

## 3. Decisao (b): `outcome_weight_versions.hash`

**Decisao Data/AI: manter `hash` em `outcome_weight_versions`.**

Uso real no MVP/Fase 6: **nao ha uso direto em `producer_events`**. Fase 6 registra eventos append-only; analise ponderada de outcomes ainda nao existe e a tabela pode ficar vazia ate haver analise real.

Justificativa para manter:

- e estrutural, nao produto: nao altera Score, exibicao, eventos, nem rubric;
- evita que analises futuras de outcomes usem pesos hardcoded ou configs sem identidade deterministica;
- aplica a mesma disciplina de versionamento imutavel das configuracoes internas;
- permite FK/joins futuros por `(version, hash)` sem migration corretiva;
- remover agora reduziria a auditabilidade futura por pouco ganho pratico.

Portanto, o campo fica como preparacao de auditabilidade para analise futura de `producer_events`/`producer_outcomes` conceitual, nao como dependencia atual dos eventos.

---

## 4. `unique(version, hash)` e consumo futuro

Ratifico `unique(version)` + `unique(version, hash)` em `rubric_versions`.

O par composto e coerente com o consumo futuro de `artist_metrics` e `report_runs` por `(rubric_version, rubric_hash)` na Fase 5. A unicidade composta e deliberada porque uma FK composta no Postgres precisa de alvo unico nas colunas referenciadas, e `version` sozinho nao expressa a identidade completa usada pelo pipeline.

Para `outcome_weight_versions`, a mesma constraint fica como disciplina estrutural: sem consumo direto no MVP, mas pronta para analises futuras que precisem versionar pesos de outcome sem hardcode.

---

## 5. Garantias e limites

- Nenhum Score foi calculado.
- Nenhum hash concreto foi calculado.
- Nenhum peso/rubric foi alterado.
- Nenhuma mudanca de schema foi aplicada.
- Qualquer mudanca futura em componentes, pesos, normalizacao ou regra publica do Score deve escalar para Product Orchestrator + Data/AI + QA, conforme matrix #5.
