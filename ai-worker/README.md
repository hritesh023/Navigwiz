# Acronous AI Worker

Cloudflare Worker for the Acronous AI subdomain (ai.acronous.com)

## Features

- **Dynamic Model Selection**: Smartly chooses between faster (gpt-4o-mini) and more capable (gpt-4o) models based on query complexity
- **Web Search Integration**: Real-time web search for up-to-date answers with source citations
- **Custom Image Editing**: Cut-and-replace image edits using LLM vision capabilities
- **Performance Optimization**: Simple queries get quick responses, complex queries get detailed answers
- **No Time Limits**: Continuous processing without hard time limits

## Route Endpoints

- `POST /v1/chat`: Chat with AI (default)
- `POST /v1/image/edit`: Edit images with cut-and-replace functionality
- `GET /health`: Health check endpoint

## Environment Variables

```env
ORACLE_LLM_URL: Self-hosted Ollama endpoint
ORACLE_LLM_MODEL: Ollama model name
ORACLE_LLM_KEY: Optional API key for the Ollama endpoint
SEARCH_ENABLED: Enable/disable web search (true/false)
```

## Deployment

Deploy to ai.acronous.com using Cloudflare Wrangler:

```bash
wrangler deploy
```

## Testing

```bash
npm test
```