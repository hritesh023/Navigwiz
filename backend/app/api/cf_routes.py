from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Request
import os, uuid, base64, tempfile, re, json
from app.services.search import search_service
from app.services.audio import audio_service
from app.config.settings import settings

router = APIRouter()

ORACLE_LLM_URL = os.getenv("ORACLE_LLM_URL", "https://oracle.acronous.com")
ORACLE_LLM_MODEL = os.getenv("ORACLE_LLM_MODEL", "qwen2.5:1.5b")
ORACLE_LLM_KEY = os.getenv("ORACLE_LLM_KEY", "")


async def _call_llm(messages: list, model: str = ORACLE_LLM_MODEL, stream: bool = False):
    body = {
        "model": model,
        "messages": messages,
        "max_tokens": 4096,
        "temperature": 0.7,
    }
    if stream:
        body["stream"] = True
    import httpx
    headers = {
        "Authorization": f"Bearer {ORACLE_LLM_KEY}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(
            f"{ORACLE_LLM_URL}/v1/chat/completions",
            json=body,
            headers=headers,
        )
        if not resp.is_success:
            raise HTTPException(502, f"LLM error: {resp.status_code}")
        return resp.json()


def _sanitize(text: str) -> str:
    return re.sub(r'\n{3,}', '\n\n', text or '').strip()


# ── Health ─────────────────────────────────────────────────────────────

@router.get("/v1/health")
async def v1_health():
    return {"status": "ok"}


@router.get("/v1/ready")
async def v1_ready():
    return {"status": "ok"}


@router.get("/v1/health/llm")
async def v1_health_llm():
    return {"status": "ok"}


@router.get("/v1/wakeup")
async def v1_wakeup():
    return {"status": "ok"}


@router.get("/health")
async def health():
    return {"status": "ok"}


# ── Chat (CF-compatible) ──────────────────────────────────────────────

@router.post("/v1/chat")
async def v1_chat(request: Request):
    body = await request.json()
    message = body.get("message", "")
    session_id = body.get("session_id", "default")
    if not message:
        return {"response": "", "session_id": session_id, "type": "error"}

    messages = [
        {"role": "system", "content": "You are Navigwiz AI assistant. Provide accurate, helpful responses."},
        {"role": "user", "content": message},
    ]
    data = await _call_llm(messages)
    content = _sanitize(data["choices"][0]["message"]["content"])
    return {"response": content, "session_id": session_id, "type": "chat"}


@router.post("/v1/chat/stream")
async def v1_chat_stream(request: Request):
    body = await request.json()
    message = body.get("message", "")
    session_id = body.get("session_id", "default")
    if not message:
        from fastapi.responses import JSONResponse
        return JSONResponse({"error": "No message provided"}, status_code=400)

    messages = [
        {"role": "system", "content": "You are Acronous AI assistant."},
        {"role": "user", "content": message},
    ]

    async def event_stream():
        import httpx
        llm_body = {
            "model": ORACLE_LLM_MODEL,
            "messages": messages,
            "max_tokens": 4096,
            "temperature": 0.7,
            "stream": True,
        }
        headers = {
            "Authorization": f"Bearer {ORACLE_LLM_KEY}",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                f"{ORACLE_LLM_URL}/v1/chat/completions",
                json=llm_body,
                headers=headers,
            ) as resp:
                buffer = ""
                async for chunk in resp.aiter_bytes():
                    buffer += chunk.decode()
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if line.startswith("data: "):
                            data_str = line[6:].strip()
                            if data_str == "[DONE]":
                                continue
                            try:
                                parsed = json.loads(data_str)
                                delta = parsed.get("choices", [{}])[0].get("delta", {}).get("content")
                                if delta:
                                    yield f"data: {json.dumps({'content': delta})}\n\n"
                            except json.JSONDecodeError:
                                pass
                yield f"data: {json.dumps({'done': True})}\n\n"

    from fastapi.responses import StreamingResponse
    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/api/chat")
