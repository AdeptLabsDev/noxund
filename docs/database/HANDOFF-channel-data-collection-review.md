# HANDOFF / Review de Database — Coleta gated de Channel Data (`channels.list → raw_youtube_channels`)

- **Tarefa:** `task_database_review_channel_data_collection` · ação `design_schema` (review-only)
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-07-01
- **Prioridade:** P1 (bloqueante do gate **G3** da §11 do runbook; não bloqueante de publish)
- **Estado:** **DESIGN/REVIEW-ONLY — ratifica integridade do schema JÁ VIVO. Zero ALTER, zero migration, zero `db push`, zero conexão, zero secret, zero coleta.** Fase 9 vetada; `0007`/producer_events PARKED; P5-REPRO-01 permanece gate de publish.
- **Autorização:** DEC-0017 item 7 (trilha gated autorizada a **desenhar/revisar**; execução livre NÃO).
- **Inputs revisados:**
  - `docs/infra/RUNBOOK-channel-data-collection.md`
  - `docs/data/DATA-COLLECT-002-channel-data-collection-spec.md`
  - `docs/product/decisions/DEC-0017-pipeline-v1-ratifications.md` (item 6 + aditivos item 45)
  - `supabase/migrations/20260620000004_phase4_raw_youtube_snapshots.sql` (`raw_youtube_channels` L128–146, triggers L165–170, RLS/revoke L179/186)
  - `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` (`channel_eligibility` L228–245; validadores estruturais F5-05A/F5-06A L108–188)

---

## 0. O que este documento é (e o que NÃO é)

É a **revisão de integridade de Database** exigida pelo gate **G3** do runbook e por `DATA-COLLECT-002 §12`. Ratifica que a coleta de Channel Data **popula um shape já aplicado e verificado** (DEC-0011/DEC-0012), sem tocar em schema, e registra as decisões dos slots aditivos futuros na **forma aditiva sem ALTER**.

**NÃO** autora migration, **NÃO** conecta ao banco, **NÃO** roda `supabase db push`, **NÃO** propõe nenhum `ALTER`, **NÃO** destrava Fase 9/RLS Policies nem `0007`. Toda afirmação abaixo é sobre DDL **já vivo**. Onde recomendo forma aditiva futura, ela é **design-only e explicitamente diferida** — não é autorização de apply.

---

## 1. Ratificação 1 — ZERO ALTER (a coleta popula o shape existente)

`raw_youtube_channels` (Fase 4) e `channel_eligibility` (Fase 5) estão **live e verificadas**. O contrato de escrita de `DATA-COLLECT-002 §4.1` é **byte-idêntico** ao DDL aplicado — coluna a coluna, tipo a tipo, nulabilidade a nulabilidade. Nenhuma coluna nova, nenhum tipo alterado, nenhum default novo.

### 1.1 Paridade contrato-de-coleta ↔ DDL aplicado (`raw_youtube_channels`, migration Fase 4 L128–140)

| Coluna aplicada | Tipo aplicado | Nulabilidade | Origem na coleta (`channels.list`) | Δ schema |
|---|---|---|---|---|
| `id` | `uuid` PK `default gen_random_uuid()` | not null (banco gera) | — (coletor não fornece) | **nenhum** |
| `run_id` | `uuid` → `report_runs(id)` `on delete restrict` | not null | UUID da **mesma** run (§1 runbook) | **nenhum** |
| `channel_id` | `text` | not null | `item.id` verbatim | **nenhum** |
| `title` | `text` | nullable | `item.snippet.title` | **nenhum** |
| `upload_count` | `bigint` | nullable | `statistics.videoCount` (ausente ⇒ NULL) | **nenhum** |
| `subscriber_count` | `bigint` | nullable | `statistics.subscriberCount` (oculto/ausente ⇒ NULL) | **nenhum** |
| `view_count` | `bigint` | nullable | `statistics.viewCount` (ausente ⇒ NULL) | **nenhum** |
| `raw_json` | `jsonb` | **not null** | objeto `item` completo, verbatim | **nenhum** |
| `fetched_at` | `timestamptz` `default now()` | not null | instante UTC do recebimento do body | **nenhum** |
| `constraint …_no_request_context` | CHECK anti-segredo | — | (defesa em profundidade, §2.4) | **nenhum** |

