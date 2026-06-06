from celery import shared_task
from app.core.memory import semantic_memory
from app.core.llm import llm_service
import asyncio


def _run_coro(coro):
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    return loop.create_task(coro)


@shared_task
def monitor_topic(topic: str, user_id: str, interval_minutes: int = 60):
    from app.services.search import search_service

    async def _run():
        results = await search_service.search(topic, 20)
        summary = await llm_service.synthesize(
            [f"{r.get('title','')}: {r.get('snippet','')}" for r in results[:10]],
            f"What are the latest developments in: {topic}"
        )
        await semantic_memory.remember(
            user_id, "monitoring",
            f"Topic Monitor [{topic}]:\n{summary}",
            tags=["monitoring", topic]
        )
        return {"topic": topic, "results_count": len(results), "summary": summary[:200]}

    return _run_coro(_run())


@shared_task
def organize_memory(user_id: str):
    async def _run():
        results = await semantic_memory.recall(user_id, "organize", 100)
        memory_types = {}
        for r in results:
            mtype = r.get("metadata", {}).get("type", "unknown")
            if mtype not in memory_types:
                memory_types[mtype] = []
            memory_types[mtype].append(r.get("text", "")[:100])

        summary = f"Organized {len(results)} memory entries into {len(memory_types)} categories"
        await semantic_memory.remember(user_id, "system", summary, tags=["organization", "memory_cleanup"])
        return {"total": len(results), "categories": list(memory_types.keys())}

    return _run_coro(_run())


@shared_task
def generate_summary(user_id: str, memory_type: str = "conversation"):
    async def _run():
        results = await semantic_memory.recall(user_id, memory_type, 50)
        texts = [r.get("text", "") for r in results]
        if not texts:
            return {"summary": "No memories found"}
        combined = "\n".join(texts[:10])
        summary = await llm_service.synthesize(
            [combined],
            f"Generate a concise summary of these {memory_type} memories, highlighting key themes, decisions, and insights."
        )
        await semantic_memory.remember(user_id, "summary", summary, tags=["summary", memory_type])
        return {"memory_type": memory_type, "summary": summary}

    return _run_coro(_run())


@shared_task
def background_research(query: str, user_id: str):
    from app.services.search import search_service

    async def _run():
        results = await search_service.search(query, 30)
        summaries = []
        for r in results[:10]:
            summaries.append(f"{r.get('title','')}: {r.get('snippet','')}")

        synthesis = await llm_service.synthesize(
            summaries,
            f"Conduct thorough research on: {query}. Provide key findings, trends, and actionable insights."
        )
        await semantic_memory.remember(user_id, "research", synthesis, tags=["research", "background"])
        return {"query": query, "sources": len(results), "synthesis": synthesis[:500]}

    return _run_coro(_run())