async def api_chat(request: Request):
    body = await request.json()
    query = body.get("query", "")
    session_id = body.get("session_id", "default")
    if not query:
        return {"content": "No query provided", "type": "error", "session_id": session_id, "sources": [], "analysis": None}

    messages = [
        {"role": "system", "content": "You are Acronous AI assistant."},
        {"role": "user", "content": query},
    ]
    data = await _call_llm(messages)
    content = _sanitize(data["choices"][0]["message"]["content"])
    return {"content": content, "type": "chat", "session_id": session_id, "sources": [], "analysis": None}


@router.post("/v1/chat/image")
async def v1_chat_image(file: UploadFile = File(...), message: str = Form(""), session_id: str = Form("default")):
    if not file:
        return {"response": "No image provided", "session_id": session_id, "type": "error"}
    file_bytes = await file.read()
    b64 = base64.b64encode(file_bytes).decode()
    mime = file.content_type or "image/jpeg"

    content = [
        {"type": "text", "text": message or "Analyze this image"},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
    ]
    messages = [
        {"role": "system", "content": "You are Acronous AI. Analyze images in detail."},
        {"role": "user", "content": content},
    ]
    data = await _call_llm(messages)
    response_text = _sanitize(data["choices"][0]["message"]["content"])
    return {
        "response": response_text, "session_id": session_id, "type": "chat",
        "image_data": "", "image_type": "", "file_data": "", "file_name": "", "file_type": "",
        "complexity": 0, "complexity_label": "simple",
    }


@router.post("/v1/chat/file")
async def v1_chat_file(file: UploadFile = File(...), message: str = Form(""), session_id: str = Form("default")):
    if not file:
        return {"response": "No file provided", "session_id": session_id, "type": "error"}
    file_bytes = await file.read()
    file_name = file.filename or "upload"
    text = file_bytes.decode("utf-8", errors="replace")[:50000]
    user_content = message or "Analyze this file"
    full_message = f"I've attached a file \"{file_name}\".\n\nFile content:\n{text}\n\nUser message: {user_content}"

    messages = [
        {"role": "system", "content": "You are Acronous AI. Analyze files thoroughly."},
        {"role": "user", "content": full_message},
    ]
    data = await _call_llm(messages)
    response_text = _sanitize(data["choices"][0]["message"]["content"])
    return {
        "response": response_text, "session_id": session_id, "type": "chat",
        "image_data": "", "image_type": "", "file_data": "", "file_name": "", "file_type": "",
        "complexity": 0, "complexity_label": "simple",
    }


# ── Search ─────────────────────────────────────────────────────────────

@router.get("/search")
async def search_get(q: str = "", category: str = "all"):
    if not q:
        return {"results": [], "suggestions": [], "infoboxes": [], "answers": []}
    results = await search_service.search(q, 20)
    return {
        "results": [
            {"title": r.get("title", ""), "url": r.get("url", ""),
             "content": r.get("snippet", ""), "img_src": r.get("img_src")}
            for r in results
        ],
        "suggestions": [], "infoboxes": [], "answers": [],
    }


@router.post("/api/tools/search")
async def api_tools_search(request: Request):
    body = await request.json()
    query = body.get("query", "")
    max_results = body.get("max_results", 5)
    if not query:
        return {"results": []}
    results = await search_service.search(query, max_results)
    return {
        "results": [
            {"title": r.get("title", ""), "url": r.get("url", ""), "snippet": r.get("snippet", "")}
            for r in results
        ]
    }


# ── Image Generation ───────────────────────────────────────────────────

async def _pollinations_image(prompt: str) -> bytes:
    import httpx
    url = f"https://image.pollinations.ai/prompt/{prompt}?width=1024&height=1024&nologo=true"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url)
        if not resp.is_success:
            raise HTTPException(502, "Image generation failed")
        return resp.content


@router.post("/v1/image/generate")
async def v1_image_generate(request: Request):
    body = await request.json()
    prompt = body.get("prompt", "")
    session_id = body.get("session_id", "default")
    if not prompt:
        return {"response": "", "session_id": session_id, "type": "error", "image_data": ""}
    image_bytes = await _pollinations_image(prompt)
    b64 = base64.b64encode(image_bytes).decode()
    return {"response": f"Generated image for: {prompt}", "image_data": b64, "session_id": session_id, "type": "image_gen"}