**Veredito:** a coleta é **INSERT-only sobre shape congelado**. `bigint` já cobre contadores de canais grandes (view/subscriber acima de int32 — comentário L124–127 do DDL). NULL ≠ 0 é **estrutural** (colunas nullable + `raw_json` como verdade última): a API que oculta/omite uma estatística chega ao Channel Filter com a coluna em `NULL`, e os gates 2/4 não disparam por ausência. **Zero ALTER ratificado.**

---

## 2. Ratificação 2 — FK composta, unicidade, imutabilidade, CHECK anti-segredo, append-only

### 2.1 Unicidade + chave de idempotência (`raw_youtube_channels`, L142–143)

```
create unique index raw_youtube_channels_run_channel_uidx
  on public.raw_youtube_channels (run_id, channel_id);
```

Impõe **uma linha por canal por run**. É simultaneamente (a) a chave de idempotência da retomada (`DATA-COLLECT-002 §5`) e (b) o **alvo** da FK composta de `channel_eligibility`. Confirmado.

### 2.2 FK composta `(run_id, channel_id)` com `ON DELETE RESTRICT` (`channel_eligibility`, L237–239)

```
constraint channel_eligibility_raw_channel_fk
  foreign key (run_id, channel_id)
  references public.raw_youtube_channels (run_id, channel_id) on delete restrict
```

+ `channel_eligibility_run_channel_uidx (run_id, channel_id)` (L241–242) → **um veredito por (run, canal)**.

**Subtileza de integridade confirmada (não é defeito):** o alvo da FK é o **índice único** `raw_youtube_channels_run_channel_uidx`, não uma `unique constraint` nomeada. PostgreSQL aceita um índice único (via `create unique index`) como alvo válido de FK — não exige constraint formal. Como **ambas as migrations já estão aplicadas e verificadas** (Fase 4 antes de Fase 5, ordem preservada), a FK foi **aceita pelo planner → está fisicamente vigente**. Nada a corrigir.

> **Nota de higiene (OPCIONAL, aditivo, NÃO aplicar agora):** algumas casas preferem uma `unique constraint` nomeada como alvo de FK por clareza de `pg_dump`/portabilidade. A forma-índice **é válida, é padrão Postgres e está live**; trocá-la seria `ALTER` fora desta trilha. **Não recomendo mexer** — registro apenas para que ninguém "ajude" adicionando constraint redundante depois.

**Duplo papel do `ON DELETE RESTRICT`** (nas duas FKs — `run_id → report_runs` e composta `→ raw_youtube_channels`): (i) não se apaga uma linha raw enquanto houver veredito apontando pra ela; (ii) não se insere veredito para um canal sem linha raw. É o alicerce declarativo do fail-closed (§3).

### 2.3 Imutabilidade por trigger — abaixo do `service_role` (`raw_youtube_channels`, L165–170)

```
create trigger raw_youtube_channels_immutable
  before update or delete on public.raw_youtube_channels
  for each row execute function public.raw_youtube_immutable();
create trigger raw_youtube_channels_no_truncate
  before truncate on public.raw_youtube_channels
  for each statement execute function public.raw_youtube_no_truncate();
```

As funções compartilhadas `raw_youtube_immutable()`/`raw_youtube_no_truncate()` (L46–66) **levantam exceção** (`restrict_violation`) em qualquer `UPDATE`/`DELETE`/`TRUNCATE`. Como o trigger vive **no banco, abaixo do `service_role`** (que faz bypass de RLS — SEC-F01), **nem o service_role muta o raw** (SEC-D03). O **único DML permitido é `INSERT`**. `UPSERT ... DO UPDATE` é barrado pelo mesmo caminho. **Append-only ratificado estruturalmente** — não depende de disciplina do coletor.

