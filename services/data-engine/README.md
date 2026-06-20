# services/data-engine — NOXUND Data/AI Pipeline (Python)

**Status:** placeholder. Não scaffoldado ainda (sem dependências instaladas).
**Stack pretendida:** Python (script/worker; FastAPI só se virar serviço — Fase 2, OD-05).
**Owner agent:** Data/AI Pipeline Agent.

Este serviço **não** é um pnpm workspace. Tem seu próprio ambiente Python (`.venv`) e `.env`.

## O que viverá aqui (quando construído)

Os 6 agentes do pipeline (`03_Data_AI_Agents_Methodology.md` / arquitetura):

1. Search Agent — coleta ~500 vídeos (`chicago drill type beat`, 30d).
2. Video Data Agent — estatísticas por vídeo (raw imutável).
3. Entity Resolution Agent — regex + LLM assistida (único ponto de IA, blindado).
4. Channel Filter Agent — elegibilidade + canais distintos.
5. Popularity Scoring Agent — Score determinístico (rubric versionado).
6. Opportunity Agent — ranking, HOT, Competition, Example determinístico.

## Como será preparado (futuro, com revisão)

> Não rodar agora.

```bash
cd services/data-engine
python -m venv .venv
# ativar e instalar a partir de pyproject.toml/requirements (a definir pelo Data/AI Agent)
```

## Restrições inegociáveis (ver docs/agents/global-agent-rules.md)

- **IA nunca gera número.** Score/Velocity/Signals/Competition/ranking/Example = código determinístico.
- **Raw é imutável.** Recoleta = novo `run_id`. Nunca sobrescrever payload bruto.
- **Computed é reconstruível.** Mesmo snapshot + mesmo rubric ⇒ relatório idêntico.
- `YOUTUBE_API_KEY` e chave de LLM são server-side; nunca commitadas (ver `.env.example`).
