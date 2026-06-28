# BE-0002 — Backend · Contrato de Consumo de `report_items` / `artist_metric_id` (Fase 5, pré-apply)

- **Owner:** Backend/Next API Agent (`docs/agents/backend-agent.md`) · id runtime `backend_agent`
- **Task:** `task_phase5_backend_api_contract` · **Action:** `create_api_contract` (não-sensível; sem apply, sem DDL, sem código de prod)
- **Data:** 2026-06-27
- **Prioridade:** high
- **Natureza:** **desenho de CONTRATO** sobre o snapshot e a proveniência. **Nenhuma** migration aplicada, **nenhuma** VIEW/RLS policy criada, **nenhum** endpoint público implementado, **nenhum** número gerado por código. A leitura do produtor é **DEFERIDA** à VIEW dedicada da **Fase 9 (sob veto SEC-0001 §0)**: este contrato **define o shape**, não destrava a Fase 9.
- **Fontes vinculantes:**
  - `supabase/migrations/20260620000005_phase5_computed_metrics_reports.sql` — `report_items` L367-414 · `artist_metrics` L259-294 · `artist_metric_videos` L304-321
  - `docs/database/HANDOFF-phase5-design.md` — §5 (cadeia referencial) · §10/§11 (revisões)
  - `docs/security/SEC-0014-phase5-computed-metrics-ddl-review.md` — SEC-F03 carry-forward (§3, §5)
  - `docs/security/SEC-0001-mvp-data-model-review.md` — **SEC-F03** (exposição por-coluna, L59)
  - `context/01_MVP_Scope_PRD.md` — §5 (colunas públicas) · §4.4 (regras de exibição)
  - **Precedente:** `docs/backend/BE-0001-consumability-authz-contract-review.md` §3.3 (compromisso SEC-F03) — este doc é a **instanciação concreta** daquele contrato agora que `report_items` existe no DDL.

---

## 0. Veredito

**O schema da Fase 5 suporta o contrato de consumo do produtor SEM expor nenhuma coluna interna.** A superfície do produtor é uma **projeção pura de 9 colunas já congeladas** em `report_items` — todas materializadas no publish pelo data-engine (owner do número). Nenhuma delas é `score_value`/`raw_score`/`final_score`/`metrics_detail_json`/`selection_reason_json`. Prova em §3.

**Distinção central (não-negociável):** as regras de exibição (`HOT` sse Score>90; `score_display` sse Score>83) são **formatação aplicada UMA VEZ no publish** sobre o número determinístico congelado, **persistida** como `tag`/`score_display` (texto/enum congelados). A leitura do produtor **nunca** lê `score_value` para decidir visibilidade — porque `score_value` permanece gravado mesmo quando `score_display` é null (Score≤83), e re-derivar o threshold no read-path **vazaria** o Score que o produto decidiu esconder (SEC-F03, SEC-0001 L59). Backend **não recalcula**; IA **não toca número**.

**A leitura do produtor é DEFERIDA à VIEW da Fase 9.** Este contrato fixa o **shape** que essa VIEW deverá projetar (§1) e o que ela **jamais** pode expor (§2). **Nenhuma** VIEW/RLS/grant é criada aqui — `report_items` segue RLS-on + default-deny + revoke (DDL L645-664). Backend **não destrava** a Fase 9.

**Rastreabilidade preservada** (§5): `artist_metric_id` → `artist_metrics` (mesmo run/artista/rubric, FK composta) → `artist_metric_videos` → `raw_youtube_videos`; `example_url` deriva de `example_video_id` validado contra o raw. É capacidade **server/admin**, fora da superfície do produtor.

**Zero expansão de escopo** (§8): sem marketplace/checkout/upload; sem endpoint público novo; sem API Node separada. Qualquer necessidade de VIEW/policy/coluna interna volta ao Orchestrator como Fase 9.

---

## 1. Superfície PÚBLICA do produtor — projeção exibível (shape do contrato)