### 2.4 CHECK anti-segredo — backstop de topo, não o controle primário (`raw_youtube_channels`, L138–139)

```
constraint raw_youtube_channels_no_request_context
  check (not (raw_json ?| array['config', 'request', 'headers', 'authorization', 'key']))
```

O operador `?|` testa **apenas chaves de topo** do objeto `jsonb`. Um body legítimo de `channels.list` (`kind = youtube#channel`) nunca tem `config`/`request`/`headers`/`authorization`/`key` no topo → **zero falso-positivo** (SEC-F08). **Honestidade:** este CHECK é **defesa em profundidade**, não a linha primária contra vazamento de secret — ele **não** varre strings aninhadas nem impede um `?key=` embutido em texto. A linha primária é a disciplina **body-only** do coletor (`DATA-COLLECT-002 §3.2/§8`) + os testes G6.2/G6.3 do runbook (canary secret ausente de log/Sentry). O CHECK garante que **se** o envelope de transporte escapar do scrub, o `INSERT` **falha** em vez de persistir contexto de request. Confirmado como backstop correto; **não substitui** o scrub (é o que a própria spec §8 declara).

### 2.5 Papel de escrita e ausência de `FORCE ROW LEVEL SECURITY` (OQ-2)

A migration faz `enable row level security` (L179) + `revoke all ... from anon, authenticated` (L186) e **zero policies** (default-deny, SEC-F13). Confirmo que **não há `FORCE ROW LEVEL SECURITY`** em `raw_youtube_channels` (nem nas irmãs raw) em nenhum ponto da migration. Consequência de integridade:

- **anon/authenticated:** sem grant, sem policy → **não escrevem nada** (default-deny mantido; Fase 9 permanece vetada).
- **owner `postgres`:** sem `FORCE RLS`, o owner **ignora RLS** → pode `INSERT`. `UPDATE/DELETE/TRUNCATE` continuam barrados pelos triggers (§2.3).
- **`service_role`:** bypassa RLS (SEC-F01) → também poderia `INSERT`, mas idem barrado nos demais DMLs.

**Ratificação de Database para OQ-2:** o caminho de escrita recomendado é **`postgres`/DB-password (session pooler)** — consistente com SEC-F19 (mantém a service-role key fora do CI). É o mesmo papel que os verify scripts já usam. **Decisão conjunta com Security** (co-owner de RLS). Não requer nenhuma mudança de schema.

---

## 3. Ratificação 3 — DC2-01 fail-closed **imposto pelo schema** (sem tombstone agora)

**Cenário:** um `channel_id` presente em `raw_youtube_videos(run)` some de `channels.list` (deletado/suspenso) entre Video Data e Channel Data → o body **omite** o item.

**Por que o fail-closed é estrutural (não só convenção):**

1. `raw_json` é **`NOT NULL`** (L136). Sem `item` no body, não há cópia verbatim → **inserir linha exigiria fabricar `raw_json`**, o que a natureza append-only/verbatim proíbe. O `NOT NULL` **impede fisicamente** a linha-fantasma.
2. **Não há coluna de tombstone.** A tabela não tem `is_present`/`collection_status` — por design. Registrar "ausente" verbatim é impossível no shape atual.
3. A FK composta `channel_eligibility → raw_youtube_channels (run_id, channel_id)` `ON DELETE RESTRICT` (§2.2) faz o resto: sem linha raw do canal, **o veredito de elegibilidade não pode ser inserido** — o banco **rejeita** o `INSERT` do Channel Filter. O gate de set-equality de `DATA-COLLECT-002 §7` não fecha → `report_runs.status = 'failed'` → **recoleta = novo `run_id`** (run inteira).

