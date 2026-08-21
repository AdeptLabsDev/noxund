# Handoff Template — NOXUND

**Auxílio de formato. Não é um handoff, não é registro de decisão e não cria autoridade** (`DEC-0035` §9: *class* `DESCRIPTIVE-CURRENT`).

Modelo usado por **qualquer papel ou agente** ao devolver trabalho ao Product Orchestrator, e pela unidade ao se apresentar ao Product Lead. Sem retorno preenchido, a tarefa **não está concluída** (ver *Definition of Done* em `product-orchestrator-agent.md`).

Os significados são fixados por [`DEC-0040`](../product/decisions/DEC-0040-governed-result-disposition-closeout-contract.md). **Este arquivo aplica esse contrato; não o define e não pode alterá-lo.**

---

## Os seis eixos — nunca colapsar

```txt
EIXO A  EXECUTION STATE       completed | failed | needs_review | blocked      (transporte; nunca aceite)
EIXO B  EVIDENCE CLASS        REPORTED | VERIFIED | ACCEPTED | UNPROVEN        (por afirmação)
EIXO C  UNIT DISPOSITION      PASS | HOLD | RED                                (conduta da unidade)
EIXO D  ARTIFACT VERDICT      PASS | HOLD | RED | (omitido)                     (por função de revisão)
EIXO E  FINDING LIFECYCLE     OPEN | CLOSED — REMEDIATED                        (não reescreve RED histórico)
EIXO F  NEXT / AUTHORIZATION  NEXT CANDIDATE  ·  PRODUCT-LEAD GO                (instrumentos separados)
```

**Proibido:** `PASS-WITH-RED`, `RED-BUT-ACCEPTED`, `CONDITIONAL PASS` e qualquer token composto. Se dois eixos discordam, **declare os dois** (`DEC-0040` D1).

**Regra de omissão.** Item **sem referente na unidade é omitido** — não se preenche com `N/A`, não se enfeita, não se inventa. A omissão é informativa (`DEC-0040` D12).

---

## Parte 1 — `ROLE RESULT` · o que **um participante** devolve

> **`AUTHOR PASS = REPORTED, NOT ACCEPTED`.** O Author **não** emite disposição de unidade (Eixo C) nem veredicto de artefato (Eixo D). Se emitir, a declaração é nula (`DEC-0040` D11).

### Núcleo obrigatório

```md
# Role Result — <UNIT / TASK ID> · <título curto>

1. **Unit / task ID:** <id>
2. **Papel lógico:** <um dos sete de DEC-0037 D1; se task-scoped, dizer "TASK-SCOPED …" e NUNCA usar o nome de um agente registrado>
3. **Execution instance:** <identificador | UNKNOWN>
4. **Execution state (Eixo A):** <completed | failed | needs_review | blocked>
5. **Resumo:** <2–5 frases honestas; sem autocertificação>
6. **Mutation accounting (Eixo/Parte 3):** <ver Parte 3 — obrigatório para qualquer papel com write scope; papel read-only declara ZERO MUTATION E COMO SABE>
```

### Seções condicionais — incluir só quando houver referente

```md
7. **Technical principal:** <só quando load-bearing e efetivamente conhecido; caso contrário UNKNOWN — nunca inventar identidade (DEC-0039 D2)>
8. **Artefatos / efeitos:** <caminhos exatos do que foi produzido>
9. **Evidência produzida:** <cada afirmação load-bearing com sua classe do Eixo B>
10. **Findings / erros:** <inclusive qualquer breach reconhecido em si mesmo>
11. **Review target · REVIEW FUNCTIONS HELD · veredicto do papel (Eixo D):**
    <só para papéis de revisão; OMITIR para o Author.
     Listar as funções efetivamente exercidas — nunca inferir cobertura por número de participantes (DEC-0037 D5; DEC-0040 D9)>
12. **Next recommendation (Eixo F):** <recomendação; NUNCA autorização>
13. **Critério de aceite:** <cole o critério original + como verificar: comando / rota / passo>
14. **Validação executada:** <o que rodou e o RESULTADO REAL; auditoria/reprodutibilidade quando aplicável>
15. **Riscos:** <riscos introduzidos ou mitigados; referência a `07_Risks` quando aplicável>
```

**Se não conseguir cumprir um item obrigatório, diga por quê.** Silêncio sobre item obrigatório é, ele próprio, um finding.

---

## Parte 2 — `GOVERNED UNIT CLOSEOUT` · o que **a unidade** apresenta ao Product Lead

> **Um closeout é uma PROPOSTA DE RATIFICAÇÃO. Não ratifica nada.** Ratificação é o merge manual do Product Lead (`DEC-0037` D11; `DEC-0040` D18).

### Núcleo obrigatório — 14 itens

```md
# Governed Unit Closeout — <UNIT ID>

1.  **Unit ID:** <id>
2.  **Canonical base + autoridade:** <SHA de main + registros dos quais a unidade partiu>
3.  **Autorização do Product Lead + gate atual:** <o GO que autorizou esta unidade; o estágio atual>
4.  **Topologia efetivamente usada:** <a instanciada, não a exigida em abstrato>
5.  **Participantes e papéis:** <papel · instância · REVIEW FUNCTIONS HELD · tipo de independência
     — neste ambiente: `PROCESS-INDEPENDENT · PRINCIPAL-NOT-INDEPENDENT` (DEC-0039 D6)>
6.  **Unit governance disposition (Eixo C):** <PASS | HOLD | RED>
7.  **Artifact verdict(s) (Eixo D):** <por função de revisão; OMITIR se não há artefato>
8.  **Evidência / findings load-bearing:** <cada um com classe do Eixo B>
9.  **Governance findings + lifecycle (Eixo E):** <OPEN | CLOSED — REMEDIATED; OMITIR se não há>
10. **Mutation accounting:** <Parte 3 — nunca omitido>
11. **Unknowns / authority gaps restantes:** <inclusive todo UNKNOWN de identidade; OMITIR se não há>
12. **Estado de artefato / PR / landing:** <OMITIR se não aplicável>
13. **NEXT CANDIDATE recomendado (Eixo F):** <candidato — não é GO>
14. **NEXT exato:** <a próxima ação precisa, e por quem>
```