Mapa **coluna congelada em `report_items` → campo público**. Todas as colunas abaixo são **frozen no publish** e lidas **verbatim** (projeção pura; zero transformação no read-path, zero join obrigatório a `artist_metrics`/`artists`). É exatamente este o conjunto que a **VIEW dedicada da Fase 9** deverá expor — e **nada além**.

| Campo público (DTO) | Coluna fonte (`report_items`) | Tipo | Regra de produto (PRD §5) | Origem do valor |
|---|---|---|---|---|
| `rank` | `rank` | int | ordenação 1..10 | congelado no publish |
| `title` | `title` | text | `"<Artista> Type Beat"` (§5.1) | congelado no publish (sem join a `artists` no read) |
| `tag` | `tag` | `'HOT' \| null` | `HOT` **sse** Score>90 (§5.2) | **formatação congelada** (§4) |
| `score_display` | `score_display` | `text \| null` | `"X/100"` **só se** Score>83 (§5.3) | **formatação congelada** (§4) |
| `signals` | `signals` | int | nº de vídeos válidos na janela (§5.4) | congelado no publish |
| `velocity_display` | `velocity_display` | text | `"X.Xk/day"`/`"XXX/day"` (§5.5) | **string já formatada**, congelada |
| `competition_level` | `competition_level` | `'Low'\|'Medium'\|'High'` | nível de competição (§5.6) | congelado no publish |
| `competition_channel_count` | `competition_channel_count` | int | canais distintos (§5.6) | congelado no publish |
| `example_url` | `example_url` | `text \| null` | link YouTube clicável (§5.7) | congelado; derivado de `example_video_id` validado contra raw (§5) |

**Notas de contrato:**
- **Projeção pura.** O read do produtor é `SELECT rank, title, tag, score_display, signals, velocity_display, competition_level, competition_channel_count, example_url` sobre a VIEW da Fase 9 — **nenhuma** outra coluna, **nenhum** cálculo, **nenhum** acesso a `artist_metrics`/raw em read-time. (Reafirma BE-0001 §1.2: "o handler do produtor nunca toca `report_items` base nem `artist_metrics`".)
- **`title` é congelado**, não derivado de `artists` no read — o publish materializa `"<Artista> Type Beat"` na coluna. Sem join obrigatório.
- **`velocity_display` é texto pronto** (`"1.2k/day"`), não um número a formatar — Backend não computa a mediana nem formata; só projeta.
- **`tag`/`score_display` podem ser `null`** legitimamente (Score≤90 / Score≤83): o `null` é a ausência de exibição, **sem carregar** o valor escondido (§3).
- **Ordenação por `rank`** (índice único `report_items_report_rank_uidx`, DDL L409). O read não recalcula ranking.

> **DTO público (shape estável do endpoint da Fase 9 — definido aqui, implementado lá):**
> ```ts
> // ReportItemPublic — projeção 1:1 da VIEW pública da Fase 9 (SEC-F03).
> // NENHUM campo deste shape deriva de score_value/raw_score/final_score/*_json.
> type ReportItemPublic = {
>   rank: number;
>   title: string;
>   tag: "HOT" | null;                                  // frozen; HOT sse Score>90
>   scoreDisplay: string | null;                        // frozen; "X/100" só se Score>83
>   signals: number;
>   velocityDisplay: string;                            // frozen; "X.Xk/day"
>   competitionLevel: "Low" | "Medium" | "High";
>   competitionChannelCount: number;
>   exampleUrl: string | null;                          // prova clicável
> };
> ```

---

## 2. Colunas INTERNAS — proibidas na superfície do produtor (SEC-F03)

Existem no schema (auditoria/proveniência), mas **nunca** chegam ao produtor: sem grant, sem VIEW que as projete, sem policy. São **admin/server-only**, sob authz (SEC-F01/F02) — §6.