**Ratificação `OPEN-DC2-01` = FAIL-CLOSED AGORA** (opção (a) da spec §11), coerente com DEC-0017 item 6. Justificativa de integridade: um canal que some entre os dois estágios torna a run **irreprodutível na fonte** (o raw do canal não existe mais para congelar); deixar avançar produziria Competition/elegibilidade sobre denominador furado — viola o non-negotiable "nada de número falso". Abortar + novo `run_id` é honesto e mantém **zero schema delta**.

**Tombstone = aditivo futuro, gated (design-only, NÃO aplicar).** Se a prática mostrar que canais somem com frequência que inviabilize runs legítimas, a forma aditiva **recomendada por Database** é uma **tabela irmã nova** — p.ex.:

```
-- FUTURO, ADITIVO, GATED — NÃO é parte desta trilha
create table public.channel_collection_absences (
  run_id      uuid not null references public.report_runs (id) on delete restrict,
  channel_id  text not null,
  status      text not null,           -- 'deleted' | 'suspended' | 'terminated'
  observed_at timestamptz not null default now(),
  primary key (run_id, channel_id)
);
```

**Por que tabela irmã e NÃO `ALTER` em `raw_youtube_channels`:** o raw é sagrado = **cópia verbatim do body da API, e nada mais**. Adicionar `is_present`/`collection_status` **na** tabela raw (ou relaxar `raw_json NOT NULL`) contaminaria "raw = body verbatim" e enfraqueceria a imutabilidade. Uma tabela irmã registra a ausência **sem sujar o raw** e sem mexer no shape congelado. Isso seria migration **aditiva + gated + nova `rule_version`** do Channel Filter (para o gate consumir ausência como decisão registrada em vez de falha) — **fora desta trilha**. Registrado, diferido.

---

## 4. Slots aditivos futuros — decisões (OPP-04 / OPP-05 / CHANNEL-03)

**Fundamento comum (por que nenhum exige ALTER):** os validadores estruturais F5-05A/F5-06A (`artist_metrics_detail_complete`, migration Fase 5 L108–158; `report_item_reason_complete` L164–185) têm semântica **mínimo-fechado / máximo-aberto**: exigem **presença/não-vazio** de um conjunto de chaves obrigatórias e **rejeitam `{}`/seções ausentes**, mas **não proíbem chaves adicionais**. Logo, evidência aditiva pode viajar como **chave extra** em `metrics_detail_json` / `selection_reason_json` — **aceita pelo CHECK, zero ALTER**. (Confirmado lendo cada branch: toda checagem é `if not (… ? 'chave') then return false`; não há cláusula que reprove chaves desconhecidas.) `channel_eligibility.reason` é `text` **sem CHECK** — deliberadamente storage-only (Fase 5: "não há CHECK de faixa/semântica; owner = Data/AI").

| Slot | Decisão Database | Forma aditiva **sem ALTER** (agora) | Forma com migration (só se um dia necessário) |
|---|---|---|---|
| **OPP-04** — auditoria de Competition por crescimento-7d (`>50%`) | **DEFER (accept-in-JSON)** | Trilha de auditoria do 7d sob `metrics_detail_json.competition.*` (bloco `competition` já é obrigatório; validador só exige `eligible_channel_ids[]` + `count`, **aceita** sub-chaves extras como `growth_7d`, `growth_window`, `basis`). | Coluna projetada em `artist_metrics` **só** se virar filtro de leitura quente — migration **aditiva** + guard storage-only. Não recomendo agora. |
| **OPP-05** — `opportunity_version` / `opportunity_hash` (versionar o passo de composição do Opportunity, espelhando `rubric_version/hash`) | **DEFER (accept-in-JSON)** | Carregar `opportunity_version`/`opportunity_hash` em `metrics_detail_json.versions.*` (bloco `versions` já é obrigatório e exige rubric/resolver/rule não-vazios; **aceita** chaves adicionais). | Quando o Opportunity ganhar tabela de saída persistida própria: novo `opportunity_versions (version, hash)` + FK composta (padrão F5-02 de `rubric_versions`) — migration **aditiva + gated**. Diferido. |
| **CHANNEL-03** — `reason` como enum (vocabulário fechado de motivos de inelegibilidade) | **DEFER — enforce na aplicação, DB permanece storage-only** | Manter `channel_eligibility.reason text`; vocabulário (`self_channel` / `insufficient_history` / `spam_burst` / `low_channel_signal`) **imposto pelo data-engine e versionado em `rule_version`**. Evidência estruturada do motivo pode acompanhar `metrics_detail_json.competition` no consumidor. | Enum/CHECK no banco = migration **aditiva + gated + nova `rule_version`**. **Não recomendo** — congelaria vocabulário no DDL e quebraria o princípio "DDL storage-only, semântica no Data/AI". |

