from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends, WebSocket, WebSocketDisconnect
import json
import os
import uuid
import tempfile

from app.models.schemas import (
    ChatRequest, ChatResponse, MemorySearchRequest, MemoryEntry,
    KnowledgeNode, KnowledgeEdge, Workspace, SearchRequest, AnalysisRequest, SynthesisRequest
)
from app.core.auth import verify_token, create_access_token
from app.core.llm import llm_service
from app.core.memory import semantic_memory, knowledge_graph
from app.core.workflows import create_research_workflow, create_analysis_workflow
from app.services.search import search_service, content_extractor
from app.services.document import document_service, vision_service
from app.services.audio import audio_service
from app.services.browser import browser_automation
from app.config.settings import settings

router = APIRouter(prefix="/api/v1")
research_workflow = create_research_workflow(llm_service)
analysis_workflow = create_analysis_workflow(llm_service)


@router.get("/health")
async def health():
    return {
        "status": "healthy",
        "app": settings.app_name,
        "version": settings.app_version,
        "memory": "chromadb+faiss",
        "llm": settings.openai_model if settings.openai_api_key else "ollama"
    }


@router.post("/auth/signup")
async def sign_up(email: str = Form(...), password: str = Form(...), display_name: str = Form("")):
    from app.config.database import get_supabase_service
    supabase = get_supabase_service()
    try:
        result = supabase.auth.sign_up({"email": email, "password": password})
        if result.user:
            supabase.table("profiles").insert({
                "id": result.user.id,
                "email": email,
                "display_name": display_name or email.split("@")[0]
            }).execute()
            token = create_access_token(result.user.id, email)
            return {"user": {"id": result.user.id, "email": email}, "token": token}
        return {"error": "Sign up failed"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/auth/signin")
async def sign_in(email: str = Form(...), password: str = Form(...)):
    from app.config.database import supabase
    try:
        result = supabase.auth.sign_in_with_password({"email": email, "password": password})
        if result.user:
            token = create_access_token(result.user.id, email)
            return {
                "user": {"id": result.user.id, "email": email},
                "token": token,
                "refresh_token": result.session.refresh_token if hasattr(result.session, 'refresh_token') else None
            }
        return {"error": "Invalid credentials"}
    except Exception as e:
        raise HTTPException(status_code=401, detail=str(e))


@router.post("/auth/signout")
async def sign_out(user: dict = Depends(verify_token)):
    from app.config.database import supabase
    supabase.auth.sign_out()
    return {"status": "signed_out"}


@router.post("/chat")
async def chat(request: ChatRequest, user: dict = Depends(verify_token)):
    context_parts = []
    memory_results = await semantic_memory.recall(user["id"], request.message, 5)
    if memory_results:
        context_parts.append("Relevant memories:\n" + "\n".join([m.get("text", "") for m in memory_results]))

    attachment_context = ""
    if request.attachments:
        for att in request.attachments:
            attachment_context += f"\n[Attachment: {att.name} ({att.type})]\n"
            if att.data:
                attachment_context += f"Content: {att.data[:5000]}\n"

    context = "\n".join(context_parts)
    messages = [{"role": "user", "content": request.message}]
    if attachment_context:
        messages.insert(0, {"role": "system", "content": f"User has attached:\n{attachment_context}"})

    response = await llm_service.chat_with_context(messages, context)

    await semantic_memory.remember(
        user["id"], "conversation",
        f"Q: {request.message}\nA: {response[:500]}",
        tags=["chat", "conversation"]
    )

    return ChatResponse(
        message=response,
        session_id=request.session_id or str(uuid.uuid4()),
        sources=[{"type": "memory", "count": len(memory_results)}]
    )


@router.post("/chat/stream")
async def chat_stream(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            request = ChatRequest.model_validate_json(data)
            messages = [{"role": "user", "content": request.message}]
            response = await llm_service.chat(messages)
            for chunk in [response[i:i+50] for i in range(0, len(response), 50)]:
                await websocket.send_text(json.dumps({"type": "chunk", "content": chunk}))
            await websocket.send_text(json.dumps({"type": "done", "session_id": str(uuid.uuid4())}))
    except WebSocketDisconnect:
        pass


@router.post("/memory/search")
async def search_memory(request: MemorySearchRequest, user: dict = Depends(verify_token)):
    results = await semantic_memory.recall(user["id"], request.query, request.limit)
    return {"results": results}


@router.post("/memory/store")
async def store_memory(entry: MemoryEntry, user: dict = Depends(verify_token)):
    entry.user_id = user["id"]
    memory_id = await semantic_memory.remember(user["id"], entry.type.value, entry.content, entry.tags)
    return {"id": memory_id, "status": "stored"}


@router.get("/memory/types/{memory_type}")
async def get_memories_by_type(memory_type: str, user: dict = Depends(verify_token)):
    results = await semantic_memory.recall(user["id"], memory_type, 50)
    return {"results": results}


@router.post("/knowledge/node")
async def add_knowledge_node(node: KnowledgeNode, user: dict = Depends(verify_token)):
    node_id = str(uuid.uuid4())
    node.id = node_id
    node.user_id = user["id"]
    await knowledge_graph.add_node(node_id, node.label, node.node_type, node.properties)
    return {"id": node_id, "status": "created"}


@router.post("/knowledge/edge")
async def add_knowledge_edge(edge: KnowledgeEdge, user: dict = Depends(verify_token)):
    knowledge_graph.add_edge(edge.source_id, edge.target_id, edge.relationship, edge.weight)
    return {"status": "created"}


@router.get("/knowledge/related/{node_id}")
async def get_related_nodes(node_id: str, depth: int = 2):
    related = knowledge_graph.get_related(node_id, depth)
    return {"nodes": related}


@router.get("/knowledge/graph")
async def get_knowledge_graph():
    return knowledge_graph.to_dict()


@router.post("/search")
async def search(request: SearchRequest):
    results = await search_service.search(request.query, request.num_results)
    return {"results": results, "query": request.query, "category": request.category}


@router.post("/extract")
async def extract_content(url: str = Form(...)):
    result = await content_extractor.extract(url)
    return result


@router.post("/analyze")
async def analyze(request: AnalysisRequest, user: dict = Depends(verify_token)):
    if request.file_path:
        result = await document_service.process(request.file_path, request.type)
        analysis = await llm_service.analyze(result["text"], request.prompt or "Analyze this content")
        return {"analysis": analysis, "metadata": result.get("metadata", {})}
    if request.content:
        analysis = await llm_service.analyze(request.content, request.prompt or "Analyze this content")
        return {"analysis": analysis}
    raise HTTPException(status_code=400, detail="No content or file_path provided")


@router.post("/synthesize")
async def synthesize(request: SynthesisRequest):
    result = await llm_service.synthesize(request.sources, request.query)
    return {"synthesis": result, "sources_count": len(request.sources)}


@router.post("/research")
async def research(query: str = Form(...), user: dict = Depends(verify_token)):
    state = await research_workflow.ainvoke({"input": query, "steps": []})
    return {
        "output": state.get("output", ""),
        "analysis": state.get("analysis", ""),
        "steps": state.get("steps", []),
        "sources_count": len(state.get("search_results", []))
    }


@router.post("/upload")
async def upload_file(file: UploadFile = File(...), analysis_type: str = Form("auto"), user: dict = Depends(verify_token)):
    os.makedirs(f"./data/uploads/{user['id']}", exist_ok=True)
    file_ext = file.filename.split(".")[-1].lower() if "." in file.filename else "bin"
    file_id = f"{uuid.uuid4().hex[:12]}.{file_ext}"
    file_path = f"./data/uploads/{user['id']}/{file_id}"

    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    result = await document_service.process(file_path, file_ext)
    ocr_texts = []
    if file_ext in ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"]:
        ocr_texts = await document_service.extract_images(file_path)
        vision_result = await vision_service.analyze_image(file_path)
        result["vision_analysis"] = vision_result

    await semantic_memory.remember(
        user["id"], "file",
        f"File: {file.filename}\nSummary: {result['text'][:1000]}",
        tags=[file_ext, "uploaded_file"]
    )

    return {
        "file_id": file_id,
        "filename": file.filename,
        "type": file_ext,
        "size": len(content),
        "analysis": result,
        "ocr_texts": ocr_texts
    }


@router.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    try:
        result = await audio_service.transcribe(tmp_path)
        return result
    finally:
        os.unlink(tmp_path)


@router.post("/tts")
async def text_to_speech(text: str = Form(...), voice: str = Form("default")):
    audio_data = await audio_service.text_to_speech(text, voice)
    from fastapi.responses import Response
    return Response(content=audio_data, media_type="audio/wav")


@router.post("/browser/navigate")
async def browser_navigate(url: str = Form(...)):
    result = await browser_automation.navigate(url)
    return result


@router.post("/browser/screenshot")
async def browser_screenshot(url: str = Form(...)):
    screenshot_data = await browser_automation.screenshot(url)
    if screenshot_data:
        from fastapi.responses import Response
        return Response(content=screenshot_data, media_type="image/png")
    raise HTTPException(status_code=400, detail="Screenshot failed")


@router.post("/workspace")
async def create_workspace(workspace: Workspace, user: dict = Depends(verify_token)):
    workspace.user_id = user["id"]
    workspace.id = str(uuid.uuid4())
    from app.config.database import supabase
    data = workspace.model_dump()
    supabase.table("workspaces").insert(data).execute()
    return {"id": workspace.id, "status": "created"}


@router.get("/workspace")
async def get_workspaces(user: dict = Depends(verify_token)):
    from app.config.database import supabase
    result = supabase.table("workspaces").select("*").eq("user_id", user["id"]).execute()
    return {"workspaces": result.data}


@router.get("/workspace/{workspace_id}")
async def get_workspace(workspace_id: str, user: dict = Depends(verify_token)):
    from app.config.database import supabase
    result = supabase.table("workspaces").select("*").eq("id", workspace_id).eq("user_id", user["id"]).single().execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Workspace not found")
    return result.data


@router.delete("/workspace/{workspace_id}")
async def delete_workspace(workspace_id: str, user: dict = Depends(verify_token)):
    from app.config.database import supabase
    supabase.table("workspaces").delete().eq("id", workspace_id).eq("user_id", user["id"]).execute()
    return {"status": "deleted"}


@router.post("/analyze/image")
async def analyze_image(file: UploadFile = File(...), prompt: str = Form("Describe this image in detail.")):
    with tempfile.NamedTemporaryFile(suffix=f".{file.filename.split('.')[-1]}", delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    try:
        analysis = await vision_service.analyze_image(tmp_path, prompt)
        ocr_text = await vision_service.extract_text_from_image(tmp_path)
        return {
            "analysis": analysis,
            "ocr_text": ocr_text,
            "filename": file.filename
        }
    finally:
        os.unlink(tmp_path)


@router.post("/image/generate")
async def generate_image(prompt: str = Form(...), style: str = Form("natural"), size: str = Form("1024x1024")):
    width, height = map(int, size.split("x"))
    from PIL import Image as PILImage, ImageDraw, ImageFont
    import io
    import base64

    img = PILImage.new("RGB", (width, height), color=(20, 20, 30))
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 32)
    except Exception:
        font = ImageFont.load_default()

    lines = []
    words = prompt.split()
    line = ""
    for word in words:
        test = f"{line} {word}".strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] > width - 80:
            lines.append(line)
            line = word
        else:
            line = test
    lines.append(line if line else prompt)

    y_start = height // 2 - (len(lines) * 25)
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        text_width = bbox[2] - bbox[0]
        x = (width - text_width) // 2
        draw.text((x, y_start + i * 50), line, fill=(200, 200, 255), font=font)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    img_b64 = base64.b64encode(buf.getvalue()).decode()

    return {
        "image": f"data:image/png;base64,{img_b64}",
        "prompt": prompt,
        "size": size,
        "format": "png"
    }


@router.post("/extensions/load")
async def load_extension(path: str = Form(...), user: dict = Depends(verify_token)):
    import os
    import json
    EXTENSIONS_DIR = os.path.join(os.path.dirname(__file__), "..", "extensions")
    resolved = os.path.normpath(os.path.join(EXTENSIONS_DIR, path))
    if not resolved.startswith(os.path.normpath(EXTENSIONS_DIR)):
        raise HTTPException(status_code=403, detail="Path outside extensions directory")
    if not os.path.exists(resolved):
        raise HTTPException(status_code=404, detail="Extension path not found")
    manifest_path = os.path.join(resolved, "manifest.json")
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            manifest = json.load(f)
        return {"name": manifest.get("name", "Unknown"), "version": manifest.get("version", "0.0.0"), "path": resolved}
    return {"name": os.path.basename(resolved), "version": "1.0.0", "path": resolved}


@router.post("/memory/clear")
async def clear_memories(memory_type: str = Form(""), user: dict = Depends(verify_token)):
    results = await semantic_memory.recall(user["id"], memory_type or "all", 1000)
    count = 0
    for r in results:
        mid = r.get("id", "")
        if mid:
            await semantic_memory.forget(user["id"], mid)
            count += 1
    return {"cleared": count, "memory_type": memory_type or "all"}


@router.get("/assistant/config")
async def get_assistant_config(user: dict = Depends(verify_token)):
    return {
        "name": "Navigwiz",
        "version": settings.app_version,
        "capabilities": [
            "web_search", "camera_analysis", "voice_input",
            "document_analysis", "image_understanding", "file_organization",
            "memory", "knowledge_graph", "research", "monitoring",
            "content_extraction", "synthesis", "code_analysis"
        ],
        "features": {
            "memory": True,
            "knowledge_graph": True,
            "background_tasks": True,
            "realtime": True
        }
    }


@router.post("/analyze/video")
async def analyze_video(file: UploadFile = File(...), prompt: str = Form("Describe what's happening in this video.")):
    with tempfile.NamedTemporaryFile(suffix=f".{file.filename.split('.')[-1]}", delete=False) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    try:
        import cv2
        cap = cv2.VideoCapture(tmp_path)
        frames = []
        frame_count = 0
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            if frame_count % 30 == 0:
                frame_path = f"{tmp_path}_frame_{frame_count}.jpg"
                cv2.imwrite(frame_path, frame)
                frames.append(frame_path)
            frame_count += 1
        cap.release()

        frame_analyses = []
        for i, fp in enumerate(frames[:5]):
            analysis = await vision_service.analyze_image(fp, f"{prompt} (Frame {i+1})")
            frame_analyses.append({"frame": i + 1, "analysis": analysis})
            os.unlink(fp)

        video_text = f"Video: {file.filename}\nFrames: {frame_count}\n"
        for fa in frame_analyses:
            video_text += f"\nFrame {fa['frame']}: {fa['analysis'][:500]}"

        summary = await llm_service.synthesize(
            [fa["analysis"] for fa in frame_analyses],
            "Summarize this video content analysis"
        )

        return {
            "filename": file.filename,
            "total_frames": frame_count,
            "analyzed_frames": len(frame_analyses),
            "frame_analyses": frame_analyses,
            "summary": summary
        }
    finally:
        os.unlink(tmp_path)
