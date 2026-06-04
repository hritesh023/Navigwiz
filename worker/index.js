const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const SEARXNG_URLS = [
  'https://searx.be/search',
  'https://search.sapti.me/search',
  'https://searx.thegreenwebfoundation.org/search',
  'https://searx.tuxcloud.net/search',
  'https://searx.work/search',
  'https://searx.info/search',
  'https://search.mdosch.de/search',
  'https://northboot.xyz/search',
];
const DDG_HTML_URL = 'https://html.duckduckgo.com/html/';
const ALLOWED_ORIGINS = '*';

const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGINS,
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

function respondJson(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function respondError(message, status = 500) {
  return respondJson({ response: message, type: 'error' }, status);
}

async function handleChat(request) {
  try {
    const apiKey = OPENAI_API_KEY;
    if (!apiKey) {
      return respondError('OpenAI API key not configured on server.', 500);
    }

    const body = await request.json();
    const userMessage = body.message || body.query || '';

    const searchResults = await duckDuckGoApiSearch(userMessage, 5);
    let enhancedMessage = userMessage;
    if (searchResults.length > 0) {
      const context = searchResults.map(r => `- ${r.title}\n  URL: ${r.url}\n  ${r.snippet}`).join('\n\n');
      enhancedMessage = `User query: ${userMessage}\n\nCurrent web search results:\n${context}\n\nPlease answer based on the above search results and your knowledge. Cite sources by URL.`;
    }

    const isFileRequest = /pdf|document|file/i.test(userMessage);

    const openaiBody = {
      model: body.model || 'openai/gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: isFileRequest
            ? 'You are a helpful assistant that generates documents. Respond with the document content in markdown format. At the end, specify the file format as: [FILE_TYPE: pdf|csv|txt|md|html] and [FILE_NAME: filename.extension]'
            : 'You are Navigwiz AI assistant. Use the provided search results when available to give accurate, real-time answers. Cite sources by URL when using search results.'
        },
        { role: 'user', content: enhancedMessage },
      ],
      max_tokens: isFileRequest ? 4096 : 2048,
    };

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://navigwiz.app',
        'X-Title': 'Navigwiz',
      },
      body: JSON.stringify(openaiBody),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`OpenRouter API error: ${response.status}`, text);
      return respondError('AI service error. Please try again.', 502);
    }

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content || '';

    if (isFileRequest) {
      const typeMatch = content.match(/\[FILE_TYPE:\s*(\w+)\]/);
      const nameMatch = content.match(/\[FILE_NAME:\s*([^\]]+)\]/);
      const fileType = typeMatch ? typeMatch[1] : 'txt';
      const fileName = nameMatch ? nameMatch[1] : 'document.txt';
      const fileData = content.replace(/\[FILE_TYPE:\s*\w+\]/g, '').replace(/\[FILE_NAME:\s*[^\]]+\]/g, '').trim();
      return respondJson({
        response: `Generated file: ${fileName}`,
        session_id: body.session_id || '',
        type: 'chat',
        file_data: btoa(unescape(encodeURIComponent(fileData))),
        file_name: fileName,
        file_type: fileType,
      });
    }

    return respondJson({
      response: content,
      session_id: body.session_id || '',
      type: 'chat',
    });
  } catch (error) {
    console.error('Chat handler error:', error.message);
    return respondError('I could not complete that request. Please try again.', 502);
  }
}

async function duckDuckGoApiSearch(query, maxResults = 8) {
  try {
    const response = await fetch(`https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_html=1&skip_disambig=1`, {
      headers: { 'User-Agent': 'Navigwiz/1.0.0' },
    });
    if (!response.ok) return [];
    const data = await response.json();
    const results = [];
    if (data.AbstractText && data.AbstractURL) {
      results.push({ title: data.Heading || query, url: data.AbstractURL, snippet: data.AbstractText });
    }
    if (data.RelatedTopics) {
      for (const topic of data.RelatedTopics) {
        if (results.length >= maxResults) break;
        if (topic.Text && topic.FirstURL) {
          results.push({ title: topic.Text.split(' - ')[0], url: topic.FirstURL, snippet: topic.Text });
        }
        if (topic.Topics) {
          for (const sub of topic.Topics) {
            if (results.length >= maxResults) break;
            if (sub.Text && sub.FirstURL) {
              results.push({ title: sub.Text.split(' - ')[0], url: sub.FirstURL, snippet: sub.Text });
            }
          }
        }
      }
    }
    return results;
  } catch (e) {
    return [];
  }
}