**Relacionados (mesma linhagem aditiva, DEC-0017 item 45 — registrados, fora do escopo desta review):** **CHANNEL-05** (`rule_hash` de `channel-filter-v1`, análogo a `rubric_hash`) → forma aditiva em `versions.rule_hash`/futura coluna; **DC2-03** (`snippet.publishedAt`/idade de canal) → já vive verbatim em `raw_json`; gate de idade futuro = coluna projetada **aditiva** + nova `rule_version` (runbook §5, `OPEN-DC2-03`). Ambos **não bloqueiam** e **não exigem** nada agora.

**Princípio Database transversal:** todo slot aditivo é (i) **acomodável hoje** como chave em JSON aceita pelos validadores, **sem ALTER**; e (ii) **projetável depois** por migration **aditiva** (nunca destrutiva, nunca mutando raw) se e quando virar caminho de leitura quente. Versionamento (rubric/rule/opportunity) é o mecanismo de reversibilidade — reverter = nova versão, não `ALTER` retroativo.

---

## 5. Sumário de integridade (checklist G3)

| Item de integridade | Estado | Evidência |
|---|---|---|
| ZERO ALTER — coleta popula shape live | ✅ ratificado | §1 (paridade coluna-a-coluna; migração 4 L128–140) |
| Unicidade `(run_id, channel_id)` (1 linha/canal/run) | ✅ | L142–143 |
| FK composta `(run_id, channel_id)` `ON DELETE RESTRICT` | ✅ vigente (índice único como alvo, aceito pelo Postgres) | L237–239 vs L142–143 |
| Imutabilidade abaixo do `service_role` (INSERT-only) | ✅ | L165–170 + funções L46–66 |
| CHECK anti-segredo (backstop de topo, não o controle primário) | ✅ com ressalva honesta | §2.4; L138–139 |
| Sem `FORCE RLS` → owner `postgres` insere; default-deny p/ anon/auth | ✅ | L179/186; OQ-2 → postgres/DB-password |
| Append-only por `run_id`; recoleta = novo `run_id` | ✅ | §2.3 + ausência de rota de update |
| DC2-01 fail-closed **imposto pelo schema** (sem tombstone agora) | ✅ ratificado | §3 (`raw_json NOT NULL` + FK RESTRICT) |
| Slots aditivos (OPP-04/05, CHANNEL-03) — defer, forma aditiva sem ALTER | ✅ decidido | §4 (validadores L108–188 = mínimo-fechado/máximo-aberto) |

**Nenhum defeito de integridade encontrado. Nenhuma migração requerida. Nenhuma ação de apply autorizada por esta review.**

---

## 6. Handoff (template `docs/agents/handoff-template.md`)

### 1. Identificação
- **Tarefa:** `task_database_review_channel_data_collection`
- **Owner agent:** Database (`database_agent`)
- **Data:** 2026-07-01 · **Prioridade:** P1

### 2. Objetivo
Review design-only (zero ALTER) da coleta gated de Channel Data: ratificar integridade do schema já vivo (`raw_youtube_channels` Fase 4 + `channel_eligibility` Fase 5) e registrar decisões dos slots aditivos futuros na forma aditiva sem ALTER.

