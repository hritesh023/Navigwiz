import os
import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager

from app.config.settings import settings
from app.api.routes import router as api_router
from app.api.cf_routes import router as cf_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    os.makedirs("./data/uploads", exist_ok=True)
    os.makedirs(settings.chroma_db_path, exist_ok=True)
    os.makedirs(settings.faiss_index_path, exist_ok=True)
    os.makedirs(settings.memory_store_path, exist_ok=True)

    print(f"  {settings.app_name} v{settings.app_version}")
    print("  Memory: ChromaDB + FAISS")
    print(f"  LLM: {settings.openai_model if settings.openai_api_key else 'Ollama'}")
    print(f"  Embeddings: {settings.embedding_model}")

    yield

    from app.services.search import search_service, content_extractor
    from app.services.browser import browser_automation
    await search_service.close()
    await content_extractor.close()
    await browser_automation.close()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    import time
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {str(exc)}", "path": str(request.url)}
    )


app.include_router(api_router)
app.include_router(cf_router)


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info"
    )