async function duckDuckGoHtmlSearch(query, maxResults = 15) {
  try {
    const response = await fetch(`${DDG_HTML_URL}?q=${encodeURIComponent(query)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    });
    if (!response.ok) return [];
    const body = await response.text();
    const results = [];
    const resultRegex = /<a[^>]*class="result__a[^"]*"[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gs;
    const snippetRegex = /class="result__snippet[^"]*"[^>]*>(.*?)<\/(?:a|div|span)>/gs;

    const linkMatches = [...body.matchAll(resultRegex)];
    const snippetMatches = [...body.matchAll(snippetRegex)];

    for (let i = 0; i < linkMatches.length && results.length < maxResults; i++) {
      const match = linkMatches[i];
      let rawUrl = (match[1] || '').trim();
      const rawTitle = stripHtml(match[2] || '').trim();
      if (!rawTitle || !rawUrl) continue;

      let url = rawUrl;
      if (url.startsWith('//')) url = 'https:' + url;
      try {
        const uri = new URL(url);
        const uddg = uri.searchParams.get('uddg');
        if (uddg) url = decodeURIComponent(uddg);
      } catch (_) { continue; }

      if (url.includes('duckduckgo.com') || url.includes('duck.com')) continue;

      let snippet = '';
      if (i < snippetMatches.length) {
        snippet = stripHtml(snippetMatches[i][1] || '').trim();
      }

      results.push({ title: rawTitle, url, snippet, img_src: null, publishedDate: null });
    }

    if (results.length === 0) {
      const liteResponse = await fetch(`https://lite.duckduckgo.com/lite/?q=${encodeURIComponent(query)}`, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      });
      if (liteResponse.ok) {
        const liteBody = await liteResponse.text();
        const rowRegex = /<a[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>/gs;
        for (const m of [...liteBody.matchAll(rowRegex)]) {
          if (results.length >= maxResults) break;
          let rawUrl = (m[1] || '').trim();
          const rawTitle = stripHtml(m[2] || '').trim();
          if (!rawTitle || !rawUrl) continue;
          const url = rawUrl.startsWith('//') ? 'https:' + rawUrl : rawUrl;
          if (url.includes('duckduckgo.com') || url.includes('duck.com')) continue;
          results.push({ title: rawTitle, url, snippet: '', img_src: null, publishedDate: null });
        }
      }
    }

    return results;
  } catch (e) {
    return [];
  }
}

function stripHtml(html) {
  return html
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .trim();
}

async function searchSearxng(query, category, maxResults) {
  const categories = category === 'all' ? 'general' : category === 'images' ? 'images' : category === 'videos' ? 'videos' : category === 'news' ? 'news' : 'general';

  for (const searxngUrl of SEARXNG_URLS) {
    try {
      const searchUrl = new URL(searxngUrl);
      searchUrl.searchParams.set('q', query);
      searchUrl.searchParams.set('format', 'json');
      searchUrl.searchParams.set('language', 'en');
      searchUrl.searchParams.set('pageno', '1');
      searchUrl.searchParams.set('categories', categories);

      const response = await fetch(searchUrl.toString(), {
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Navigwiz/1.0.0',
        },
      });

      if (!response.ok) {
        console.error(`SearXNG error on ${searxngUrl}: ${response.status}`);
        continue;
      }

      const data = await response.json();
      const rawResults = data.results || [];
      if (rawResults.length === 0) continue;

      return {
        results: rawResults.slice(0, maxResults || 50).map((r) => ({
          title: r.title || '',
          url: r.url || '',
          content: r.content || r.snippet || '',
          img_src: r.img_src || r.thumbnail_src || null,
          publishedDate: r.publishedDate || null,
        })),
        suggestions: (data.suggestions || []).map((s) => s.toString()).filter(Boolean),
        infoboxes: (data.infoboxes || []).map((ib) => ({
          title: ib.title || '',
          content: ib.content || '',
          url: ib.url || null,
          img_src: ib.img_src || null,
          attributes: (ib.attributes || []).map((a) => ({
            label: a.label || '',
            value: a.value || '',
          })),
        })),
        answers: (data.answers || []).map((a) => a.toString()).filter(Boolean),
        numberOfResults: data.number_of_results || null,
      };
    } catch (error) {
      console.error(`SearXNG proxy error on ${searxngUrl}:`, error.message);
      continue;
    }
  }

  return null;
}