### 3. Critério de aceite
ZERO-ALTER ratificado; FK composta/unicidade/imutabilidade/CHECK anti-segredo confirmados (append-only por `run_id`); DC2-01 fail-closed confirmado (abortar→novo `run_id`; sem tombstone agora); decisões dos slots aditivos (OPP-04/05, CHANNEL-03) com forma aditiva sem ALTER; AgentResult com status + next_recommendation.

### 4. Resultado
- [x] Critério de aceite atendido.
- [x] Demonstrável: paridade coluna-a-coluna §1 contra migration Fase 4 L128–140; FK/triggers/CHECK verificados nas linhas citadas; validadores F5-05A/F5-06A lidos (mínimo-fechado/máximo-aberto) para fundamentar os aditivos.
- Entregue: esta review + ratificações §1–§4 + sumário §5. **Nenhuma migration, nenhuma conexão, nenhum apply.**

### 5. Arquivos alterados
- `docs/database/HANDOFF-channel-data-collection-review.md` — **novo** (esta review). **Zero** arquivo de schema/migration tocado.

### 6. Impacto no escopo
- Mantém o MVP travado? **Sim.** Zero tabela nova, zero marketplace/Fase 2.
- Toca non-negotiable? **Reforça** "raw imutável / NULL≠0 / nada de número falso" — não os enfraquece.
- Toca número/banco/auth/copy? **Banco: só review**, zero DDL. Slot de escrita (OQ-2) e CHECK anti-segredo são **co-decisão com Security**.

### 7. Validação executada
- Leitura direta do DDL aplicado (migrations Fase 4/5) confirmando cada asserção com file:line. Nenhum teste de banco executado (review-only, sem conexão — por constraint da tarefa).
- Reprodutibilidade: fail-closed DC2-01 e append-only mantêm a run **reconstruível por `run_id`**; pré-condição de P5-REPRO-01 preservada.

### 8. Riscos
- **Mitigado:** linha-fantasma para canal omitido é **impossível** (`raw_json NOT NULL` + FK RESTRICT) — fail-closed é estrutural, não confia no coletor.
- **Residual (não-Database):** vazamento de secret depende do scrub body-only + testes G6 (Security/DevOps); o CHECK é só backstop de topo (§2.4). Higiene de log/Sentry é gate G2/G6, não deste review.
- **Aditivos:** se tombstone/enum forem aplicados no futuro, exigem migration **aditiva + gated + nova versão** — nunca ALTER destrutivo nem mutação de raw (forma recomendada em §3/§4).

### 9. Revisões necessárias
- [x] Database/Data Integrity Review — **este documento** (gate G3).
- [ ] Security Review — OQ-2 (papel de escrita postgres/DB-password vs service_role) + confirmar ausência de `FORCE RLS` do lado de política; SEC-F08/F23 já em SEC-0019 (gate G2). **Acionar.**
- [ ] Data/AI Review — forma dos aditivos em `metrics_detail_json`/`rule_version` (OPP-04/05, CHANNEL-03/05) quando forem implementados.
- [ ] Product Lead — ratificar `OPEN-DC2-01 = fail-closed` e os defers dos slots aditivos (nenhum é OPEN DECISION bloqueante; são registros).

### 10. Próximos passos
- Gate **G3 verde** (Database). Desbloqueia sequência dos demais gates da §11 (G2 Security → G4 DevOps `define_pipeline` → G5 `configure_env` → G6 testes → G7 dispatch humano).
- **Nada** aqui autoriza `channels.list` real: G0–G9 permanecem fail-closed; publish continua atrás de **P5-REPRO-01**.

### 11. Open decisions / bloqueios
- `OPEN-DC2-01` → **RESOLVIDO por esta review: fail-closed agora** (tombstone = aditivo futuro via tabela irmã, gated). Aguarda ratificação Product Lead como registro.
- `OPEN-DC2-03` (publishedAt), CHANNEL-05 (`rule_hash`) → **diferidos, não bloqueiam** (vivem em `raw_json`/`versions`).
- OQ-2 (papel de escrita) → recomendação Database registrada; **confirmação final conjunta com Security**.

