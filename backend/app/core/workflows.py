from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated, Optional
import operator


class AgentState(TypedDict):
    input: str
    context: Optional[str]
    search_results: Optional[list[dict]]
    analysis: Optional[str]
    output: Optional[str]
    steps: Annotated[list[str], operator.add]


def create_research_workflow(llm_service):
    workflow = StateGraph(AgentState)

    async def search_web(state: AgentState) -> dict:
        from app.services.search import search_service
        query = state["input"]
        results = await search_service.search(query)
        steps = [f"Searched web for: {query}"]
        return {"search_results": results, "steps": steps}

    async def analyze_results(state: AgentState) -> dict:
        results = state.get("search_results", [])
        query = state["input"]
        context = "\n".join([f"{r.get('title','')}: {r.get('snippet','')}" for r in results[:5]])
        analysis = await llm_service.analyze(
            context,
            f"Analyze these search results for query: {query}. Extract key insights, patterns, and actionable information."
        )
        return {"analysis": analysis, "steps": ["Analyzed search results"]}

    async def generate_output(state: AgentState) -> dict:
        analysis = state.get("analysis", "")
        query = state["input"]
        output = await llm_service.chat([
            {"role": "user", "content": f"Based on this analysis:\n{analysis}\n\nProvide a comprehensive response to: {query}"}
        ])
        return {"output": output, "steps": ["Generated final output"]}

    workflow.add_node("search", search_web)
    workflow.add_node("analyze", analyze_results)
    workflow.add_node("generate", generate_output)

    workflow.set_entry_point("search")
    workflow.add_edge("search", "analyze")
    workflow.add_edge("analyze", "generate")
    workflow.add_edge("generate", END)

    return workflow.compile()


def create_analysis_workflow(llm_service):
    workflow = StateGraph(AgentState)

    async def extract_content(state: AgentState) -> dict:
        content = state.get("context", state["input"])
        return {"context": content, "steps": ["Extracted content"]}

    async def analyze_deep(state: AgentState) -> dict:
        content = state.get("context", "")
        analysis = await llm_service.analyze(
            content,
            "Perform deep analysis. Identify: 1) Key topics and themes 2) Entities mentioned 3) Relationships between concepts 4) Sentiment and tone 5) Actionable insights"
        )
        return {"analysis": analysis, "steps": ["Performed deep analysis"]}

    async def summarize(state: AgentState) -> dict:
        analysis = state.get("analysis", "")
        output = await llm_service.chat([
            {"role": "user", "content": f"Summarize this analysis concisely:\n{analysis}"}
        ])
        return {"output": output, "steps": ["Generated summary"]}

    workflow.add_node("extract", extract_content)
    workflow.add_node("analyze", analyze_deep)
    workflow.add_node("summarize", summarize)

    workflow.set_entry_point("extract")
    workflow.add_edge("extract", "analyze")
    workflow.add_edge("analyze", "summarize")
    workflow.add_edge("summarize", END)

    return workflow.compile()
