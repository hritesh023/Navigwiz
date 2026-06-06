import json
import os
import uuid
from datetime import datetime
import chromadb
from chromadb.config import Settings as ChromaSettings
from sentence_transformers import SentenceTransformer
from app.config.settings import settings


class VectorMemory:
    def __init__(self):
        os.makedirs(settings.chroma_db_path, exist_ok=True)
        os.makedirs(settings.faiss_index_path, exist_ok=True)

        self.chroma_client = chromadb.PersistentClient(
            path=settings.chroma_db_path,
            settings=ChromaSettings(anonymized_telemetry=False)
        )

        self.embedding_model = SentenceTransformer(settings.embedding_model)

    def _get_or_create_collection(self, collection_name: str):
        try:
            return self.chroma_client.get_collection(collection_name)
        except ValueError:
            return self.chroma_client.create_collection(collection_name)

    def embed_text(self, text: str) -> list[float]:
        return self.embedding_model.encode(text).tolist()

    def embed_batch(self, texts: list[str]) -> list[list[float]]:
        return self.embedding_model.encode(texts).tolist()

    async def embed_text_async(self, text: str) -> list[float]:
        import asyncio
        return await asyncio.to_thread(self.embed_text, text)

    async def embed_batch_async(self, texts: list[str]) -> list[list[float]]:
        import asyncio
        return await asyncio.to_thread(self.embed_batch, texts)

    async def store(self, collection: str, id: str, text: str, metadata: dict = None):
        col = self._get_or_create_collection(collection)
        embedding = await self.embed_text_async(text)
        col.add(
            ids=[id],
            embeddings=[embedding],
            metadatas=[metadata or {}],
            documents=[text]
        )

    async def delete(self, collection: str, id: str):
        col = self._get_or_create_collection(collection)
        col.delete(ids=[id])

    async def update(self, collection: str, id: str, text: str, metadata: dict = None):
        col = self._get_or_create_collection(collection)
        embedding = await self.embed_text_async(text)
        col.update(
            ids=[id],
            embeddings=[embedding],
            metadatas=[metadata or {}],
            documents=[text]
        )

    async def search(self, collection: str, query: str, n_results: int = 10, threshold: float = 0.0) -> list[dict]:
        col = self._get_or_create_collection(collection)
        query_embedding = await self.embed_text_async(query)
        results = col.query(
            query_embeddings=[query_embedding],
            n_results=n_results
        )
        items = []
        if results["ids"] and results["ids"][0]:
            for i, id_val in enumerate(results["ids"][0]):
                distance = results["distances"][0][i] if results["distances"] else 0
                score = 1 - distance
                if score >= threshold:
                    items.append({
                        "id": id_val,
                        "text": results["documents"][0][i] if results["documents"] else "",
                        "metadata": results["metadatas"][0][i] if results["metadatas"] else {},
                        "score": float(score)
                    })
        return items


class SemanticMemory:
    def __init__(self, vector_memory: VectorMemory):
        self.vector = vector_memory

    async def remember(self, user_id: str, memory_type: str, content: str, tags: list[str] = None):
        memory_id = f"{memory_type}_{user_id}_{uuid.uuid4().hex[:12]}"
        metadata = {
            "user_id": user_id,
            "type": memory_type,
            "tags": json.dumps(tags or []),
            "timestamp": str(datetime.utcnow())
        }
        await self.vector.store(f"memory_{user_id}", memory_id, content, metadata)
        return memory_id

    async def recall(self, user_id: str, query: str, n_results: int = 10) -> list[dict]:
        return await self.vector.search(f"memory_{user_id}", query, n_results)

    async def search_across_users(self, query: str, n_results: int = 20) -> list[dict]:
        return await self.vector.search("global_memory", query, n_results)

    async def forget(self, user_id: str, memory_id: str):
        await self.vector.delete(f"memory_{user_id}", memory_id)


class KnowledgeGraphMemory:
    def __init__(self, vector_memory: VectorMemory):
        self.vector = vector_memory
        import networkx as nx
        self.graph = nx.MultiDiGraph()  # type: ignore[import-untyped]

    async def add_node(self, node_id: str, label: str, node_type: str, properties: dict = None):
        self.graph.add_node(node_id, label=label, type=node_type, properties=properties or {})
        await self.vector.store(
            "knowledge_graph",
            node_id,
            f"{label} ({node_type}): {json.dumps(properties or {})}",
            {"type": node_type, "label": label}
        )

    def add_edge(self, source_id: str, target_id: str, relationship: str, weight: float = 1.0):
        self.graph.add_edge(source_id, target_id, relationship=relationship, weight=weight)

    def get_related(self, node_id: str, depth: int = 2) -> list[dict]:
        if node_id not in self.graph:
            return []
        from collections import deque
        visited = {node_id}
        queue = deque([(node_id, 0)])
        related = []
        while queue:
            current, d = queue.popleft()
            if d >= depth:
                continue
            for neighbor in self.graph.neighbors(current):
                if neighbor not in visited:
                    visited.add(neighbor)
                    edge_data = self.graph.get_edge_data(current, neighbor)
                    rel = list(edge_data.values())[0].get("relationship", "related") if edge_data else "related"
                    node_data = self.graph.nodes[neighbor]
                    related.append({
                        "id": neighbor,
                        "label": node_data.get("label", ""),
                        "type": node_data.get("type", ""),
                        "relationship": rel
                    })
                    queue.append((neighbor, d + 1))
        return related

    async def search_nodes(self, query: str) -> list[dict]:
        return await self.vector.search("knowledge_graph", query)

    def to_dict(self) -> dict:
        nodes = []
        for nid, data in self.graph.nodes(data=True):
            nodes.append({"id": nid, **data})
        edges = []
        for u, v, data in self.graph.edges(data=True):
            edges.append({"source": u, "target": v, **data})
        return {"nodes": nodes, "edges": edges}


vector_memory = VectorMemory()
semantic_memory = SemanticMemory(vector_memory)
knowledge_graph = KnowledgeGraphMemory(vector_memory)
