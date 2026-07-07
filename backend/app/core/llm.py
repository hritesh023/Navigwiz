from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_community.chat_models import ChatOllama
from langchain_core.messages import HumanMessage, SystemMessage
from app.config.settings import settings


class LLMService:
    def __init__(self):
        self._llm = None
        self._initialize()

    def _initialize(self):
        if settings.openai_api_key:
            self._llm = ChatOpenAI(
                model=settings.openai_model,
                temperature=0.7,
                max_tokens=4096,
                api_key=settings.openai_api_key
            )
        else:
            self._llm = ChatOllama(
                model="llama3.2",
                temperature=0.7,
                num_predict=4096
            )

    @property
    def llm(self):
        if self._llm is None:
            self._initialize()
        return self._llm

    async def chat(self, messages: list[dict], system_prompt: Optional[str] = None) -> str:
        langchain_messages = []
        if system_prompt:
            langchain_messages.append(SystemMessage(content=system_prompt))
        for msg in messages:
            if msg["role"] == "user":
                langchain_messages.append(HumanMessage(content=msg["content"]))
            elif msg["role"] == "assistant":
                from langchain_core.messages import AIMessage
                langchain_messages.append(AIMessage(content=msg["content"]))
            else:
                langchain_messages.append(SystemMessage(content=msg["content"]))
        response = await self.llm.ainvoke(langchain_messages)
        return response.content

    async def aiFast(self, prompt, system_prompt: Optional[str] = None) -> str:
        if system_prompt is None:
            system_prompt = "You are a helpful AI assistant. Provide concise, accurate answers. For simple questions, give brief and direct responses. For complex queries, provide more detailed explanations. Be factual and helpful."
        messages = [{"role": "system", "content": system_prompt}, {"role": "user", "content": prompt}]
        return await self.chat(messages)

    async def aiSmart(self, prompt, system_prompt: Optional[str] = None) -> str:
        if system_prompt is None:
            system_prompt = "You are an advanced AI assistant specializing in complex problem-solving. Analyze requirements thoroughly, consider multiple approaches, and provide comprehensive detailed answers with step-by-step reasoning. Use external resources when needed for accuracy."
        messages = [{"role": "system", "content": system_prompt}, {"role": "user", "content": prompt}]
        return await self.chat(messages)

    async def chat_with_context(self, messages: list[dict], context: str) -> str:
        system_prompt = f"""You are Navigwiz, an AI-native digital companion.
You understand the user's goals, habits, projects, and digital life.
You have access to the following context about the user:

{context}

Be helpful, concise, and proactive. Act like a trusted friend, not a search engine."""
        return await self.chat(messages, system_prompt)

    async def analyze(self, content: str, prompt: str) -> str:
        messages = [
            {"role": "system", "content": "You are an AI analysis engine."},
            {"role": "user", "content": f"Content:\n{content}\n\nAnalysis request:\n{prompt}"}
        ]
        return await self.chat(messages)

    async def synthesize(self, sources: list[str], query: str) -> str:
        sources_text = "\n\n".join([f"Source {i+1}:\n{s}" for i, s in enumerate(sources)])
        messages = [
            {"role": "system", "content": "You synthesize information from multiple sources."},
            {"role": "user", "content": f"Synthesize the following sources to answer:\n{query}\n\n{sources_text}"}
        ]
        return await self.chat(messages)


llm_service = LLMService()
