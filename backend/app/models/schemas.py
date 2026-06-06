from pydantic import BaseModel, Field
from typing import Optional, Any
from datetime import datetime
from enum import Enum


class MessageRole(str, Enum):
    user = "user"
    assistant = "assistant"
    system = "system"


class Attachment(BaseModel):
    name: str
    type: str
    path: Optional[str] = None
    content_type: str = "text"
    data: Optional[str] = None


class ChatMessage(BaseModel):
    role: MessageRole
    content: str
    attachments: list[Attachment] = []
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    attachments: list[Attachment] = []
    workspace_id: Optional[str] = None


class ChatResponse(BaseModel):
    message: str
    session_id: str
    sources: list[dict] = []


class MemoryType(str, Enum):
    long_term = "long_term"
    semantic = "semantic"
    project = "project"
    browsing = "browsing"
    file = "file"
    conversation = "conversation"
    knowledge = "knowledge"


class MemoryEntry(BaseModel):
    id: Optional[str] = None
    type: MemoryType
    content: str
    embedding: Optional[list[float]] = None
    metadata: dict[str, Any] = {}
    user_id: str
    tags: list[str] = []
    created_at: datetime = Field(default_factory=datetime.utcnow)


class MemorySearchRequest(BaseModel):
    query: str
    types: list[MemoryType] = []
    limit: int = 10
    threshold: float = 0.7


class KnowledgeNode(BaseModel):
    id: Optional[str] = None
    label: str
    node_type: str
    description: str = ""
    properties: dict[str, Any] = {}
    user_id: str


class KnowledgeEdge(BaseModel):
    source_id: str
    target_id: str
    relationship: str
    weight: float = 1.0


class KnowledgeGraph(BaseModel):
    nodes: list[KnowledgeNode] = []
    edges: list[KnowledgeEdge] = []


class WorkspaceItem(BaseModel):
    id: Optional[str] = None
    type: str
    title: str
    content: str = ""
    url: Optional[str] = None
    metadata: dict[str, Any] = {}
    file_path: Optional[str] = None


class Workspace(BaseModel):
    id: Optional[str] = None
    name: str
    description: str = ""
    user_id: str
    items: list[WorkspaceItem] = []
    created_at: datetime = Field(default_factory=datetime.utcnow)


class ProjectFile(BaseModel):
    name: str
    type: str
    path: str
    size: int = 0
    metadata: dict[str, Any] = {}


class AnalysisRequest(BaseModel):
    type: str
    content: Optional[str] = None
    file_path: Optional[str] = None
    prompt: Optional[str] = None


class SynthesisRequest(BaseModel):
    sources: list[str]
    query: str
    format: str = "summary"


class SearchRequest(BaseModel):
    query: str
    category: str = "general"
    num_results: int = 10


class BackgroundTaskRequest(BaseModel):
    task_type: str
    params: dict[str, Any] = {}
    schedule: Optional[str] = None
    user_id: str
