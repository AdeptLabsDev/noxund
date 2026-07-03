# SEC-0017 — Security & Privacy Review (review_rls) · entity_resolution_candidates (DEC-0014)

- **Task:** `task_entity_candidates_review_security_rls` · **Action:** `review_rls` · **Agent:** `security_agent`
- **Data:** 2026-06-28
- **SQL:** `supabase/migrations/20260620000006_entity_resolution_candidates.sql`
- **Verify:** `supabase/tests/entity_resolution_candidates_post_apply_verify.sql`
- **Rollback:** `supabase/rollback/20260620000006_entity_resolution_candidates.rollback.sql`
- **Handoff:** `docs/database/HANDOFF-entity-resolution-candidates-design.md`
- **Base:** SEC-0001 (SEC-F02/F03/F13 · veto §0 Fase 9) · SEC-F07 (least-privilege de leitura) · SEC-F09/F10 (PII/log) · padrão default-deny das Fases 1–5.
- **Mandato:** matrix #3 (migração; Database + Security) + gatilho RLS/roles. Gate de veto. Silêncio ≠ aprovação.
- **Status do alvo:** AUTORADO, NÃO APLICADO (design-only; banco intocado). `run_migration` segue em task gated separada.

---

## 0. Veredito

✅ **APROVADO — SEM BLOQUEIO.** Tabela **aditiva, mutável (staging/review queue)**, com a superfície de ataque mais simples até aqui: **zero trigger, zero `SECURITY DEFINER`, zero `jsonb` livre**. Default-deny efetivo (RLS-on + revoke, **zero policy/view**) → **Fase 9 NÃO destravada**. PII é **mínima** (nomes derivados de títulos públicos) e fica **server/admin-only** sob default-deny. **SEC-F08 é N/A** nesta camada (sem coluna jsonb que carregue envelope/secret). As 3 FK RESTRICT preservam proveniência **sem** abrir vetor de acesso. **Ratifico** o contrato write-layer ("nunca serializar secret/PII em `review_notes`") como **vinculante** para o `data_agent`.

Registro **2 condições não-bloqueantes de carry-forward** (SEC-F08 reabre se um dia houver coluna estruturada; `review_notes` é nota interna que **nunca** pode chegar ao produtor — Fase 9). Nenhuma corrige o DDL atual.

*(Veto da **Fase 9 — RLS Policies + VIEW pública** segue de pé, à parte, SEC-0001 §0. Esta autoria não o destrava.)*

---

## 1. Focus areas — veredito ponto a ponto

### default_deny → ✅
| Item | Veredito | Evidência |
|---|---|---|
| RLS ENABLE | ✅ | `alter table … enable row level security` (L118) — único `alter`, sobre a tabela **nova**. |
| `revoke all from anon, authenticated` (SEC-F02/F13) | ✅ | L123. |
| **Zero `create policy` executável** | ✅ | `grep` de `create policy` → **só comentário** (L29, L114); nenhuma policy executável. Verify §4 asserta `pg_policies = 0` (L186-187). |
| **Zero `create view`** | ✅ | nenhuma VIEW; só o comentário "ZERO view" (L29). |
| Fase 9 não destravada | ✅ | sem policy/VIEW → leitura/escrita seguem server/admin (service_role); produtor não alcança a fila. |
| Default-deny empírico | ✅ | verify §5: `anon`/`authenticated` → `insufficient_privilege` (L317-324). |

### pii → ✅ (mínima, server/admin-only; política pronunciada)
- `proposed_name` (span de título público) e `review_notes` (nota humana livre) são **TEXT** sob **default-deny** — **nenhum** papel de cliente (`anon`/`authenticated`) os lê nesta fase. Escrita/leitura = resolver + tela de revisão (server/admin).
- **Sensibilidade:** baixa — nomes de artista de **títulos públicos** do YouTube; **não** há email/identidade de produtor aqui (SEC-F09 trata de `applications`/`wtp_responses`, fora desta tabela).
- **Superfície de risco real = `review_notes`** (free-text humano): é onde um operador poderia, por engano, colar secret/PII. Endereçado pelo contrato write-layer (§3) + higiene de log SEC-F10 (não logar free-text/título).
- **Política pronunciada:** a fila é **ferramenta interna** (revisão da única zona de IA); **nenhuma** exposição ao produtor é contemplada. `review_notes` é comentário interno e **nunca** deve alcançar o produtor; se a Fase 9 algum dia expuser qualquer coisa derivada desta tabela, deve excluir `review_notes` (análogo SEC-F03). Carry-forward para a Fase 9 (sob veto).

### sec_f08 → ✅ N/A nesta camada (com gatilho de reabertura)
- A tabela **não tem coluna `jsonb`** (todas são uuid/text/enum/timestamptz) → **não existe** o vetor que SEC-F08 nomeia (envelope de request/key dumpado num payload). `grep` de `jsonb` → **só comentário** (L33). **SEC-F08 formalmente N/A aqui.**
- **Gatilho de reabertura (não-bloqueante):** se uma iteração futura introduzir coluna estruturada/`jsonb` (o handoff §6 cogita), **SEC-F08 reabre** e exigirá CHECK `no_request_context` (ou scrub equivalente) como nas tabelas raw. Registro para não se perder.

