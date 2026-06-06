import httpx
from bs4 import BeautifulSoup
from duckduckgo_search import DDGS
from app.config.settings import settings


class SearchService:
    def __init__(self):
        self._client = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=30.0, follow_redirects=True)
        return self._client

    async def search(self, query: str, num_results: int = 10) -> list[dict]:
        try:
            return await self._search_searxng(query, num_results)
        except Exception as e:
            print(f"SearXNG search failed: {e}")
        try:
            return await self._search_duckduckgo(query, num_results)
        except Exception as e:
            print(f"DuckDuckGo search failed: {e}")
        return await self._search_fallback(query, num_results)

    async def _search_searxng(self, query: str, num_results: int) -> list[dict]:
        params = {
            "q": query,
            "format": "json",
            "language": "en-US",
            "categories": "general",
            "pageno": 1
        }
        response = await self.client.get(settings.searxng_url, params=params)
        data = response.json()
        results = []
        for r in data.get("results", [])[:num_results]:
            results.append({
                "title": r.get("title", ""),
                "url": r.get("url", ""),
                "snippet": r.get("content", ""),
                "source": "searxng"
            })
        return results

    async def _search_duckduckgo(self, query: str, num_results: int) -> list[dict]:
        import asyncio
        def _search():
            out = []
            with DDGS() as ddgs:
                for i, r in enumerate(ddgs.text(query, max_results=num_results)):
                    if i >= num_results:
                        break
                    out.append({
                        "title": r.get("title", ""),
                        "url": r.get("href", ""),
                        "snippet": r.get("body", ""),
                        "source": "duckduckgo"
                    })
            return out
        return await asyncio.to_thread(_search)

    async def _search_fallback(self, query: str, num_results: int) -> list[dict]:
        url = f"https://html.duckduckgo.com/html/?q={query.replace(' ', '+')}"
        response = await self.client.get(url)
        soup = BeautifulSoup(response.text, "html.parser")
        results = []
        for result in soup.select(".result")[:num_results]:
            title_el = result.select_one(".result__title a")
            snippet_el = result.select_one(".result__snippet")
            if title_el:
                results.append({
                    "title": title_el.get_text(strip=True),
                    "url": title_el.get("href", ""),
                    "snippet": snippet_el.get_text(strip=True) if snippet_el else "",
                    "source": "duckduckgo_html"
                })
        return results

    async def close(self):
        await self.client.aclose()


class ContentExtractor:
    def __init__(self):
        self._client = None

    @property
    def client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=30.0, follow_redirects=True)
        return self._client

    async def extract(self, url: str) -> dict:
        try:
            import trafilatura
            import asyncio
            response = await self.client.get(url)
            text = await asyncio.to_thread(trafilatura.extract, response.text)
            return {
                "url": url,
                "content": text or "",
                "success": text is not None
            }
        except Exception as e:
            print(f"trafilatura extraction failed for {url}: {e}")
        try:
            response = await self.client.get(url)
            soup = BeautifulSoup(response.text, "html.parser")
            for tag in soup(["script", "style", "nav", "footer", "header"]):
                tag.decompose()
            text = soup.get_text(separator="\n", strip=True)
            return {
                "url": url,
                "content": text[:100000],
                "success": bool(text)
            }
        except Exception as e:
            return {"url": url, "content": "", "success": False, "error": str(e)}

    async def close(self):
        if self._client is not None:
            await self._client.aclose()
            self._client = None


search_service = SearchService()
content_extractor = ContentExtractor()
