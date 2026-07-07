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

function isSimpleQuery(query) {
  const wordCount = query.trim().split(/\s+/).length;
  const simplePatterns = [
    /^[a-zA-Z\s]+$/,
    /(what is|who is|when is|where is|why is|how much|how many|how does|how can)/i,
    /(^|\s)(hi|hello|hey|greetings)/,
    /(please|can you|could you|help me|assist me)/i,
    /clarify|tell me|explain|define|meaning of/i,
  ];

  const isShort = wordCount <= 6;
  const isQuestion = query.includes('?');
  const hasSimplePattern = simplePatterns.some((pattern) => pattern.test(query));
  const onlyLetters = /^[a-zA-Z\s]+$/i.test(query);

  return isShort && isQuestion && (hasSimplePattern || onlyLetters);
}

async function duckDuckGoApiSearch(query, maxResults = 8) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000);
    const response = await fetch(
      `https://api.duckduckgo.com/?q=${encodeURIComponent(query)}&format=json&no_html=1&skip_disambig=1`,
      {
        headers: { 'User-Agent': 'AcronousAI/1.0.0' },
        signal: controller.signal,
      }
    );
    clearTimeout(timeoutId);

    if (!response.ok) return [];
    const data = await response.json();
    const results = [];
    if (data.AbstractText && data.AbstractURL) {
      results.push({
        title: data.Heading || query,
        url: data.AbstractURL,
        snippet: data.AbstractText,
      });
    }
    if (data.RelatedTopics) {
      for (const topic of data.RelatedTopics) {
        if (results.length >= maxResults) break;
        if (topic.Text && topic.FirstURL) {
          results.push({
            title: topic.Text.split(' - ')[0],
            url: topic.FirstURL,
            snippet: topic.Text,
          });
        }
        if (topic.Topics) {
          for (const sub of topic.Topics) {
            if (results.length >= maxResults) break;
            if (sub.Text && sub.FirstURL) {
              results.push({
                title: sub.Text.split(' - ')[0],
                url: sub.FirstURL,
                snippet: sub.Text,
              });
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
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 45000);

    const response = await fetch(`${DDG_HTML_URL}?q=${encodeURIComponent(query)}`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: controller.signal,
    });
    clearTimeout(timeoutId);

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
      } catch (_) {
        continue;
      }

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
          'User-Agent': 'AcronousAI/1.0.0',
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

async function searchFromWeb(query, maxResults = 10) {
  let searchResults = [];

  const searxngResult = await searchSearxng(query, 'all', maxResults);
  if (searxngResult) {
    searchResults = searxngResult.results || [];
  }

  if (searchResults.length < maxResults / 2) {
    const ddgHtmlResults = await duckDuckGoHtmlSearch(query, maxResults);
    if (ddgHtmlResults && ddgHtmlResults.length > 0) {
      const processed = ddgHtmlResults.map((r) => ({
        title: r.title,
        url: r.url,
        content: r.snippet,
        img_src: r.img_src || null,
        publishedDate: r.publishedDate || null,
      }));
      searchResults = [...processed, ...searchResults].slice(0, maxResults);
    }
  }

  if (searchResults.length < maxResults / 2) {
    const ddgApiResults = await duckDuckGoApiSearch(query, maxResults);
    if (ddgApiResults && ddgApiResults.length > 0) {
      const processed = ddgApiResults.map((r) => ({
        title: r.title,
        url: r.url,
        content: r.snippet,
        img_src: null,
        publishedDate: null,
      }));
      searchResults = [...processed, ...searchResults].slice(0, maxResults);
    }
  }

  return searchResults;
}

async function handleChat(request, env) {
  try {
    const apiKey = env.OPENAI_API_KEY || env.OPENROUTER_API_KEY || env.GOOGLE_API_KEY;
    if (!apiKey) {
      return respondError('AI API key not configured on server.', 500);
    }

    const body = await request.json();
    const userMessage = body.message || body.query || '';
    const isSimple = isSimpleQuery(userMessage);

    let searchResults = [];
    let enhancedMessage = userMessage;
    if (env.SEARCH_ENABLED !== false) {
      searchResults = await searchFromWeb(userMessage, 5);
      if (searchResults.length > 0) {
        const context = searchResults.map((r) => `- ${r.title}\n  URL: ${r.url}\n  ${r.content || r.snippet}`).join('\n\n');
        enhancedMessage = `User query: ${userMessage}\n\nCurrent web search results:\n${context}\n\nPlease answer based on the above search results and your knowledge. Cite sources by URL.`;
      }
    }

    const openaiBody = {
      model: body.model || (isSimple ? 'openai/gpt-4o-mini' : 'openai/gpt-4o'),
      messages: [
        {
          role: 'system',
          content: isSimple
            ? 'You are Acronous AI - a fast AI assistant. Give direct, concise answers. For simple questions, be brief and to the point. Provide quick, useful information.'
            : 'You are Acronous AI - an advanced AI assistant. Analyze complex queries thoroughly, consider multiple aspects, and provide detailed, well-reasoned responses. Use search context when available.',
        },
        { role: 'user', content: enhancedMessage },
      ],
      max_tokens: isSimple ? 1024 : 4096,
    };

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://ai.acronous.com',
        'X-Title': 'Acronous AI',
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

    return respondJson({
      response: content,
      session_id: body.session_id || '',
      type: 'chat',
      is_simple: isSimple,
      sources_count: searchResults.length,
    });
  } catch (error) {
    console.error('Chat handler error:', error.message);
    return respondError('I could not complete that request. Please try again.', 502);
  }
}

async function handleImageEdit(request, env) {
  try {
    const apiKey = env.OPENAI_API_KEY || env.OPENROUTER_API_KEY;
    if (!apiKey) {
      return respondError('AI API key not configured on server.', 500);
    }

    const body = await request.json();
    const base64Data = body.image_data || body.image;
    const prompt = body.prompt || '';

    if (!base64Data) {
      return respondError('No image data provided', 400);
    }

    const enhancedPrompt = `Cut only the specific part of this image that matches the request: "${prompt}" and replace it with the requested content. Do NOT recreate the entire image, just edit the specific portion. Make it look natural and seamless. Only edit what was specifically requested in the prompt, do not add extra elements or completely transform the image. The output should show only the requested edit, not a completely new image.`;

    const baseImagePrompt = `${enhancedPrompt} Return exactly the edited image, not a description.`;

    const openaiBody = {
      model: 'openai/gpt-4o',
      messages: [
        {
          role: 'system',
          content:
            'You are an image editing AI. You receive image data and edit requests. ONLY make the exact edits requested in the user prompt. Do NOT recreate the entire image, do NOT change elements not mentioned in the prompt, do NOT add new objects, do NOT transform the style. ONLY perform the specific edits mentioned. If the edit is unclear, ask for clarification. Always respond with the edited image only, not descriptions.',
        },
        {
          role: 'user',
          content: [
            {
              role: 'user',
              content: [
                {
                  type: 'text',
                  text: baseImagePrompt,
                },
                {
                  type: 'image_url',
                  image_url: {
                    url: base64Data,
                  },
                },
              ],
            },
          ],
        },
      ],
      max_tokens: 4096,
    };

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify(openaiBody),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`OpenAI API error: ${response.status}`, text);
      return respondError('Image editing service error. Please try again.', 502);
    }

    const data = await response.json();
    const result = data.choices?.[0]?.message?.content || '';

    return respondJson({
      response: result,
      type: 'image_edit',
      edit_type: 'cut_and_replace',
      prompt_used: baseImagePrompt,
    });
  } catch (error) {
    console.error('Image edit handler error:', error.message);
    return respondError('Image editing failed. Please try again.', 502);
  }
}

async function handleRequest(request, env) {
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
      return handleChat(request, env);

    case '/v1/image/edit':
      if (request.method !== 'POST') {
        return respondError('Method not allowed', 405);
      }
      return handleImageEdit(request, env);

    case '/health':
      if (request.method === 'GET') {
        return respondJson({
          status: 'ok',
          timestamp: Date.now(),
          uptime: Math.floor(process.uptime()),
        });
      }
      return respondError('Method not allowed', 405);

    default:
      return respondError('Not found', 404);
  }
}

export default {
  fetch: handleRequest,
};