async function handleSearch(request) {
  const url = new URL(request.url);
  const query = url.searchParams.get('q');
  if (!query) {
    return respondError('Missing query parameter', 400);
  }

  const category = url.searchParams.get('category') || 'all';

  const searxngResult = await searchSearxng(query, category, 50);
  if (searxngResult) {
    return respondJson({
      results: searxngResult.results,
      suggestions: searxngResult.suggestions,
      infoboxes: searxngResult.infoboxes,
      answers: searxngResult.answers,
      number_of_results: searxngResult.numberOfResults,
    });
  }

  if (category === 'all' || category === 'web') {
    const ddgHtmlResults = await duckDuckGoHtmlSearch(query, 20);
    if (ddgHtmlResults.length > 0) {
      return respondJson({
        results: ddgHtmlResults,
        suggestions: [],
        infoboxes: [],
        answers: [],
        number_of_results: null,
      });
    }

    const ddgApiResults = await duckDuckGoApiSearch(query, 10);
    if (ddgApiResults.length > 0) {
      return respondJson({
        results: ddgApiResults,
        suggestions: [],
        infoboxes: [],
        answers: [],
        number_of_results: null,
      });
    }
  }

  return respondJson({ results: [], suggestions: [], infoboxes: [], answers: [] });
}

async function handleImageProxy(request) {
  const url = new URL(request.url);
  const imageUrl = url.searchParams.get('url');
  if (!imageUrl) {
    return respondError('Missing url parameter', 400);
  }

  try {
    const response = await fetch(decodeURIComponent(imageUrl), {
      headers: {
        'User-Agent': 'Navigwiz/1.0.0',
      },
    });

    if (!response.ok) {
      return respondError('Image fetch failed', 502);
    }

    const buffer = await response.arrayBuffer();
    const contentType = response.headers.get('Content-Type') || 'image/jpeg';

    return new Response(buffer, {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=86400',
      },
    });
  } catch (error) {
    console.error('Image proxy error:', error.message);
    return respondError('Image proxy failed', 502);
  }
}

async function handleImage(request) {
  try {
    const body = await request.json();
    const prompt = body.prompt || body.message || '';
    const encoded = encodeURIComponent(prompt);

    async function tryPollinations(modelFlag) {
      const url = modelFlag
        ? `https://image.pollinations.ai/prompt/${encoded}?width=1024&height=1024${modelFlag}&nologo=true`
        : `https://image.pollinations.ai/prompt/${encoded}?width=1024&height=1024&nologo=true`;
      const resp = await fetch(url, { timeout: 30000 });
      if (!resp.ok) return null;
      const buffer = await resp.arrayBuffer();
      const b64 = btoa(String.fromCharCode(...new Uint8Array(buffer)));
      return b64;
    }

    let imageB64 = await tryPollinations('&model=flux');
    if (!imageB64) imageB64 = await tryPollinations('');
    if (!imageB64) {
      return respondError('Image generation failed. Please try again.', 502);
    }

    return respondJson({ response: prompt, image_data: imageB64, type: 'image_gen' });
  } catch (error) {
    console.error('Image handler error:', error.message);
    return respondError('Image generation failed. Please try again.', 502);
  }
}

async function handleRequest(request) {
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  const url = new URL(request.url);
  const path = url.pathname;

  switch (path) {
    case '/v1/chat':
    case '/api/chat':
      if (request.method !== 'POST') {
        return respondError('Method not allowed', 405);
      }
      return handleChat(request);

    case '/v1/image/generate':
      if (request.method !== 'POST') {
        return respondError('Method not allowed', 405);
      }
      return handleImage(request);

    case '/search':
      if (request.method !== 'GET') {
        return respondError('Method not allowed', 405);
      }
      return handleSearch(request);

    case '/image-proxy':
      if (request.method !== 'GET') {
        return respondError('Method not allowed', 405);
      }
      return handleImageProxy(request);

    default:
      return respondError('Not found', 404);
  }
}

export default {
  fetch: handleRequest,
};