### write_layer_contract → ✅ RATIFICADO como vinculante
Ratifico — e torno **vinculante** para o `data_agent` (write-layer: resolver + tela de revisão):
1. **Nunca** serializar secret (YOUTUBE_API_KEY/qualquer credencial) em `review_notes`/`proposed_name` — alinhado a SEC-F23 (SEC-0016) e à regra global #6.
2. `review_notes`/`proposed_name` seguem **higiene de log SEC-F10**: não entram em log/Sentry (free-text/título proibidos).
3. `proposed_name` é **só** o span de nome (guardrail §3 da spec) — não um dump de título inteiro nem metadado extra.
**Validação esperada (pré-live, no job do resolver):** teste que comprove ausência de secret/PII-além-do-nome em `review_notes` (espelha o canary de SEC-0016 §8).

### provenance_restrict → ✅ (rastreabilidade sem vetor de acesso)
As 3 FK `ON DELETE RESTRICT` — `(run_id, video_id)→raw_youtube_videos` (L78-79), `run_id→report_runs` (L66), `artist_id→artists` (L69) — são **constraints referenciais**: preservam proveniência (candidato sempre rastreável ao raw; raw/run/artista referenciado não pode ser apagado) e **não concedem leitura** da tabela referenciada nem alteram RLS. **Nenhum vetor de acesso aberto.** Verify §5 prova: vídeo ausente/de outro run → `foreign_key_violation` (L209-221); DELETE de artista referenciado → bloqueado (L303-307); verify §4 confirma **todas** as FK RESTRICT.

---

## 2. Checagens independentes (minhas, além do escopo) — todas OK

- **Aditivo, não-destrutivo:** **zero `ALTER`** de tabela aplicada/congelada — o único `alter` é `enable row level security` na tabela nova (L118). Reusa o enum `video_artist_method` (Fase 5) sem recriar; rollback não o dropa. Confirmado.
- **Superfície simplificada:** **zero trigger**, **zero `SECURITY DEFINER`**, **zero função** → a superfície SEC-F15 que dominou a Fase 5 está **ausente**. `grep` de `security definer` → nenhum.
- **Mutável por design (honesto):** sem trigger de imutabilidade — correto para staging; o verify **prova a mutabilidade** (UPDATE pending→rejected aceito, L247-248) em vez de fingir freeze. A verdade congelada vive a jusante (`audit_events` + `metrics_detail_json.overrides[]`, F5-06A) — a mutabilidade da fila **não** enfraquece nenhuma garantia de snapshot.
- **Atômico:** `begin/commit` (L44/L125). Rollback declarado (tabela → enum novo), fora de `migrations/`, baixo risco.
- **Zero número / zero IA-gera-número:** fila de **nomes** (string), não de métricas; CHECKs são estruturais (prompt/decisão), nunca threshold. Sem superfície de cálculo embutida.
- **Zero secret; zero tabela de marketplace/Fase 2.** Confirmado.
- **service_role:** sem grant novo; revoke só de anon/authenticated — consistente com Fases 1–5.

---

## 3. Quadro de gates do `run_migration` (entity_resolution_candidates)

| Gate | Estado |
|---|---|
| Database — autor | ✅ (handoff) |
| **Security & Privacy `review_rls` (matrix #3 + RLS/roles)** | ✅ **APROVADO — este doc (SEC-0017)** |
| Data/AI — integridade da fila + coerência com replay (`audit_events`/`overrides[]`) | ⏳ próximo — **não é meu gate** |
| PR revisado + merge na `main` (sem push direto) | ⏳ |
| **Gate humano + required reviewers do `run_migration`** | ⏳ runtime — workflow dedicado, confirmação, `production-db`, dispatch de `main` (SEC-F18) |
| **SEC-F08** se introduzir coluna estruturada/jsonb | ⏳ carry-forward não-bloqueante (reabre o requisito) |
| `review_notes` em qualquer exposição futura | ⏳ carry-forward Fase 9 (excluir nota interna; análogo SEC-F03) |
| Fase 9 — RLS Policies + VIEW pública | ⛔ veto à parte (SEC-0001 §0) — não destravado aqui |

**Como meu gate ficou baixado:** default-deny efetivo + zero policy/VIEW; PII mínima e server/admin-only com contrato write-layer ratificado; SEC-F08 N/A (com gatilho de reabertura); FK RESTRICT sem vetor de acesso; superfície sem trigger/DEFINER. Nenhuma correção exigida. **Não aprovo apply** — `run_migration` segue gated (humano + `production-db` + dispatch de `main`/SEC-F18). Silêncio de Security ≠ aprovação; este doc é a liberação explícita.
