# Decision Log Template — NOXUND

Modelo para registrar decisões que alteram **escopo, stack, rubric, schema, posicionamento** ou qualquer non-negotiable.

Princípio: **se não está registrada, não aconteceu.** Decisões rejeitadas também são histórico.

Local de registro: `OPEN DECISION (OD-06)` — definir entre `docs/product/decisions/<id>.md` (um arquivo por decisão) ou um `DECISIONS.md` apendado. Até decidir, usar `docs/product/decisions/`.

Copie o bloco abaixo por decisão.

---

```md
## DEC-<NNN> — <título curto da decisão>

- **Data:** <YYYY-MM-DD>
- **Status:** Proposta | Aprovada | Rejeitada | Revertida | OPEN DECISION
- **Decisor:** <Product Lead / Product Orchestrator>
- **Área:** <Escopo / Stack / Rubric / Schema / Posicionamento / Segurança / Outro>
- **Prioridade/Impacto:** <Alto / Médio / Baixo>

### Contexto
<Qual situação ou conflito motivou a decisão. Citar documentos/§ de /context envolvidos.>

### Decisão
<O que foi decidido, em 1–3 frases objetivas.>

### Alternativas consideradas
- <Opção A> — <por que sim/não>
- <Opção B> — <por que sim/não>

### Justificativa
<Por que esta opção. Ligar à tese do MVP e aos non-negotiables.>

### Impacto
- **Escopo:** <muda? como?>
- **Non-negotiables:** <toca algum? como fica preservado?>
- **Documentos a atualizar:** <ex.: scope-guardrails.md, mvp-backlog.md, context-index.md>
- **Tarefas afetadas:** <IDs do backlog>

### Reversibilidade
<Fácil/difícil de reverter; condição que justificaria reverter.>

### Revisões necessárias
- [ ] Product Lead  [ ] Security  [ ] Data/AI  [ ] Database/Data Integrity  [ ] QA

### Follow-up
<Próximos passos; data de revisão se for condicional.>
```

---

## Decisões já travadas (referência — origem `/context`)

Estas **não são** entradas novas; resumem o que já está decidido em `00_Product_Lead_Decision_Log.md`. Servem como linha de base. Reabrir qualquer uma exige uma entrada `DEC-<NNN>` formal e o Product Lead.

| Ref | Decisão travada |
|---|---|
| LD-01 | MVP é o Hotspot Artists Report, **não** marketplace. |
| LD-02 | Posicionamento: "Market intelligence engine for producers". Proibido prometer previsão/IA mágica. |
| LD-03 | Vertical única: Chicago Drill, keyword `chicago drill type beat`, janela 30d, ~500 vídeos. |
| LD-04 | Acesso fechado, por convite e aprovação manual. |
| LD-05 | 2 relatórios fixos (10 artistas, 2 HOT cada); toggle honesto, sem "Re-Gen". |
| LD-06 | Sem query sob demanda no MVP (1/dia é política de Fase 2). |
| LD-07 | Score determinístico, versionado, calculado por código (rubric 40/25/20/15). |
| LD-08 | IA generativa nunca calcula/julga/exibe número; só assiste Entity Resolution com validação. |
| LD-09 | Sem data lake diário no MVP (apenas snapshots por rodada). |
| LD-10 | Sem exposure penalty no MVP. |
| LD-11 | Sem ML scoring no MVP. |
| LD-12 | Stack híbrida com cortes (Next.js+TS, Supabase, Python; Redis/Celery adiados). |
| LD-13 | Marketing founder-led, fechado, por convite; sem ads massivos / SEO aberto / AI hype. |
| LD-14 | Critérios de avanço para Fase 2 (N≥15, intenção≥30%, confirmação≥50%, WTP≥25%, open≥70%). |