**Nunca omitir, faça a unidade o que fizer:** **1 · 2 · 3 · 6 · 10 · 14**. Os demais são omitidos quando não têm referente.

### Extensões específicas da unidade

O writ **pode** acrescentar campos exigidos pelo domínio (por exemplo: evidência de validação, estado de rollback, resultado de gate técnico). O writ **não pode** redefinir, renomear, fundir ou reordenar os eixos, nem exigir campo sem referente. **Não reinventar um contrato de retorno por unidade** (`DEC-0040` D12).

### Gates de escopo e revisão cruzada — condicional

Preencher quando a unidade toca escopo, número, banco, auth, segurança, produção, infra ou copy pública. **Não é ornamento:** `product-orchestrator-agent.md` §*Definition of Done* exige a determinação de revisão de domínio e aponta para este arquivo.

```md
## Impacto no escopo
- Mantém o MVP travado? <sim/não — se não, PARAR e escalar>
- Toca algum non-negotiable? <quais e como>
- Toca número / banco / auth / copy pública? <sim/não → revisão obrigatória abaixo>

## Revisões necessárias (gatilhos, não formalidade)
- [ ] Data/AI Review — tocou número, rubric, pipeline ou coleta
- [ ] Security Review — tocou auth, secrets, API keys, endpoints, RLS
- [ ] Database / Data Integrity Review — tocou schema, migrations, raw/computed
- [ ] QA Review — tocou fluxo crítico ou eventos
- [ ] Product Lead — há OPEN DECISION ou mudança de escopo
```

**A autoridade destes gatilhos é `agent-review-matrix.md` e `agent-boundaries.md`, não esta lista** — aqui ela é auxílio de preenchimento. Marcar a revisão **e** acioná-la; `HOLD` de domínio de veto bloqueia a unidade e **não há voto por maioria**. Uma função de revisão exigida é exercida, ou a unidade retorna `HOLD` + `AGENT-CAPABILITY-GAP` (`DEC-0037` D6).

---

## Parte 3 — Mutation accounting

> **`OUTSIDE REPOSITORY ≠ OUTSIDE write_scope`.**
> **`git status` limpo NÃO é prova de `ZERO MUTATION`** — fala apenas do conteúdo rastreado do repositório. **Toda alegação de `ZERO MUTATION` deve nomear as checagens que a sustentam.**

Superfícies a cobrir, sempre que a unidade puder alcançá-las: arquivos do repositório · branches · commits · pushes · PRs · refs, tags, worktrees, stash · temp/cache/sidecar/backup · `/tmp` e temp do sistema · scratchpad de sessão · **arquivos de memória de projeto ou sessão** · qualquer arquivo fora do repositório · sistemas mutáveis externos (configuração do GitHub, workflows, Environments, secrets, banco, nuvem).

```md
## Mutation accounting
- **AUTHORIZED MUTATION:** <caminho — o que mudou>            (dentro do write scope declarado)
- **UNAUTHORIZED MUTATION:** <caminho — o que mudou>          → UNIT RED (DEC-0040 D5)
- **HARNESS / SYSTEM PERSISTENCE OUTSIDE AGENT CONTROL:** <o quê, e por que era inevitável>
- **UNKNOWN MUTATION STATE:** <o que não pôde ser estabelecido>  → UNIT HOLD (DEC-0040 D4)
- **Checagens executadas:** <ex.: git status --porcelain · git status --ignored --porcelain · scratchpad inspecionado · nenhum arquivo de memória escrito>
```

**Limpeza nunca é autorização retroativa.** Apagar um artefato não autorizado é um **segundo** ato não autorizado: destrói a evidência do primeiro e **agrava o breach**. Ao reconhecer um breach: **parar a unidade · preservar evidência · não se auto-reparar · reportar completo** (`DEC-0040` D13; `product-orchestrator-agent.md` §*Governance breach*).

---

## Notas de uso

- **Honestidade obrigatória.** Teste que falhou, passo pulado ou evidência ausente entram no retorno. Evidência ausente é `HOLD`, nunca “provavelmente PASS”.
- **Um retorno por tarefa.** Tarefa grande se quebra antes, não se resume depois.
- **Revisões cruzadas são gatilhos, não formalidade:** marcar a revisão **e** acioná-la. `HOLD` de domínio de veto bloqueia a unidade; **não há voto por maioria**.
- **`NEXT` não é `GO`.** Nenhum campo de status autoriza o estágio seguinte (`DEC-0040` D8).
- **Nada aqui prova identidade.** Um retorno carrega papel alegado, principal conhecido e classificação de proveniência — nunca atestação. `HASHING IS NOT ATTESTATION` (`DEC-0038` §13; `DEC-0039` D9).
- O Orchestrator responde a cada retorno com **rotear / pedir revisão / escalar / parar** e registra decisões relevantes via `decision-log-template.md`. **Ele não aceita** (`DEC-0037` D10).
