---
title: Navigwiz Brain
emoji: 🧠
colorFrom: indigo
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
license: apache-2.0
---

# Navigwiz + Acronous AI Brain

The AI backend for Navigwiz browser. Runs FastAPI + ChromaDB + LangChain.

## Environment Secrets (set in Settings → Secrets)

| Secret | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | Yes | OpenAI or OpenRouter API key |
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Supabase anonymous key |
| `SUPABASE_SERVICE_KEY` | Yes | Supabase service role key |
| `JWT_SECRET` | Yes | Random 64+ char string |
| `REDIS_URL` | Yes | Upstash Redis connection URL |
| `CELERY_BROKER_URL` | Yes | Same as REDIS_URL |
| `CELERY_RESULT_BACKEND` | Yes | Same as REDIS_URL |