@router.get("/v1/image/generate")
async def v1_image_generate_get(prompt: str = "", session_id: str = "default"):
    if not prompt:
        return {"response": "", "session_id": session_id, "type": "error", "image_data": ""}
    image_bytes = await _pollinations_image(prompt)
    from fastapi.responses import Response
    return Response(content=image_bytes, media_type="image/png",
                    headers={"Access-Control-Allow-Origin": "*", "Cache-Control": "public, max-age=3600"})


@router.post("/v1/image/edit")
async def v1_image_edit(file: UploadFile = File(...), message: str = Form(""), session_id: str = Form("default")):
    if not file:
        return {"response": "No image provided", "session_id": session_id, "type": "error"}
    file_bytes = await file.read()
    b64 = base64.b64encode(file_bytes).decode()
    edit_desc = message or "edit this image"
    encoded = edit_desc.replace(" ", "%20")
    image_bytes = await _pollinations_image(encoded)
    result_b64 = base64.b64encode(image_bytes).decode()
    return {
        "response": f"Image edited: {edit_desc}", "session_id": session_id, "type": "chat",
        "image_data": result_b64, "image_type": "png", "file_data": "", "file_name": "",
    }


@router.post("/api/image/qr-code")
async def api_qr_code(request: Request):
    body = await request.json()
    data = body.get("data", "")
    size = body.get("size", 256)
    if not data:
        return {"error": "No data provided"}
    import httpx
    url = f"https://api.qrserver.com/v1/create-qr-code/?size={size}x{size}&data={data}"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url)
        if not resp.is_success:
            return {"error": "QR generation failed"}
        b64 = base64.b64encode(resp.content).decode()
    return {"image": b64, "format": "png"}


@router.post("/api/image/redesign")
async def api_image_redesign(file: UploadFile = File(...), prompt: str = Form("")):
    if not file:
        return {"content": None, "error": "No image provided"}
    encoded = (prompt or "redesign this image").replace(" ", "%20")
    image_bytes = await _pollinations_image(encoded)
    b64 = base64.b64encode(image_bytes).decode()
    return {"content": b64, "error": None, "prompt": prompt}


@router.post("/api/image/analyze")
async def api_image_analyze(file: UploadFile = File(...), session_id: str = Form("default")):
    if not file:
        return {"content": "", "type": "error", "session_id": session_id}
    file_bytes = await file.read()
    b64 = base64.b64encode(file_bytes).decode()
    mime = file.content_type or "image/jpeg"
    content = [
        {"type": "text", "text": "Analyze this image in detail. Describe what you see."},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}},
    ]
    messages = [
        {"role": "system", "content": "You are an image analysis AI."},
        {"role": "user", "content": content},
    ]
    data = await _call_llm(messages)
    analysis = _sanitize(data["choices"][0]["message"]["content"])
    return {"content": analysis, "type": "analysis", "session_id": session_id}


# ── Voice ──────────────────────────────────────────────────────────────

@router.post("/api/voice/transcribe")
async def api_voice_transcribe(file: UploadFile = File(...)):
    if not file:
        return {"text": "", "error": "No audio file provided"}
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    try:
        result = await audio_service.transcribe(tmp_path)
        return {"text": result.get("text", ""), "error": None}
    except Exception as e:
        return {"text": "", "error": f"Transcription failed: {e}"}
    finally:
        os.unlink(tmp_path)


# ── Document Processing ────────────────────────────────────────────────

@router.post("/api/tools/process-document")
async def api_process_document(file: UploadFile = File(...)):
    if not file:
        return {"text": "", "error": "No file provided"}
    file_bytes = await file.read()
    file_name = file.filename or "upload"
    ext = file_name.split(".")[-1].lower() if "." in file_name else ""
    text_exts = {"txt", "md", "py", "js", "ts", "html", "css", "json", "xml", "yaml", "yml", "csv", "dart", "go", "rs", "rb", "php", "java", "cpp", "c", "h", "hpp", "swift", "kt", "sh", "bat", "ps1", "sql", "log", "ini", "cfg", "toml", "rtf"}

    if ext in text_exts:
        text = file_bytes.decode("utf-8", errors="replace")
    else:
        text = f"[{file_name}] Binary file ({len(file_bytes)} bytes)"
    return {"text": text, "filename": file_name, "size": len(file_bytes)}