---

## 7. AgentResult

> Envelope canônico de `packages/orchestrator/src/core/result-schema.ts` (`AgentResult`): campos `task_id`, `agent`, `status`, `summary`, `artifacts[]`, `errors[]`, `next_recommendation`. O Orchestrator consome **só** este shape — nada de prosa livre.
>
> **Reconciliação de ação:** a task delegada trouxe `action: review_schema`, que **não** está na allow-list do `database_agent` (`design_schema`, `plan_migration`, `define_rls_policy`, `change_db_schema`, `run_migration`). Mapeada fielmente para **`design_schema`** (review/plan-only, zero DDL) — a semântica exata desta entrega. `action` não é campo do `AgentResult` (vive no `TaskCommand`).

```json
{
  "task_id": "task_database_review_channel_data_collection",
  "agent": "database_agent",
  "status": "completed",
  "summary": "Review de Database (design-only, ZERO ALTER) da coleta gated de Channel Data concluída — gate G3. (1) ZERO-ALTER: DATA-COLLECT-002 §4.1 é byte-idêntico ao raw_youtube_channels aplicado (Fase 4 L128–140); coleta é INSERT-only sobre shape congelado; NULL≠0 estrutural. (2) Unicidade (run_id, channel_id) L142–143 + FK composta ON DELETE RESTRICT (channel_eligibility L237–239 → índice único L142–143, vigente) + imutabilidade abaixo do service_role, INSERT-only (triggers L165–170) + CHECK anti-segredo de topo como BACKSTOP (L138–139, não substitui o scrub body-only) + sem FORCE RLS (owner postgres insere; default-deny p/ anon/auth) → OQ-2 postgres/DB-password. (3) DC2-01 fail-closed IMPOSTO pelo schema: raw_json NOT NULL + FK RESTRICT tornam linha-fantasma e veredito órfão impossíveis; sem tombstone agora; tombstone futuro = tabela irmã aditiva, NUNCA ALTER no raw. (4) Slots aditivos OPP-04/OPP-05/CHANNEL-03 = DEFER na forma aditiva sem ALTER (chaves em metrics_detail_json/versions aceitas pelos validadores mínimo-fechado/máximo-aberto F5-05A/F5-06A, L108–188; reason permanece text storage-only). Nenhum defeito de integridade; nenhuma migração requerida; zero conexão, zero apply, zero secret.",
  "artifacts": [
    {
      "type": "review",
      "path": "docs/database/HANDOFF-channel-data-collection-review.md",
      "description": "Review de integridade + handoff (gate G3): ratifica ZERO-ALTER, FK composta/unicidade/imutabilidade/CHECK anti-segredo/append-only, DC2-01 fail-closed imposto pelo schema, e decisões dos slots aditivos (OPP-04/05, CHANNEL-03) na forma aditiva sem ALTER. Zero migration, zero conexão, zero secret."
    }
  ],
  "errors": [],
  "next_recommendation": {
    "target_agent": "security_agent",
    "action": "audit_secrets",
    "priority": "high",
    "reason": "Gate G3 (Database) verde. Rotear G2 Security (SEC-0019): confirmar OQ-2 (papel de escrita postgres/DB-password vs service_role) + ausência de FORCE RLS em raw_youtube_channels; ratificar SEC-F08 (CHECK anti-segredo é backstop de topo, não substitui o scrub body-only) + SEC-F23/PII pública em raw_json. Depois G4 DevOps define_pipeline. Nenhuma coleta real/apply/ALTER autorizados: G0–G9 permanecem fail-closed, publish atrás de P5-REPRO-01, Fase 9 vetada, 0007 parked. Aditivos (OPP-04/05, CHANNEL-03, CHANNEL-05, DC2-03) = design-only diferido, só materializam por migration ADITIVA+gated+nova versão."
  }
}
```
