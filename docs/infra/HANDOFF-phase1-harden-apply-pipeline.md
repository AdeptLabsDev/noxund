# Handoff — `task_phase1_devops_harden_apply_pipeline` · DevOps Agent

## 1. Identificação
- **Tarefa:** `task_phase1_devops_harden_apply_pipeline` · **Action:** `define_pipeline` (não-sensível)
- **Owner agent:** DevOps / Infra (`devops_agent`)
- **Data:** 2026-06-21
- **Prioridade:** P1 (high)
- **Branch:** `infra/phase1-credentialed-apply-env` (sobre `748cf6d`)
- **Origem:** `SEC-0005` ⛔ (DEC-0007 §2a NÃO satisfeita): 2 bloqueantes (SEC-F17, SEC-F18) + 2 condições (SEC-F19, SEC-F20).

## 2. Objetivo
Remediar os achados nomeados do SEC-0005 para **destravar o re-audit** `audit_secrets`, sem
aplicar nada e sem secret no repo. Fechar no PR o que o DevOps possui (SEC-F17, SEC-F19) e
**documentar com exigência de evidência** os itens out-of-band do Product Lead (SEC-F18,
SEC-F20).

## 3. Critério de aceite (do payload)
1. `actions/checkout` (L64, L110) e `supabase/setup-cli` (L67) por **commit SHA completo** + comentário de versão; **zero tag mutável** (SEC-F17).
2. `SUPABASE_SERVICE_ROLE_KEY` fora do CI; INFRA-0001 §2.1/§4.2 atualizadas; verificação pós-apply válida pela prova de banco (SEC-F19).
3. Runbook documenta SEC-F18 (branch rule `= main` **antes** de popular secrets) com **evidência exigida**.
4. Política de rotação + revogação de tokens de teste (SEC-F20) documentada antes do apply.
5. Handoff preenchido; PR pronto para re-auditoria `security_agent:audit_secrets`.

## 4. Resultado
- [x] **Critério 1 — SEC-F17 (fechado no PR).** 3 ocorrências SHA-pinadas:
  - `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4.3.1` (L64, L111)
  - `supabase/setup-cli@ab058987d8d6c725971f6cf9d0b5c98467e30bd1  # v1.7.1` (L67)
  - SHAs resolvidos das **release tags oficiais via API do GitHub** (não fabricados; cross-check: v4.2.2→`11bd719…` bate com o SHA público). Majors **mantidos** (v4/v1) — só pin, sem bump. **Zero tag mutável** (grep confirmado).
- [x] **Critério 2 — SEC-F19 (fechado no PR).** Passo "Complementary — service-key API negative check" **removido**; `secrets.SUPABASE_SERVICE_ROLE_KEY` **não é mais referenciada** no workflow (grep confirmado). INFRA-0001 §2.1 (tabela reduzida a 2 secrets + nota) e §4.2 (reescrita: prova autoritativa é de banco, key fora do CI) atualizadas. A verificação §4/§5 em banco permanece **intacta**.
- [x] **Critério 3 — SEC-F18 (documentado + evidência).** INFRA-0001 §3 reordenado (branch rule `= main` **antes** dos secrets) + **§7 pré-flight runbook** com tabela de evidência exigida. Inclui **alerta de sequência**: os secrets já foram populados → se a branch rule não estava ativa, tratar como exposição e **rotacionar** antes do 1º run.
- [x] **Critério 4 — SEC-F20 (documentado).** INFRA-0001 §5.2: gatilhos de rotação (pós-apply, troca de pessoal, periódica ≤90d), revogação imediata de tokens de teste pós-apply, access token escopado ao mínimo.
- [x] **Critério 5.** Este handoff + PR prontos para re-audit.

**Como verificar:**
`grep -nE 'uses:.*@(v[0-9]+|main|latest)' .github/workflows/phase1-db-apply.yml` → vazio ·
`grep -rn 'secrets.SUPABASE_SERVICE_ROLE_KEY' .github/` → vazio.

## 5. Arquivos alterados
- `.github/workflows/phase1-db-apply.yml` — **modificado**: SHA-pin (SEC-F17); remoção do passo de service-key (SEC-F19).
- `docs/infra/INFRA-0001-phase1-credentialed-env.md` — **modificado**: §2.1, §3, §4.2, §5 (remediações + rotação), §6, **§7 pré-flight runbook**.
- `.env.example` — **modificado**: pointer reflete que a service key é app-runtime only, fora do CI.
- `docs/infra/HANDOFF-phase1-configure-env.md` — **modificado**: banner de supersessão (evita instrução stale de popular a service key).

## 6. Impacto no escopo
- **MVP travado?** Sim. Hardening defensivo de CI; nada de Fase 2; nenhuma mudança de stack.
- **Non-negotiable?** Reforça #10 (secrets) e supply chain. **Nenhum apply**; nenhum secret em payload/repo/log.
- **Pontos fortes preservados:** `permissions: contents: read`, manual-only + frase `APPLY-PHASE1`, required reviewers, URL mascarada, apply atômico — todos intactos.

## 7. Validação executada
- **Estrutural:** grep — 3 `uses:` por SHA de 40 chars, **0** tags mutáveis; **0** `secrets.SUPABASE_SERVICE_ROLE_KEY` no CI.
- **Resolução de SHA:** via API pública do GitHub (`/repos/{owner}/{repo}/tags`); cross-check do v4.2.2 confirma que a API retorna commit SHA.
- **Apply:** **não executado** (constraint do payload).
- **Funcional do workflow:** roda no 1º dispatch pós-merge + Environment (downstream, gated).

## 8. Riscos
- **Sequência SEC-F18 (ativo):** secrets já populados antes de confirmar a branch rule → exposição potencial até a regra `= main` existir. Mitigação no §7: configurar a regra **agora** + **rotacionar** as duas credenciais antes do 1º run. **Requer ação + evidência do Product Lead.**
- **Drift de versão das actions:** SHA-pin congela versão; re-pinar conscientemente a cada bump (documentado em INFRA §5.1).
- **Merge:** continua proibido push direto na `main` (global rule #12) — PR + revisão.

## 9. Revisões necessárias
- [ ] ⏳ **Security — re-audit `audit_secrets`** sobre o PR atualizado (matrix #8): confirmar SEC-F17/F19 fechados no código e SEC-F18/F20 documentados com evidência. **Acionada** via `next_recommendation`.
- [x] **DevOps** — esta entrega (autor).
- **Pendências out-of-band (Product Lead, evidência → re-audit):** SEC-F18 (branch rule) + SEC-F20 (rotação) + remoção da service key do Environment (§7).

## 10. Próximos passos
1. **Product Lead (out-of-band, §7):** branch rule `= main`; remover `SUPABASE_SERVICE_ROLE_KEY` do Environment; rotacionar `SUPABASE_ACCESS_TOKEN`+`SUPABASE_DB_PASSWORD` (sequência SEC-F18); anexar evidência.
2. **Security (`audit_secrets`):** re-auditar → baixar o bloqueio do SEC-0005 §6.
3. **Merge do PR** (DEC-0007 §2b) via branch + revisão.
4. **Database (`run_migration`, gated):** dispara `phase1-db-apply.yml` → apply + verify §4/§5.

## 11. Open decisions / bloqueios
- **Bloqueio do merge/apply:** retido até o re-audit baixar SEC-0005. As mudanças in-PR (SEC-F17/F19) estão **prontas**; SEC-F18/F20 dependem de ação + evidência humana (alçada do Product Lead, por desenho).
- Gates sensíveis downstream (merge §2b, popular/escopar secrets, apply + required reviewers) **permanecem intactos**.
