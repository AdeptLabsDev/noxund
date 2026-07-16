## DEC-0021 — RO-1: mitigação do auto-pause do Supabase (free tier) — liveness+restore obrigatórios pré-execução; keep-alive automatizado REJEITADO; gatilho vinculante do upgrade Pro

- **Data:** 2026-07-16
- **Status:** **Registrada — decisão de Product Lead.** Resolve a OPEN DECISION **RO-1** (aberta em `SG-V7 §7`, deliberadamente não decidida naquele closeout). **Não** altera código, workflow, schema, marker, secrets, Environment, GCP nem o plano Supabase — o upgrade é fixado aqui como **gatilho futuro**, não executado.
- **Decisor:** Product Lead · registrada pelo Product Orchestrator
- **Área:** Operação de banco (Supabase) · disponibilidade para coletas/computes/SG-8 · postura de secrets e acesso fechado
- **Relaciona:** `docs/data/SG-V7-data-collect-001-first-collection-closeout.md §3.2/§7` (materialização do risco no run #2 + requisito de liveness pré-dispatch), `docs/data/SG-6-data-collect-002-channel-collection-closeout.md §7`, `SEC-0022` (postura: secrets exclusivamente no Environment gated por required reviewer)

### Contexto

Projetos Supabase free tier **auto-pausam após ~7 dias de inatividade**; o pause remove o DNS do projeto e o tenant do session pooler, derrubando no `connect()` qualquer operação futura que toque o banco (falha limpa, pré-criação, custo zero — mas falha). O risco **materializou-se** no run #2 do SG-V7 (`29444609139`, 2026-07-15): projeto pausado desde 2026-07-11, `ENOTFOUND` no pooler, zero raio de dano. O restore manual pelo Product Lead provou **dados intactos** e restabeleceu o serviço no mesmo dia. Desde então, o check de liveness é requisito vinculante das revalidações pré-dispatch de coleta (`SG-V7 §7`); faltava a decisão de **mitigação permanente**. Última atividade de banco: 2026-07-15 (coletas SG-V7/SG-6) → pause projetado ≈ 2026-07-22 na ausência de atividade.

### Decisão

**1. Mitigação vigente — liveness + restore manual OBRIGATÓRIOS antes de TODA execução que toque o banco.** Generaliza o requisito do `SG-V7 §7` — antes restrito às revalidações pré-dispatch de coleta — para **qualquer ato que toque o banco**: coletas, computes (Channel Filter / scoring / opportunity), rodadas do SG-8/P5-REPRO-01, applies e verificações credenciadas. Ritual em três partes:
- probe de DNS read-only (`<ref>.supabase.co`) por agente — sem credencial;
- verificação credenciada do Product Lead (`select 1` + presença das tabelas de contrato);
- **restore manual via dashboard se pausado** — ato exclusivo do Product Lead, dentro da própria alçada (precedente: correção do run #2).

**2. Keep-alive automatizado — REJEITADO.** Alternativas avaliadas e descartadas:
- **cron (GitHub Actions) com `select 1` credenciado:** exigiria secret de banco disponível a job **não-assistido** — regressão material de postura (hoje os secrets vivem exclusivamente no Environment `youtube-collection`, gated por required reviewer, que um cron não pode satisfazer) + nova rota de egress com ciclo completo de audit;
- **pinger externo em endpoint do projeto:** conflita com a postura de acesso fechado do MVP e adiciona dependência de serviço externo;
- **isenção nativa de pause no free tier:** não existe — a isenção **é** o plano pago.
Comum a todas: keep-alive que falha silenciosamente gera falsa confiança, e o esforço de revisão de segurança preservaria um plano que o produto abandonará de qualquer forma.

**3. Upgrade Pro — OBRIGATÓRIO antes da primeira operação NÃO ASSISTIDA ou USER-FACING; no máximo, antes do PRIMEIRO PUBLISH.** O gatilho **não** é a mera entrada no SG-8: enquanto toda operação for assistida (humano no loop cumprindo o ritual do item 1), free tier + liveness bastam. Tornam o upgrade obrigatório, **o que ocorrer primeiro**:
- a primeira operação **não assistida** — qualquer automação que toque o banco sem humano no loop;
- a primeira superfície **user-facing** — qualquer operação servida a produtor;
- o **primeiro publish** — deadline absoluto.
Ao disparar o gatilho, o upgrade precede a operação; verificar pricing vigente no ato. O upgrade em si será ato do Product Lead na plataforma, fora do repo.

### O que esta DEC NÃO autoriza

Upgrade agora, mudança de plano, automação de qualquer natureza, compute-live, entity-resolution, Channel Filter, scoring, SG-8, publish, merge de qualquer PR — cada um permanece atrás de ordem própria e explícita do Product Lead.

### Reversibilidade

Alta. Itens 1–2 são processo, revogáveis por nova DEC sem tocar código, schema ou dados. O item 3 é gatilho de decisão futura; nenhuma cobrança, configuração ou mudança de plataforma decorre deste registro.