| Coluna | Tabela | Por que é interna | Onde pode ser lida |
|---|---|---|---|
| `score_value` | `report_items` | número cru congelado; existe **mesmo quando `score_display` é null** (Score≤83) → vazá-lo quebra a regra de produto (SEC-0001 L59) | admin/server (`GET /admin/*`, `is_admin()`) |
| `selection_reason_json` | `report_items` | prova determinística crua (candidatos/top3/tiebreak/vídeos) — metodologia interna | admin/server |
| `raw_score`, `final_score` | `artist_metrics` | Score interno antes/depois de normalização | admin/server |
| `metrics_detail_json` | `artist_metrics` | evidência por-célula (componentes/pesos/inputs/overrides) | admin/server |
| `engagement_score`, `channel_diversity_score`, `velocity_median_per_day`, `channel_diversity_count` | `artist_metrics` | componentes crus do cálculo | admin/server |
| `artist_metric_id`, `run_id`, `rubric_version`, `rubric_hash`, `report_id`, `artist_id`, `id`, `example_video_id`, `created_at` | `report_items` | ponteiros de identidade/coerência/proveniência | server (traceability, §5) |

**RLS é por-linha, não por-coluna** (SEC-0001 L59): por isso a separação **não** se faz com policy sobre `report_items`, mas com **VIEW dedicada** que projeta só as 9 colunas de §1. Enquanto a VIEW não existe (Fase 9), `report_items` permanece **default-deny** — o produtor lê **zero** coluna.

---

## 3. Prova: a exibição NÃO depende de coluna crua

Três pilares fecham o requisito SEC-F03 ("a exibição do produtor não usa `score_value`/`raw_score`/`final_score`/`metrics_detail_json`/`selection_reason_json`"):

1. **Materialização no publish (uma vez, pelo owner do número).** A decisão de formatação — exibir `HOT`? exibir `score_display`? — é computada **no momento do publish** pelo data-engine (Data/AI, owner do cálculo) a partir do número determinístico, e **persistida** em `report_items.tag`/`score_display` como texto/enum **congelados** (DDL L377-378). Após `published`, o `report_items_snapshot_guard` (DDL L482-513) torna essas colunas imutáveis. IA não toca número; o publish só **formata** um número já congelado.

2. **Read = projeção pura.** O caminho do produtor projeta **somente** as 9 colunas de §1. Não há, em read-time, leitura de `score_value`/`raw_score`/`final_score`/`*_json`, nem recomputo, nem ida ao raw. O contrato proíbe `SELECT *` e proíbe join a `artist_metrics`/raw no read do produtor.

3. **Argumento anti-vazamento (o cerne do SEC-F03).** `score_value` permanece gravado **mesmo quando `score_display` é null** (Score≤83). Se o read-path lesse `score_value` para decidir a visibilidade, ele (a) exigiria grant sobre a coluna crua e (b) **re-derivaria o threshold escondido em código** — vazando, por inferência, o Score que o produto decidiu ocultar. Projetar as colunas **já formatadas e congeladas** (`tag`/`score_display`) elimina os dois vetores: quando a regra esconde, a coluna é simplesmente `null` e **não carrega informação** sobre o valor oculto.

> **Conclusão:** a superfície do produtor é função **apenas** de colunas públicas congeladas. Provado por construção: nenhum campo de §1 deriva de coluna de §2.

---

## 4. Regras de exibição = FORMATAÇÃO sobre número congelado

| Regra (PRD) | Natureza | Quem aplica | Quando | Onde fica |
|---|---|---|---|---|
| `tag = 'HOT'` sse Score>90 (§5.2) | formatação | data-engine (owner do número) | **no publish** | `report_items.tag` (frozen) |
| `score_display = "X/100"` sse Score>83 (§5.3) | formatação | data-engine | **no publish** | `report_items.score_display` (frozen) |
| `velocity_display = "X.Xk/day"` (§5.5) | formatação | data-engine | **no publish** | `report_items.velocity_display` (frozen) |

