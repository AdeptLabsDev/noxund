# 07 · Risks, Mitigations & Future Decisions

**Objetivo:** registrar riscos reais e impedir que o MVP escale prematuramente.

---

## 1. Riscos principais

| Risco | Severidade | Mitigação |
|---|---|---|
| Produtor percebe que o botão simula IA | Alta | Usar copy honesta: `Ver outro grupo de oportunidades`. |
| Score parece arbitrário | Alta | Rubric fixo, código determinístico, auditoria por componente. |
| Competition duplica Signals | Alta | Competition = canais distintos; Signals = vídeos válidos. |
| Example parece escolhido no olho | Alta | Regra determinística de seleção. |
| Amostra de produtores é pequena | Média/Alta | N < 15 é direcional; não tomar decisão final. |
| Intenção declarada infla resultado | Alta | Follow-up obrigatório em 10–14 dias. |
| WTP não é capturado | Média | Pergunta única pós-uso. |
| YouTube API falha ou limita quota | Média | Rate limiting, logs e coleta controlada. |
| IA alucina nome de artista | Alta | IA apenas assistida, validação por substring/normalização e revisão humana. |
| Time constrói marketplace cedo demais | Alta | Escopo explícito: marketplace fora do MVP. |

---

## 2. Riscos de produto

### 2.1 O relatório é interessante, mas não acionável
**Sinal:** produtores marcam útil, mas não marcam `vou produzir`.  
**Resposta:** revisar formato da oportunidade, artistas selecionados, Competition e copy da tabela.

### 2.2 O produtor declara intenção, mas não produz
**Sinal:** intenção ≥ 30%, follow-up baixo.  
**Resposta:** relatório gera curiosidade, mas não muda comportamento. Investigar por entrevista.

### 2.3 O produtor questiona metodologia
**Sinal:** dúvidas sobre Score, Example ou Competition.  
**Resposta:** usar auditoria interna para responder com evidência; melhorar tooltip se necessário.

### 2.4 O nicho escolhido está saturado ou fraco
**Sinal:** poucos artistas com Score > 83 ou Competition alta demais.  
**Resposta:** repetir validação em subgênero adjacente antes de abandonar a tese.

---

## 3. Riscos técnicos

### 3.1 Coleta inconsistente
**Mitigação:** cada coleta precisa ter `run_id`, janela temporal e payload bruto.

### 3.2 Fórmula muda sem versionamento
**Mitigação:** `rubric_versions` obrigatório.

### 3.3 Raw e computed misturados
**Mitigação:** separar tabelas brutas, mapeamentos e métricas derivadas.

### 3.4 Follow-up manual esquecido
**Mitigação:** tabela `followups` com `due_at` e job diário.

---

## 4. Riscos de marketing

### 4.1 Parecer SaaS genérico
**Mitigação:** DM via linguagem de cena, foco em Chicago Drill, prova de YouTube.

### 4.2 Parecer spam de artista querendo demo
**Mitigação:** deixar claro que não está pedindo nada, apenas testando relatório privado.

### 4.3 Atrair produtores errados
**Mitigação:** aprovação manual e rejeição de curiosos.

### 4.4 Prometer demais
**Mitigação:** banir copy de previsão, garantia e IA mágica.

---

## 5. Decisões futuras condicionadas

### 5.1 Query real 1/dia
**Só decidir depois de:** pipeline de geração funcionar ponta a ponta.  
**Critério:** validação do Hotspot passou e produtores pedem novos cortes.

### 5.2 Redis/Celery
**Só decidir depois de:** jobs recorrentes se tornarem gargalo.  
**Critério:** multi-keyword, multi-nicho ou geração sob demanda.

### 5.3 Plano pago
**Só decidir depois de:** WTP ≥ 25% e follow-up comprovar produção real.  
**Opções futuras:** assinatura semanal, créditos de relatório, beta pago fechado.

### 5.4 Marketplace curado
**Só decidir depois de:** base de produtores elite engajada.  
**Critério:** produtores enxergam NOXUND como ferramenta indispensável antes de trocar checkout.

### 5.5 Sub-perfis / beatmaker names
**Só decidir depois de:** produtores validados confirmarem dor real de múltiplos canais/nomes.  
**Observação:** é diferencial forte, mas não necessário para validar Hotspot.

### 5.6 Data lake
**Só decidir depois de:** necessidade real de tendência histórica.  
**Critério:** relatórios semanais/multi-nicho exigem comparação temporal.

### 5.7 ML scoring
**Só decidir depois de:** volume de producer_outcomes suficiente.  
**Requisito:** model_version + feature_snapshot_id.

---

## 6. Kill criteria

Encerrar ou reformular fortemente o MVP se:

- produtores aprovados não abrem o relatório;
- intenção declarada fica muito abaixo de 30%;
- follow-up real fica próximo de zero;
- produtores não entendem a tabela sem explicação longa;
- múltiplos produtores questionam credibilidade dos dados;
- WTP é nulo e uso real também é baixo.

---

## 7. Pivot options

Se a hipótese falhar, opções antes de abandonar NOXUND:

1. Trocar vertical para Jersey Drill/Jersey Club ou pluggnb.
2. Reduzir tabela e aumentar prova visual.
3. Transformar em relatório semanal editorial/manual.
4. Mirar produtores maiores com serviço concierge.
5. Mirar labels/A&Rs somente se produtores não responderem, mas dados forem úteis.

---

## 8. Regra final

Não escalar complexidade antes de provar comportamento.

A NOXUND só deve ganhar infra de marketplace quando tiver evidência de que produtores validados já confiam na inteligência da plataforma.

