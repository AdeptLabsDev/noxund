# SEC-0023 · SG-V2 — Structured Result (machine-consumable companion)

**Propósito:** payload **estruturado e consumível** da revisão de Security SG-V2 (`SEC-0023-sg-v2-data-collect-001-video-collection-review.md`). O `AgentResult` (envelope canônico de `@noxund/orchestrator`) referencia **este** arquivo em `artifacts[]`; a revisão em prosa é para humano, este é para consumo.

**Contrato de consumo:** o bloco `json` único abaixo é a **fonte estruturada**. Chaves e ids são **estáveis**; a ordem é fixa. Todo item rastreável à revisão SEC-0023 e às fontes vinculantes (spec §§, DEC-0018, SEC-0012/0016/0019/0021/0022). **Zero valor de secret** (só nomes). Este arquivo **não** autoriza coleta/dispatch/arm/provisionamento.

```json
{
  "schema": "noxund.security.structured_result/v1",
  "review": {
    "id": "SEC-0023",
    "gate": "SG-V2",
    "track": "DATA-COLLECT-001 (video: search.list -> raw_youtube_search_pages; videos.list -> raw_youtube_videos)",
    "agent": "security_agent",
    "action": "audit_secrets",
    "date": "2026-07-05",
    "mandate": "REVIEW/DESIGN-ONLY. Poder de veto. Silencio != aprovacao. Nao autoriza execucao.",
    "status": "completed",
    "human_review_doc": "docs/security/SEC-0023-sg-v2-data-collect-001-video-collection-review.md"
  },
  "verdict": {
    "sg_v2": "GO",
    "layer": "desenho de dado/secret/quota liberado; nenhum defeito de desenho",
    "authorizes": [
      "avancar SG-V3 (Database) em revisao/design",
      "avancar SG-V4/SG-V5 (collector inerte/offline + testes §8 + verify §7) em paralelo, zero egress"
    ],
    "does_not_authorize": [
      "coleta real (search.list/videos.list)",
      "dispatch",
      "arm (.armed)",
      "provisionamento de Environment/secret/GCP",
      "qualquer ALTER/migration"
    ]
  },
  "controls": [
    { "id": "SV2-01", "control": "SEC-F23 body de video (title/stats/raw_json): publico, minimizado a part=statistics,snippet, default-deny, NULL!=0", "source": "spec §4; SEC-0016 §1", "state": "ratificado" },
    { "id": "SV2-02", "control": "SEC-F08 anti-envelope: CHECK top-level JA VIVO nos 2 raws (Fase 4) + scrub body-only autoritativo", "source": "schema Fase 4; SEC-0012", "state": "ratificado" },
    { "id": "SV2-03", "control": "Scrub body-only autoritativo no coletor (envelope/URL/headers/key nunca persistidos)", "source": "spec §3.3/§4.3/§8", "state": "desenho_ok", "proof": "teste §8.1 (SG-V5)" },
    { "id": "SV2-04", "control": "YOUTUBE_API_KEY server-only, todos os canais fechados; header X-Goog-Api-Key", "source": "spec §8; SEC-0016 §2", "state": "aprovado" },
    { "id": "SV2-05", "control": "pageToken proibido em log/Sentry (+ title, query-URL, body, IDs em massa)", "source": "spec §8", "state": "desenho_ok", "proof": "canary §8.3 (SG-V5) + Sentry-scrub (SG-V6)" },
    { "id": "SV2-06", "control": "Higiene de log: API key / DB password / connection string / query URL / raw_json / title / payload body negados", "source": "spec §8; SEC-0016 §3", "state": "ratificado" },
    { "id": "SV2-07", "control": "Environment least-privilege: sem SUPABASE_ACCESS_TOKEN, sem service-role, main-only (SEC-F18)", "source": "SEC-0022 §1", "state": "herdado" },
    { "id": "SV2-08", "control": "OD-V1 (reuso vs dedicado)", "source": "handoff G7", "state": "recomendacao_emitida", "ref": "open_decisions[OD-V1]" },
    { "id": "SV2-09", "control": "F-1' (cap por-run + retry budget + alerta re-calibrado + API-restriction re-confirmada)", "source": "handoff G6/R1", "state": "condicao_de_gate", "ref": "findings[F-1']" },
    { "id": "SV2-10", "control": "Path novo de STATE em report_runs nao abre secret/grant novo; atomicidade e gate da Database", "source": "spec §2/§6", "state": "sem_superficie_nova", "delegates_to": "database_agent (SG-V3)" },
    { "id": "SV2-11", "control": "F-2' (audit_secrets SEPARADO do YAML de video; nao herda este doc)", "source": "DEC-0018 F-2", "state": "gate_futuro", "ref": "findings[F-2']" },
    { "id": "SV2-12", "control": "Fail-closed sem vazamento de estado parcial (run parcial != snapshot elegivel)", "source": "spec §6/§7", "state": "confirmado" }
  ],
  "findings": [
    {
      "id": "F-1'",
      "severity": "medium",
      "gate": "SG-V6/configure_env + SG-V7/dispatch",
      "blocking_for": "1st real video run",
      "not_blocking": "design (SG-V2/SG-V3/SG-V4/SG-V5)",
      "issue": "search.list custa 100 unid/chamada => ~1010 unid/run (~100x o caminho de canal de ~10 unid). Retry storm ou re-dispatch pode estourar a quota diaria de 10k no meio da run e, com key compartilhada, inanir o 002. O alerta de quota vigente foi calibrado para o perfil de ~10 unid do canal (SEC-0022).",
      "required_mitigation": [
        "cap de quota por-run (hard, recomendo ~2000 unid) com fail-closed se projetar ultrapassar",
        "retry <=2/chamada em classe transitoria (5xx/rede/429-com-backoff)",
        "quotaExceeded/dailyLimitExceeded = TERMINAL, NUNCA retentado",
        "surplus de retry por-run <=~500 unid",
        "alerta per-run >~1500 unid + alertas GCP diarios 50%/80% de 10k RE-CONFIRMADOS para o perfil ~1010",
        "API-restriction da MESMA key (YouTube Data API v3) re-confirmada; sem key nova",
        "concurrency proprio (cancel-in-progress:false) + avaliar gate quota-aware 001<->002"
      ],
      "thresholds_owner": "OD-V2 (numeros exatos = Product Lead)"
    },
    {
      "id": "F-2'",
      "severity": "medium",
      "gate": "SG-V6/define_pipeline",
      "blocking_for": "1st real video run",
      "not_blocking": "design",
      "issue": "O workflow de video e arquivo NOVO com semantica de CRIACAO de run (gera UUID, escreve report_runs, SEM run_id de input) e egress mais pesado (search.list). Diverge do template e do YAML do 002.",
      "required_mitigation": [
        "audit_secrets de Security SEPARADO do YAML de video (matrix #8, desvio de template)",
        "SHA-pin SEC-F17",
        "permissions: contents: read",
        "SEC-F18 main-only antes dos secrets",
        "required reviewers",
        "service-role NAO usada (SEC-F19)",
        "URL mascarada; header X-Goog-Api-Key",
        "arm marker + frase de confirmacao proprios"
      ],
      "inheritance": "NAO herda SEC-0016 nem SEC-0023"
    }
  ],
  "open_decisions": [
    {
      "id": "OD-V1",
      "owner": "Security + DevOps",
      "escalate_to": "Product Lead",
      "question": "Environment reutilizado (youtube-collection) vs dedicado para o estagio de video",
      "recommendation": "REUTILIZAR o Environment youtube-collection (least-privilege, ja co-assinado em SEC-0022) + workflow de video SEPARADO (arm marker/frase/SHA-pins/F-2' proprios). NAO provisionar 2o Environment.",
      "rationale": [
        "A YOUTUBE_API_KEY e a MESMA (mesmo projeto Google) => 2o Environment so DUPLICA a key portadora de custo (mais copias p/ vazar/rotacionar), nao reduz blast-radius",
        "A postura ja provisionada (sem ACCESS_TOKEN/service-role, main-only, DB least-privilege) e exatamente a que o video precisa; herdar > re-derivar (evita drift)",
        "Isolamento que importa (gatilho, arm, criacao-de-run, audit_secrets) vive no WORKFLOW, nao no Environment",
        "Reviewer unico AdeptLabsDev (sem teams): 2o Environment nao cria separacao de deveres real"
      ],
      "caveat": "Reuso => key/quota compartilhada com 002; risco endereçado por F-1' (OD-V2), nao por Environment dedicado",
      "state": "recommendation-issued"
    },
    {
      "id": "OD-V2",
      "owner": "Security (F-1') + DevOps (configure_env)",
      "escalate_to": "Product Lead",
      "question": "Quota cap por-run + retry budget + threshold do F-1' para ~1010 unid/run",
      "recommendation": "Floors: cap por-run ~2000 unid (fail-closed); retry <=2/chamada (quota* TERMINAL; surplus <=~500 unid/run); alerta per-run >~1500 unid + alertas GCP 50%/80% de 10k re-confirmados para ~1010; API-restriction re-confirmada.",
      "nature": "floors/postura de Security; numeros finais = decisao do Product Lead",
      "state": "recommendation-issued"
    }
  ],
  "quota_model": {
    "search_list": { "unit_cost": 100, "calls_nominal": 10, "subtotal": 1000, "note": "part=snippet, maxResults=50, ~10 paginas (500/50)" },
    "videos_list": { "unit_cost": 1, "calls_nominal": 10, "subtotal": 10, "note": "part=statistics,snippet, lotes de 50" },
    "nominal_total_per_run": 1010,
    "daily_default_quota": 10000,
    "nominal_share_of_daily": "~10%",
    "vs_channel_002": "~100x mais pesado por pagina (canal = ~10 unid/run)",
    "recommended_controls": {
      "per_run_hard_cap_units": 2000,
      "per_call_transient_retries_max": 2,
      "quota_error_retry": "never (terminal fail-closed)",
      "per_run_retry_surplus_max_units": 500,
      "per_run_alert_threshold_units": 1500,
      "gcp_daily_alerts_pct": [50, 80],
      "api_restriction": "YouTube Data API v3 (same key, re-confirm)",
      "ip_restriction": "N/A (GitHub runners sem IP estatico) — residual aceito, compensado por API-restriction + alerta + rotacao"
    }
  },
  "f1_prime_checklist": [
    { "id": "F1'-a", "condition": "Cap de quota por-run (~2000) imposto; ultrapassagem projetada => fail-closed", "owner": "Data/AI + DevOps", "verification": "repo (codigo/YAML)", "state": "pending", "gate": "SG-V5/V6" },
    { "id": "F1'-b", "condition": "Retry <=2/chamada em classe transitoria; quota* TERMINAL; surplus <=~500 unid/run", "owner": "Data/AI", "verification": "repo + teste §8.4", "state": "pending", "gate": "SG-V5" },
    { "id": "F1'-c", "condition": "Alerta per-run (>~1500) + alertas GCP diarios (50%/80% de 10k) RE-CONFIRMADOS para ~1010", "owner": "DevOps + Security (co-sign)", "verification": "atestacao out-of-band", "state": "pending", "gate": "SG-V6" },
    { "id": "F1'-d", "condition": "API-restriction da MESMA key = YouTube Data API v3 re-confirmada; sem key nova; rotacao (<=90d/pos-run/pessoal/leak)", "owner": "Security (atesta)", "verification": "atestacao out-of-band", "state": "pending", "gate": "SG-V6" },
    { "id": "F1'-e", "condition": "Concurrency proprio (cancel-in-progress:false) + avaliar gate quota-aware 001<->002", "owner": "DevOps", "verification": "repo (YAML)", "state": "pending", "gate": "SG-V6" },
    { "id": "F1'-f", "condition": "Sentry-scrub desligado/redatado (URL/params/breadcrumbs) p/ canary §8.3 fechar", "owner": "DevOps + Security", "verification": "atestacao + teste", "state": "pending", "gate": "SG-V6" },
    { "id": "F1'-g", "condition": "F-2' audit_secrets SEPARADO do YAML de video (SHA-pin/contents:read/SEC-F18/header/service-role nao usada)", "owner": "Security (bloqueante)", "verification": "repo (YAML)", "state": "pending", "gate": "SG-V6" }
  ],
  "residual_risks": [
    { "id": "RR-1", "risk": "Key/quota compartilhada com 002 (inevitavel: mesmo projeto Google); retry storm de 001 pode inanir 002", "severity": "medium", "mitigation": "Environment dedicado NAO corrige (quota e do projeto); corrigido por F-1' cap+alerta project-aware + concurrency" },
    { "id": "RR-2", "risk": "IP-restriction N/A (runners GitHub sem IP estatico)", "severity": "low", "mitigation": "Carry-forward aceito (SEC-0021 §4); compensado por API-restriction + alerta + rotacao" },
    { "id": "RR-3", "risk": "Texto livre em title/description pode conter secret colado/PII de 3o; raw_json verbatim/imutavel nao scrubavel", "severity": "low", "mitigation": "Aceito v1; contido por 4 camadas (publico/default-deny/nunca exposto/Fase 9 VETADA); re-review se raw exposto" },
    { "id": "RR-4", "risk": "Sentry default captura URL/params/breadcrumbs (pode vazar pageToken/query-URL)", "severity": "medium", "mitigation": "Scrubber desligado/redatado + canary §8.3 (F1'-f)" },
    { "id": "RR-5", "risk": "Reviewer unico AdeptLabsDev encarna DevOps+Security (sem teams)", "severity": "low", "mitigation": "Separacao por papel/agente; gate humano multi-fator re-aplicado a cada collect/verify (SEC-0022 §4)" },
    { "id": "RR-6", "risk": "Re-dispatch/duplicacao sob falha parcial re-consome quota pesada", "severity": "medium", "mitigation": "Idempotencia §5 (indices unicos vivos) + retomada reusa raw; teste §8.5; cap F-1' limita custo por tentativa" },
    { "id": "RR-7", "risk": "configure_env = ato sensivel/humano; provisionamento errado do cap/alerta anula F-1'", "severity": "medium", "mitigation": "Co-sign de Security no configure_env (SG-V6), evidencia out-of-band" }
  ],
  "gate_state": {
    "sg_v_track": [
      { "gate": "SG-V0", "state": "green", "note": "substrato DB aplicado (Fase 3/4), zero migration nova; spec v1 completa" },
      { "gate": "SG-V1", "state": "green", "note": "Product ratification merged (docs/data/SG-V1-...)" },
      { "gate": "SG-V2", "state": "green", "note": "ESTE doc — Security audit_secrets GO (design)" },
      { "gate": "SG-V3", "state": "pending", "note": "Database re-ratifica ZERO ALTER + atomicidade da finalizacao (confirmacao, nao migration)" },
      { "gate": "SG-V4", "state": "pending", "note": "collector Agente 1+2 inerte/offline" },
      { "gate": "SG-V5", "state": "pending", "note": "5 testes §8 + verify §7 (SQL)" },
      { "gate": "SG-V6", "state": "pending", "note": "workflow de video disarmed + F-2' + configure_env com F-1'" },
      { "gate": "SG-V7", "state": "no-go-now", "note": "dispatch humano (fronteira humana) => run_id §7-passed" },
      { "gate": "SG-V8", "state": "downstream", "note": "run_id vira input do SG-6 do 002" },
      { "gate": "SG-8", "state": "pre-publish", "note": "P5-REPRO-01 bloqueante antes do 1o publish" }
    ],
    "sg6_002": "NO-GO (inalterado) — sem run_id de video congelado e §7-passed",
    "pipeline_002_youtube_collection": "ARMADO e OCIOSO (.armed em main, TOTAL_RUNS=0) — intocado",
    "standing_vetos": ["Fase 9 / RLS Policies VETADA", "0007/producer_events PARKED", "publish barrado ate P5-REPRO-01 (SG-8)"]
  },
  "inherited_precedents": [
    { "id": "SEC-0016", "what": "audit_secrets do spec 001: SEC-F23 fechado no desenho (body-only, key, log hygiene)" },
    { "id": "SEC-0012", "what": "CHECK SEC-F08 no schema Fase 4 — JA VIVO/aplicado" },
    { "id": "SEC-0019", "what": "F-1/F-2 do 002 (template de finding)" },
    { "id": "SEC-0021", "what": "co-sign com condicoes C1-C5 do Environment youtube-collection" },
    { "id": "SEC-0022", "what": "F-1 fechado por atestacao + Environment provisionado (ESCOPADO ao caminho ~10 unid do canal)" }
  ],
  "safe_next_steps": [
    "1. Product Orchestrator registra SG-V2 GO no decision log e escala OD-V1/OD-V2 ao Product Lead",
    "2. Abrir SG-V3 (Database: zero-ALTER + atomicidade da finalizacao)",
    "3. SG-V4/SG-V5 (collector inerte/offline + testes §8 + verify §7) em paralelo, zero egress",
    "4. SG-V6 (workflow disarmed + F-2' + configure_env com F-1')",
    "5. SG-V7 dispatch humano (NO-GO agora)",
    "6. SG-8/P5-REPRO-01 antes de qualquer publish"
  ],
  "governance": {
    "action_in_allow_list": true,
    "action": "audit_secrets (+ threat_model implicito de topologia de Environment; matrix #8)",
    "needs_review": false,
    "reviewer_note": "AdeptLabsDev encarna DevOps+Security (sem teams) — separacao por papel/agente, NOTE nao-bloqueante (SEC-0022 §4)"
  },
  "constraints_honored": {
    "docs_only": true,
    "zero_secret_values": true,
    "untouched": [
      ".github/workflows/youtube-collection.yml",
      ".github/collection/youtube-collection.armed",
      "services/data-engine/*",
      "supabase/migrations/* (zero ALTER)",
      "supabase/tests/*",
      "20260620000007_phase6_producer_events.* (PARKED)"
    ],
    "nothing": ["collect", "dispatch", "arm", "provision", "commit/push/PR", "toque em GCP/Supabase/secrets"]
  }
}
```