- **Backend não recalcula** Score/Velocity/Signals/Competition e **não** materializa essas strings — só **projeta** o que o publish congelou. (Não-negociável onboarding §8.1: "IA generativa nunca gera número"; ranking/Example/Score saem de código determinístico.)
- **Sem `Re-Gen`/fake realtime AI** (PRD §4.4): o botão de alternância usa a copy honesta **"Ver outro grupo de oportunidades"** — troca entre os 2 snapshots fixos (`report_switched`), **não** "gera" nada. (Copy pública é do Frontend; Backend não cria caminho que sugira processamento em tempo real.)
- **Owner da materialização:** o data-engine, no publish, é o único ponto que lê o número cru e escreve a formatação congelada. Backend e a VIEW da Fase 9 ficam **a jusante**, só lendo.

---

## 5. Rastreabilidade preservada (todo número rastreável até o raw)

A cadeia auditável é **referencial** (FKs do DDL), não lógica:

```
report_items.artist_metric_id
  └─(FK composta report_items_artist_metric_fk: id,run_id,artist_id,rubric_version,rubric_hash) DDL L394-396
     → artist_metrics                       (a métrica EXATA do snapshot — mesmo run/artista/rubric)
        └─(FK artist_metric_videos_metric_fk: artist_metric_id,run_id) DDL L311-312
           → artist_metric_videos           (inputs normalizados da métrica)
              └─(FK artist_metric_videos_raw_fk: run_id,video_id) DDL L314-315
                 → raw_youtube_videos        (raw imutável)

report_items.example_video_id
  └─(FK report_items_example_raw_fk: run_id,example_video_id) DDL L402-403
     → raw_youtube_videos                    (Example é vídeo-prova real do mesmo run)
```

**Contrato de rastreabilidade:**
- `artist_metric_id` é **ponteiro de proveniência server/admin**, **não** campo público. A FK composta garante que aponta a métrica **exata** (não "alguma métrica") — o snapshot é auto-coerente sem o backend recomputar nada.
- **`example_url` (público) deriva de `example_video_id`** que tem FK ao raw daquele run: o link clicável é prova de um vídeo real coletado, não inventado (PRD §5.7). O publish materializa `example_url` a partir do `example_video_id` validado; o read só projeta `example_url`.
- **Todo número exibido é rastreável até `raw_youtube_videos`** (não-negociável onboarding §8.10) — via `artist_metric_id` → `artist_metric_videos` → raw, capacidade exercida **server/admin/auditoria**, nunca no read do produtor.
- O **rebuild** apoia-se em `metrics_detail_json` (versões/overrides congelados) + raw imutável + rubric append-only (HANDOFF-phase5 §5) — também server-side.

---

## 6. Consumo ADMIN/INTERNO sob authz (não é a superfície do produtor)

Endpoints **admin/server** **podem** ler colunas internas — sob `is_admin()` em código (SEC-F01) e zero-grant a `anon`/`authenticated` (SEC-F02). Isto **não** é a superfície do produtor e **não** destrava RLS/VIEW pública. Reusa o contrato de BE-0001 §1.3:

| Rota (BE-0001 §1.3) | Lê interno? | Authz |
|---|---|---|
| `GET /admin/reports` | sim — `report_items` colunas completas (incl. `score_value`, `selection_reason_json`) | `is_admin()` |
| `GET /admin/metrics` | sim — pode ler `score_value`/`raw_score` para agregados | `is_admin()` |
| `POST /admin/reports/:id/publish` | escreve o freeze point (materializa `tag`/`score_display`/`example_url` via data-engine) | `is_admin()` |

- Acesso admin a coluna interna roda **abaixo do service_role**, server-side, **nunca** exposto a `NEXT_PUBLIC_*`/bundle.
- A capacidade de rastreabilidade de §5 (seguir `artist_metric_id` até o raw) é **admin/auditoria**, mesma fronteira.
- **Isto não é precedente para expor nada ao produtor** — a superfície do produtor continua sendo só §1, via VIEW da Fase 9.

---

## 7. Deferimento explícito à Fase 9 (sob veto) — Backend NÃO destrava

