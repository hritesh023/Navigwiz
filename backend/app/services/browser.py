from typing import Optional
from playwright.async_api import async_playwright, Browser, Playwright


class BrowserAutomation:
    def __init__(self):
        self._playwright: Optional[Playwright] = None
        self._browser: Optional[Browser] = None

    async def _ensure_browser(self, headless: bool = True) -> Browser:
        if self._browser is None:
            self._playwright = await async_playwright().start()
            self._browser = await self._playwright.chromium.launch(headless=headless)
        return self._browser

    async def _new_page(self, headless: bool = True):
        browser = await self._ensure_browser(headless)
        return await browser.new_page(
            viewport={"width": 1920, "height": 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )

    async def navigate(self, url: str, headless: bool = True) -> dict:
        page = await self._new_page(headless)
        try:
            response = await page.goto(url, wait_until="networkidle", timeout=30000)
            title = await page.title()
            content = await page.content()
            text = await page.inner_text("body")
            screenshot = await page.screenshot(full_page=True, type="png")
            return {
                "url": url,
                "title": title,
                "content": content,
                "text": text[:100000],
                "status": response.status if response else None,
                "screenshot": screenshot,
                "success": True
            }
        except Exception as e:
            return {"url": url, "error": str(e), "success": False}
        finally:
            await page.close()

    async def screenshot(self, url: str, full_page: bool = False) -> Optional[bytes]:
        page = await self._new_page()
        try:
            await page.goto(url, wait_until="networkidle", timeout=30000)
            screenshot = await page.screenshot(full_page=full_page, type="png")
            return screenshot
        except Exception:
            return None
        finally:
            await page.close()

    async def extract_links(self, url: str) -> list[dict]:
        page = await self._new_page()
        try:
            await page.goto(url, wait_until="networkidle", timeout=30000)
            links = await page.evaluate("""
                () => Array.from(document.querySelectorAll('a[href]')).map(a => ({
                    text: a.innerText.trim(),
                    href: a.href,
                    title: a.title
                }))
            """)
            return links[:500]
        except Exception:
            return []
        finally:
            await page.close()

    async def close(self):
        if self._browser:
            await self._browser.close()
            self._browser = None
        if self._playwright:
            await self._playwright.stop()
            self._playwright = None


browser_automation = BrowserAutomation()