# ── Config & Status ────────────────────────────────────────────────────

@router.get("/api/models/list")
async def api_models_list():
    return {"models": [{"id": "default", "name": "Acronous AI", "provider": "acronous", "backend": "managed"}]}


@router.get("/api/status")
async def api_status():
    return {"status": "running", "vision_enabled": True, "voice_enabled": True, "web_search_enabled": True}


@router.get("/api/config")
async def api_config():
    return {
        "enable_web": True, "enable_vision": True, "enable_voice": True,
        "suggestions": [
            {"icon": "book", "title": "Learn Something", "desc": "Explain ML simply", "query": "Explain machine learning in simple terms"},
            {"icon": "code", "title": "Write Code", "desc": "Create a Python script", "query": "Write a Python script that scrapes a website"},
            {"icon": "image", "title": "Generate Art", "desc": "Draw a landscape", "query": "Draw a serene mountain landscape at sunset"},
            {"icon": "search", "title": "Research", "desc": "Latest AI news", "query": "What are the latest developments in artificial intelligence?"},
        ],
    }


@router.get("/api/config/llm")
async def api_config_llm_get():
    return {"status": "managed"}


@router.post("/api/config/llm")
async def api_config_llm_post():
    return {"status": "managed"}


@router.get("/api/auth/me")
async def api_auth_me():
    return {"id": "local", "email": "local@acronous.ai", "name": "Local User", "provider": "acronous"}


# ── Conversations (in-memory, like CF Worker) ────────────────────────

_conversations: list[dict] = []
_messages_store: dict[str, list[dict]] = {}


@router.get("/api/conversations")
async def api_conversations_list():
    return {"conversations": _conversations}


@router.post("/api/conversations")
async def api_conversations_create(request: Request):
    body = await request.json()
    conv_id = str(uuid.uuid4())
    title = body.get("title", "New Conversation")
    conv = {"id": conv_id, "title": title, "created_at": "2024-01-01T00:00:00Z", "updated_at": "2024-01-01T00:00:00Z"}
    _conversations.insert(0, conv)
    return conv


@router.get("/api/conversations/{conv_id}/messages")
async def api_conversations_messages_list(conv_id: str):
    msgs = _messages_store.get(conv_id, [])
    formatted = [
        {"id": f"msg_{i}", "role": m.get("role", "user"), "content": m.get("content", ""),
         "msg_type": "text", "created_at": m.get("timestamp", "")}
        for i, m in enumerate(msgs)
    ]
    return {"messages": formatted}


@router.post("/api/conversations/{conv_id}/messages")
async def api_conversations_messages_add(conv_id: str, request: Request):
    body = await request.json()
    msg = {"role": body.get("role", "user"), "content": body.get("content", ""), "timestamp": "2024-01-01T00:00:00Z"}
    if conv_id not in _messages_store:
        _messages_store[conv_id] = []
    _messages_store[conv_id].append(msg)
    return {"status": "ok", "id": f"msg_{uuid.uuid4().hex[:8]}"}


@router.get("/api/conversations/{conv_id}/export")
async def api_conversations_export(conv_id: str):
    msgs = _messages_store.get(conv_id, [])
    lines = [f"**{m['role']}**: {m['content']}" for m in msgs]
    from fastapi.responses import PlainTextResponse
    return PlainTextResponse("\n".join(lines), media_type="text/markdown",
                             headers={"Access-Control-Allow-Origin": "*"})


@router.delete("/api/conversations/{conv_id}")
async def api_conversations_delete(conv_id: str):
    global _conversations
    _conversations = [c for c in _conversations if c["id"] != conv_id]
    _messages_store.pop(conv_id, None)
    return {"status": "ok"}


@router.put("/api/conversations/{conv_id}")
async def api_conversations_update(conv_id: str, request: Request):
    body = await request.json()
    title = body.get("title", "Conversation")
    return {"id": conv_id, "title": title, "status": "ok"}


@router.post("/api/conversations/sync")
async def api_conversations_sync(request: Request):
    body = await request.json()
    conversations = body.get("conversations", [])
    return {"status": "ok", "synced": len(conversations)}