- A **leitura do produtor** depende da **VIEW pública dedicada da Fase 9** (SEC-F03), que está **sob veto SEC-0001 §0**. Este contrato **define o shape** dessa VIEW (§1 = exatamente as colunas a projetar; §2 = o que ela jamais projeta) mas **DEFERE a implementação**.
- **Nada criado nesta fase:** zero `CREATE VIEW`, zero `CREATE POLICY`, zero `GRANT`. `report_items` permanece RLS-on + default-deny + `revoke all from anon, authenticated` (DDL L645-664), confirmado por SEC-0014 §3.
- **Quando a Fase 9 abrir** (fora deste contrato): a VIEW projeta o DTO de §1; o read endpoint do produtor exige `authenticated` **E** `producers.status='approved'` **E** `report.status='published'` (BE-0001 §1.2); Security re-review com evidência levanta o veto. Backend implementa **só então**.
- **`selection_reason` sanitizado:** BE-0001 §3.3.4 previu um `selection_reason` público sanitizado. **Decisão deste contrato:** **fora do DTO público mínimo** (§1) — `selection_reason_json` é interno (§2); um shape público sanitizado, **se** desejado, é decisão de produto/Frontend/Security da Fase 9, não deste contrato. O MVP (PRD §5) não lista "reason" como coluna pública; o Example (`example_url`) já é a prova. Não expandir aqui.

---

## 8. Zero expansão de escopo

- **Sem** marketplace, checkout, pagamentos, upload, download (PRD §9). **Sem** API Node separada (backend-agent: forbidden). **Sem** query sob demanda / relatório em tempo real.
- **Sem** endpoint público novo fora do contrato; **sem** coluna interna exposta; **sem** RLS/VIEW.
- Qualquer necessidade de VIEW pública, policy, novo endpoint público ou exposição de coluna interna **é Fase 9 (sob veto)** e **volta ao Orchestrator** — não implementada aqui (Stop Condition do backend-agent; onboarding §8.4).
- **Achado, se houver:** se o schema **não** suportasse o contrato sem expor interno, o achado voltaria ao `database_agent`. **Não é o caso** — §3 prova que suporta.

---

## 9. Rastreabilidade documental (nota)

O backfill **DATA-AI-0007** (aprovação Data/AI que vivia só no `AgentResult`) segue **recomendado em paralelo** por Security/Data (SEC-0014 §5) — **não bloqueia** este contrato, que se apoia no DDL/verify concretos e no veredito SEC-0014 (106 linhas, no repo).

---

## 10. Critério de aceite (mapeado aos `success_criteria`)

- [x] **Contrato de consumo documentado, público vs interno**, provando que a exibição do produtor **não** usa `score_value`/`raw_score`/`final_score`/`metrics_detail_json`/`selection_reason_json` (§1, §2, §3 — SEC-F03).
- [x] **Leitura do produtor DEFERIDA à VIEW da Fase 9** (sob veto); **nenhuma** VIEW/RLS/grant criada; Backend não destrava a Fase 9 (§7).
- [x] **Rastreabilidade preservada** `artist_metric_id → artist_metrics → artist_metric_videos → raw`; regras de exibição (HOT>90, score>83) tratadas como **formatação sobre número congelado**, sem geração/recalculo por API ou IA (§4, §5).
- [x] **Zero expansão de escopo**; novo escopo retorna ao Orchestrator (§8).
- [x] **next_recommendation:** DevOps autora `phase5-db-apply.yml` → `security_agent:audit_secrets` (#8 delta) → `run_migration` gated (humano + required reviewers) por último; se o schema não suportasse o contrato sem expor interno, o achado voltaria ao `database_agent` (não é o caso — §3).

> **Não-negociável (CLAUDE.md / global-agent-rules):** segurança desde o primeiro commit. SEC-F03 entra no **desenho** do contrato — a superfície do produtor é, por construção, incapaz de vazar coluna interna. Número sempre determinístico, rastreável até o raw, nunca gerado por IA/API.
