// Navigwiz Auth Worker — handles auth for navigwiz.acronous.com
const TOKEN_NAME = 'acronous_token';
const NAVIGWIZ_APP = 'https://navigwiz.pages.dev';
const LOGO_DATA = 'data:image/png;base64,' + "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";
function base64Url(buf) {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function base64UrlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  return Uint8Array.from(atob(str), c => c.charCodeAt(0));
}

function textEncode(s) { return new TextEncoder().encode(s); }
function textDecode(b) { return new TextDecoder().decode(b); }

async function createJWT(payload, secret) {
  const header = base64Url(textEncode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const now = Math.floor(Date.now() / 1000);
  const body = base64Url(textEncode(JSON.stringify({ ...payload, iat: now, exp: now + 604800 })));
  const data = header + '.' + body;
  const key = await crypto.subtle.importKey('raw', textEncode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, textEncode(data));
  return data + '.' + base64Url(sig);
}

async function verifyJWT(token, secret) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const key = await crypto.subtle.importKey('raw', textEncode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    const valid = await crypto.subtle.verify('HMAC', key, base64UrlDecode(parts[2]), textEncode(parts[0] + '.' + parts[1]));
    if (!valid) return null;
    const payload = JSON.parse(textDecode(base64UrlDecode(parts[1])));
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch { return null; }
}

async function hashPw(password, salt) {
  const hash = await crypto.subtle.digest('SHA-256', textEncode(password + salt));
  return base64Url(hash);
}

function userKey(email) { return `user:${email.toLowerCase()}`; }

async function getUser(email, env) {
  const raw = await env.AUTH_USERS.get(userKey(email));
  return raw ? JSON.parse(raw) : null;
}

async function saveUser(user, env) {
  await env.AUTH_USERS.put(userKey(user.email), JSON.stringify(user));
}

function corsResponse(body, status = 200, origin) {
  const headers = { 'Content-Type': 'application/json' };
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  headers['Access-Control-Allow-Credentials'] = 'true';
  return new Response(JSON.stringify(body), { status, headers });
}

function redirectResponse(location) {
  return new Response(null, { status: 302, headers: { Location: location } });
}

function setCookie(token, hostname) {
  const domain = hostname?.endsWith('acronous.com') ? 'Domain=.acronous.com; ' : '';
  return `${TOKEN_NAME}=${token}; ${domain}Path=/; Max-Age=604800; SameSite=Lax; Secure`;
}

function clearCookie(hostname) {
  const domain = hostname?.endsWith('acronous.com') ? 'Domain=.acronous.com; ' : '';
  return `${TOKEN_NAME}=; ${domain}Path=/; Max-Age=0`;
}

function getTokenFromReq(req) {
  const auth = req.headers.get('Authorization');
  if (auth?.startsWith('Bearer ')) return auth.slice(7);
  const cookie = req.headers.get('Cookie');
  if (cookie) {
    const m = cookie.match(new RegExp(`${TOKEN_NAME}=([^;]+)`));
    if (m) return decodeURIComponent(m[1]);
  }
  return null;
}

function escapeHtml(s) {
  return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

const AUTH_STYLE = `*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}:root{--bg:#08080c;--surface:#0f0f16;--surface-2:#181822;--border:#22223a;--text:#e0e0f0;--text-muted:#7878a0;--primary:#f59e0b;--primary-hover:#e08e00;--primary-glow:rgba(245,158,11,0.12);--accent-1:#f59e0b;--accent-2:#f87171;--error:#f87171;--success:#34d399;--radius:16px}html{font-size:16px}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);min-height:100vh;display:flex;align-items:center;justify-content:center;padding:1rem}.bg-glow{position:fixed;inset:0;pointer-events:none;overflow:hidden;z-index:0}.bg-glow::before{content:'';position:absolute;top:-30%;left:-10%;width:50%;height:60%;background:radial-gradient(circle,rgba(245,158,11,0.12) 0%,transparent 70%);border-radius:50%}.bg-glow::after{content:'';position:absolute;bottom:-30%;right:-10%;width:50%;height:60%;background:radial-gradient(circle,rgba(248,113,113,0.08) 0%,transparent 70%);border-radius:50%}.card{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:2.5rem;width:100%;max-width:420px;position:relative;z-index:1;backdrop-filter:blur(24px)}.logo{width:72px;height:72px;margin:0 auto 1.25rem;border-radius:18px;overflow:hidden;display:flex;align-items:center;justify-content:center;background:#0a0a0f;border:1px solid var(--border)}.logo img{width:48px;height:48px;object-fit:contain}h1{font-size:1.35rem;font-weight:700;text-align:center;margin-bottom:0.2rem;letter-spacing:-0.01em}.subtitle{text-align:center;color:var(--text-muted);margin-bottom:1.75rem;font-size:0.875rem}.form-group{margin-bottom:1rem}label{display:block;font-size:0.8rem;font-weight:500;margin-bottom:0.35rem;color:var(--text-muted);letter-spacing:0.01em;text-transform:uppercase}input{width:100%;padding:0.75rem 1rem;background:var(--surface-2);border:1px solid var(--border);border-radius:10px;color:var(--text);font-size:0.925rem;outline:none;transition:all 0.2s;font-family:inherit}input:focus{border-color:var(--primary);box-shadow:0 0 0 3px rgba(245,158,11,0.1)}input::placeholder{color:var(--text-muted);opacity:0.4}.btn{width:100%;padding:0.8rem;border:none;border-radius:10px;font-size:0.95rem;font-weight:600;cursor:pointer;transition:all 0.2s;background:linear-gradient(135deg,var(--primary),#f87171);color:white;font-family:inherit}.btn:hover{opacity:0.92;transform:translateY(-1px);box-shadow:0 4px 20px rgba(245,158,11,0.25)}.btn:active{transform:translateY(0)}.btn:disabled{opacity:0.4;cursor:not-allowed;transform:none;box-shadow:none}.spinner{width:18px;height:18px;border:2px solid rgba(255,255,255,0.2);border-top-color:white;border-radius:50%;animation:spin 0.6s linear infinite;flex-shrink:0;display:inline-block;vertical-align:middle;margin-right:0.4rem}@keyframes spin{to{transform:rotate(360deg)}}.error{background:rgba(248,113,113,0.08);border:1px solid rgba(248,113,113,0.15);border-radius:10px;padding:0.65rem 0.85rem;color:var(--error);font-size:0.85rem;margin-bottom:1rem;display:none;line-height:1.4}.error.show{display:block}.footer-text{text-align:center;margin-top:1.5rem;font-size:0.85rem;color:var(--text-muted)}.footer-text a{color:var(--accent-2);text-decoration:none;font-weight:600}.footer-text a:hover{text-decoration:underline;color:var(--primary)}`;

const LOGO_HTML = `<div class="logo"><img src="${LOGO_DATA}" alt="Navigwiz"></div>`;

const SCI_FI_STYLE = `
@keyframes scanline{0%{transform:translateY(-100%)}100%{transform:translateY(100vh)}}.scanlines{position:fixed;inset:0;pointer-events:none;z-index:10;overflow:hidden}.scanlines::before{content:'';position:absolute;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(245,158,11,0.03) 2px,rgba(245,158,11,0.03) 4px)}.scanlines::after{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,transparent,rgba(245,158,11,0.3),transparent);animation:scanline 3s linear infinite}
@keyframes flicker{0%,100%{opacity:1}50%{opacity:0.85}92%{opacity:1}}.glitch{animation:flicker 0.15s infinite}
@keyframes pulseGlow{0%,100%{filter:drop-shadow(0 0 8px rgba(245,158,11,0.4)) drop-shadow(0 0 20px rgba(245,158,11,0.15))}50%{filter:drop-shadow(0 0 15px rgba(245,158,11,0.6)) drop-shadow(0 0 40px rgba(245,158,11,0.25))}}
@keyframes spinSlow{to{transform:rotate(360deg)}}.hex-ring{position:absolute;width:140px;height:140px;border:1px solid rgba(245,158,11,0.1);border-radius:50%;animation:spinSlow 8s linear infinite}.hex-ring:nth-child(2){width:100px;height:100px;animation-direction:reverse;animation-duration:6s;border-color:rgba(248,113,113,0.08)}.hex-ring:nth-child(3){width:60px;height:60px;animation-duration:4s;border-color:rgba(245,158,11,0.06)}
@keyframes fillBar{to{width:100%}}.loading-bar{position:absolute;bottom:0;left:0;height:2px;background:linear-gradient(90deg,transparent,#f59e0b,#f87171,transparent);width:0;animation:fillBar 3.5s ease-in-out forwards}
@keyframes fadeUp{0%{opacity:0;transform:translateY(20px)}100%{opacity:1;transform:translateY(0)}}.boot-msg{font-family:'Courier New',monospace;font-size:0.7rem;color:rgba(120,120,160,0.6);position:absolute;bottom:3rem;left:50%;transform:translateX(-50%);white-space:nowrap}
@keyframes blink{0%,100%{opacity:1}50%{opacity:0}}.cursor-blink::after{content:'▌';animation:blink 0.8s step-end infinite;color:var(--primary);margin-left:2px}
@keyframes hexFloat{0%{transform:translateY(0) rotate(0deg);opacity:0}10%{opacity:0.15}90%{opacity:0.15}100%{transform:translateY(-100px) rotate(180deg);opacity:0}}.hex-bg{position:fixed;inset:0;pointer-events:none;z-index:0;overflow:hidden}.hex-bg span{position:absolute;bottom:-20px;font-size:1.2rem;color:rgba(245,158,11,0.06);animation:hexFloat 12s linear infinite}.hex-bg span:nth-child(1){left:10%;animation-duration:14s}.hex-bg span:nth-child(2){left:25%;animation-duration:10s;animation-delay:1s;font-size:0.9rem}.hex-bg span:nth-child(3){left:45%;animation-duration:16s;animation-delay:2s}.hex-bg span:nth-child(4){left:65%;animation-duration:11s;animation-delay:0.5s;font-size:0.8rem}.hex-bg span:nth-child(5){left:80%;animation-duration:13s;animation-delay:3s}.hex-bg span:nth-child(6){left:35%;animation-duration:15s;animation-delay:1.5s;font-size:1rem}
@keyframes loginFadeIn{0%{opacity:0;transform:scale(0.95)}100%{opacity:1;transform:scale(1)}}`;

function loginPage(redirect) {
  const rParam = redirect ? `?redirect=${encodeURIComponent(redirect)}` : '';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Navigwiz</title><style>${AUTH_STYLE}${SCI_FI_STYLE}</style></head><body>
<div class="hex-bg"><span>⬡</span><span>⬡</span><span>⬡</span><span>⬡</span><span>⬡</span><span>⬡</span></div>
<div class="scanlines"></div>
<div id="splash" style="position:fixed;inset:0;z-index:20;display:flex;flex-direction:column;align-items:center;justify-content:center;background:#08080c;transition:opacity 0.8s,transform 0.8s">
  <div style="position:relative;display:flex;align-items:center;justify-content:center;width:160px;height:160px;margin-bottom:2rem">
    <div class="hex-ring" style="position:absolute"></div>
    <div class="hex-ring" style="position:absolute"></div>
    <div class="hex-ring" style="position:absolute"></div>
    <div style="width:72px;height:72px;border-radius:18px;overflow:hidden;display:flex;align-items:center;justify-content:center;background:#0a0a0f;border:1px solid #22223a"><img src="${LOGO_DATA}" alt="Navigwiz" style="width:48px;height:48px;object-fit:contain;animation:pulseGlow 2s ease-in-out infinite"></div>
  </div>
  <h1 style="font-size:1.8rem;font-weight:800;letter-spacing:0.15em;color:#e0e0f0;margin-bottom:0.3rem" class="glitch">NAVIGWIZ</h1>
  <p style="font-size:0.75rem;color:rgba(120,120,160,0.5);letter-spacing:0.3em;text-transform:uppercase;margin-bottom:2.5rem">Security Gateway v2.0</p>
  <div style="width:200px;height:2px;background:rgba(34,34,58,0.5);border-radius:1px;overflow:hidden;margin-bottom:0.75rem"><div class="loading-bar" style="position:relative;height:100%;width:0;background:linear-gradient(90deg,#f59e0b,#f87171);border-radius:1px"></div></div>
  <p class="boot-msg" id="bootMsg" style="position:relative;bottom:auto;margin-top:0.5rem;font-family:'Courier New',monospace;font-size:0.7rem;color:rgba(120,120,160,0.6);white-space:nowrap"><span id="bootText" class="cursor-blink"></span></p>
</div>
<div id="loginContainer" style="display:none;animation:loginFadeIn 0.6s ease-out;width:100%;display:flex;align-items:center;justify-content:center">
<div class="bg-glow"></div>
<div class="card" style="animation:loginFadeIn 0.6s ease-out">${LOGO_HTML}<h1>Welcome back</h1><p class="subtitle">Sign in to your Navigwiz account</p><div id="error" class="error"></div><form id="loginForm" novalidate><div class="form-group"><label for="email">Email</label><input id="email" type="email" placeholder="you@example.com" required autocomplete="email" autocapitalize="off" spellcheck="false"></div><div class="form-group"><label for="password">Password</label><input id="password" type="password" placeholder="&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;" required autocomplete="current-password" minlength="6"></div><button type="submit" class="btn" id="submitBtn">Sign In</button></form><p class="footer-text">Don't have an account? <a href="/signup${rParam}">Create one</a></p></div>
</div>
<script>
(function(){var b=document.getElementById('splash'),l=document.getElementById('loginContainer'),bt=document.getElementById('bootText'),msgs=['INITIALIZING SECURE CONNECTION','LOADING AUTHENTICATION MODULES','ESTABLISHING ENCRYPTION','VERIFYING INTEGRITY','CONNECTING TO NAVIGWIZ GATEWAY','READY'],i=0;function showMsg(){if(i<msgs.length){bt.textContent=msgs[i]+'...';bt.className='cursor-blink';i++;setTimeout(showMsg,500)}else{bt.textContent='';bt.className='';setTimeout(function(){b.style.opacity='0';b.style.transform='scale(1.05)';setTimeout(function(){b.style.display='none';l.style.display='flex';l.style.animation='loginFadeIn 0.6s ease-out'},800)},300)}}showMsg();var e=document.getElementById('loginForm'),t=document.getElementById('email'),n=document.getElementById('password'),o=document.getElementById('error'),i2=document.getElementById('submitBtn'),r=new URLSearchParams(location.search).get('redirect')||'/';e.addEventListener('submit',async function(a){a.preventDefault();o.classList.remove('show');i2.disabled=true;i2.innerHTML='<span class="spinner"></span>Signing in...';try{var d=await fetch('/api/auth/login-redirect',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:t.value.trim(),password:n.value,redirect:r})}),s=await d.json();if(s.redirectUrl){window.location.href=s.redirectUrl}else{o.textContent=s.error||'Invalid email or password';o.classList.add('show');i2.disabled=false;i2.textContent='Sign In'}}catch(c){o.textContent='Connection error. Please try again.';o.classList.add('show');i2.disabled=false;i2.textContent='Sign In'}})})();
</script>
</body></html>`;
}

function signupPage(redirect) {
  const rParam = redirect ? `?redirect=${encodeURIComponent(redirect)}` : '';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Sign Up - Navigwiz</title><style>${AUTH_STYLE}</style></head><body><div class="bg-glow"></div><div class="card">${LOGO_HTML}<h1>Create your account</h1><p class="subtitle">One account for all Navigwiz products</p><div id="error" class="error"></div><form id="signupForm" novalidate><div class="form-group"><label for="name">Full Name</label><input id="name" type="text" placeholder="John Doe" autocomplete="name" autocapitalize="words"></div><div class="form-group"><label for="email">Email</label><input id="email" type="email" placeholder="you@example.com" required autocomplete="email" autocapitalize="off" spellcheck="false"></div><div class="form-group"><label for="password">Password</label><input id="password" type="password" placeholder="&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;&#xb7;" required minlength="6" autocomplete="new-password"></div><button type="submit" class="btn" id="submitBtn">Create Account</button></form><p class="footer-text">Already have an account? <a href="/login${rParam}">Sign in</a></p></div><script>
(function(){var e=document.getElementById('signupForm'),t=document.getElementById('name'),n=document.getElementById('email'),o=document.getElementById('password'),i=document.getElementById('error'),r=document.getElementById('submitBtn'),a=new URLSearchParams(location.search).get('redirect')||'/';e.addEventListener('submit',async function(d){d.preventDefault();i.classList.remove('show');r.disabled=true;r.innerHTML='<span class="spinner"></span>Creating account...';try{var s=await fetch('/api/auth/signup-redirect',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:n.value.trim(),password:o.value,name:t.value.trim()||n.value.split('@')[0],redirect:a})}),u=await s.json();if(u.redirectUrl){window.location.href=u.redirectUrl}else{i.textContent=u.error||'Sign up failed';i.classList.add('show');r.disabled=false;r.textContent='Create Account'}}catch(c){i.textContent='Connection error. Please try again.';i.classList.add('show');r.disabled=false;r.textContent='Create Account'}})})();
</script></body></html>`;
}

function dashboardPage(user, token) {
  const tokenParam = token ? `?token=${token}` : '';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Navigwiz</title><style>${AUTH_STYLE}.back-link{margin-bottom:1rem}.user-info{display:flex;align-items:center;justify-content:space-between;margin-bottom:1.5rem;padding-bottom:1.25rem;border-bottom:1px solid var(--border)}.user-details span{display:block}.user-details .name{font-weight:600;font-size:1rem}.user-details .email{font-size:0.8rem;color:var(--text-muted);margin-top:0.1rem}.btn-outline{background:transparent;border:1px solid var(--border);color:var(--text);padding:0.45rem 1rem;border-radius:8px;cursor:pointer;font-size:0.8rem;transition:all 0.2s;font-family:inherit}.btn-outline:hover{border-color:var(--error);color:var(--error)}.launch-btn{display:block;width:100%;padding:1rem;margin-top:1.5rem;border:none;border-radius:12px;font-size:1rem;font-weight:600;cursor:pointer;background:linear-gradient(135deg,var(--primary),#f87171);color:white;font-family:inherit;text-align:center;text-decoration:none;transition:all 0.2s}.launch-btn:hover{opacity:0.92;transform:translateY(-1px);box-shadow:0 4px 20px rgba(245,158,11,0.25)}
</style></head><body><div class="bg-glow"></div><div class="card" style="max-width:440px">${LOGO_HTML}<h1>Navigwiz</h1><div class="user-info"><div class="user-details"><span class="name">${escapeHtml(user.name)}</span><span class="email">${escapeHtml(user.email)}</span></div><button class="btn-outline" id="logoutBtn">Sign Out</button></div><p class="subtitle" style="text-align:left;margin-bottom:0">You are signed in</p><a class="launch-btn" href="${NAVIGWIZ_APP}${tokenParam}" id="launchBtn">Launch Navigwiz Browser</a></div><script>
(function(){document.getElementById('logoutBtn').addEventListener('click',async function(){await fetch('/api/auth/logout',{method:'POST'});window.location.href='/login'});var e=new URLSearchParams(location.search).get('token');if(e)document.getElementById('launchBtn').href='${NAVIGWIZ_APP}?token='+e})();
</script></body></html>`;
}

const NO_CACHE = { 'Cache-Control': 'private, no-cache, no-store, must-revalidate', 'Pragma': 'no-cache' };

async function handleAuthRequest(request, url, env) {
  const path = url.pathname;
  const method = request.method;
  const origin = request.headers.get('Origin') || 'https://navigwiz.acronous.com';
  const hostname = url.hostname;
  const jwtSecret = env.JWT_SECRET;

  if (path === '/api/auth/signup' && method === 'POST') {
    try {
      const { email, password, name } = await request.json();
      if (!email || !password) return corsResponse({ error: 'Email and password are required' }, 400, origin);
      if (password.length < 6) return corsResponse({ error: 'Password must be at least 6 characters' }, 400, origin);
      if (await getUser(email, env)) return corsResponse({ error: 'An account with this email already exists' }, 409, origin);
      const salt = crypto.randomUUID();
      const hashed = await hashPw(password, salt);
      const user = { id: crypto.randomUUID(), email: email.toLowerCase(), name: name || email.split('@')[0], salt, password: hashed, createdAt: new Date().toISOString() };
      await saveUser(user, env);
      const token = await createJWT({ id: user.id, email: user.email, name: user.name }, jwtSecret);
      const res = corsResponse({ success: true, token, user: { id: user.id, email: user.email, name: user.name } }, 200, origin);
      res.headers.append('Set-Cookie', setCookie(token, hostname));
      return res;
    } catch { return corsResponse({ error: 'Something went wrong. Please try again.' }, 500, origin); }
  }

  if (path === '/api/auth/signup-redirect' && method === 'POST') {
    try {
      const { email, password, name, redirect } = await request.json();
      if (!email || !password) return corsResponse({ error: 'Email and password are required' }, 400, origin);
      if (password.length < 6) return corsResponse({ error: 'Password must be at least 6 characters' }, 400, origin);
      if (await getUser(email, env)) return corsResponse({ error: 'An account with this email already exists' }, 409, origin);
      const salt = crypto.randomUUID();
      const hashed = await hashPw(password, salt);
      const user = { id: crypto.randomUUID(), email: email.toLowerCase(), name: name || email.split('@')[0], salt, password: hashed, createdAt: new Date().toISOString() };
      await saveUser(user, env);
      const token = await createJWT({ id: user.id, email: user.email, name: user.name }, jwtSecret);
      const target = (redirect || '/') + ((redirect || '').includes('?') ? '&' : '?') + 'token=' + token;
      const res = corsResponse({ success: true, redirectUrl: target, token }, 200, origin);
      res.headers.append('Set-Cookie', setCookie(token, hostname));
      return res;
    } catch { return corsResponse({ error: 'Authentication failed. Please try again.' }, 500, origin); }
  }

  if (path === '/api/auth/login' && method === 'POST') {
    try {
      const { email, password } = await request.json();
      if (!email || !password) return corsResponse({ error: 'Email and password are required' }, 400, origin);
      const user = await getUser(email, env);
      if (!user) return corsResponse({ error: 'Invalid email or password' }, 401, origin);
      const hashed = await hashPw(password, user.salt);
      if (hashed !== user.password) return corsResponse({ error: 'Invalid email or password' }, 401, origin);
      const token = await createJWT({ id: user.id, email: user.email, name: user.name }, jwtSecret);
      const res = corsResponse({ success: true, token, user: { id: user.id, email: user.email, name: user.name } }, 200, origin);
      res.headers.append('Set-Cookie', setCookie(token, hostname));
      return res;
    } catch { return corsResponse({ error: 'Something went wrong. Please try again.' }, 500, origin); }
  }

  if (path === '/api/auth/login-redirect' && method === 'POST') {
    try {
      const { email, password, redirect } = await request.json();
      if (!email || !password) return corsResponse({ error: 'Email and password are required' }, 400, origin);
      const user = await getUser(email, env);
      if (!user) return corsResponse({ error: 'Invalid email or password' }, 401, origin);
      const hashed = await hashPw(password, user.salt);
      if (hashed !== user.password) return corsResponse({ error: 'Invalid email or password' }, 401, origin);
      const token = await createJWT({ id: user.id, email: user.email, name: user.name }, jwtSecret);
      const target = (redirect || '/') + ((redirect || '').includes('?') ? '&' : '?') + 'token=' + token;
      const res = corsResponse({ success: true, redirectUrl: target, token }, 200, origin);
      res.headers.append('Set-Cookie', setCookie(token, hostname));
      return res;
    } catch { return corsResponse({ error: 'Something went wrong. Please try again.' }, 500, origin); }
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    const res = corsResponse({ success: true }, 200, origin);
    res.headers.append('Set-Cookie', clearCookie(hostname));
    return res;
  }

  if (path === '/api/auth/verify') {
    const token = getTokenFromReq(request);
    if (!token) return corsResponse({ valid: false }, 200, origin);
    const decoded = await verifyJWT(token, jwtSecret);
    if (!decoded) return corsResponse({ valid: false }, 200, origin);
    return corsResponse({ valid: true, user: { id: decoded.id, email: decoded.email, name: decoded.name } }, 200, origin);
  }

  if (path === '/api/auth/me') {
    const token = getTokenFromReq(request);
    if (!token) return corsResponse({ error: 'Not authenticated' }, 401, origin);
    const decoded = await verifyJWT(token, jwtSecret);
    if (!decoded) return corsResponse({ error: 'Not authenticated' }, 401, origin);
    return corsResponse({ user: { id: decoded.id, email: decoded.email, name: decoded.name } }, 200, origin);
  }

  function htmlResponse(body) {
    return new Response(body, { headers: { 'Content-Type': 'text/html;charset=utf-8', ...NO_CACHE } });
  }

  if (path === '/' || path === '/login' || path === '/login.html') {
    const token = getTokenFromReq(request);
    if (token) {
      const decoded = await verifyJWT(token, jwtSecret);
      if (decoded) {
        // Already authenticated — redirect to the Navigwiz app
        const appUrl = env.NAVIGWIZ_APP_URL || NAVIGWIZ_APP;
        const sep = appUrl.includes('?') ? '&' : '?';
        return redirectResponse(appUrl + sep + 'token=' + token);
      }
    }
    const redirect = url.searchParams.get('redirect') || '';
    return htmlResponse(loginPage(redirect));
  }

  if (path === '/signup' || path === '/signup.html') {
    const token = getTokenFromReq(request);
    if (token) {
      const decoded = await verifyJWT(token, jwtSecret);
      if (decoded) {
        const sep = (url.searchParams.get('redirect') || '/').includes('?') ? '&' : '?';
        return redirectResponse((url.searchParams.get('redirect') || '/') + sep + 'token=' + token);
      }
    }
    return htmlResponse(signupPage(url.searchParams.get('redirect') || ''));
  }

  if (path === '/dashboard' || path === '/dashboard.html') {
    const token = getTokenFromReq(request);
    if (!token) return redirectResponse('/login?redirect=' + encodeURIComponent(url.pathname));
    const decoded = await verifyJWT(token, jwtSecret);
    if (!decoded) return redirectResponse('/login?redirect=' + encodeURIComponent(url.pathname));
    return htmlResponse(dashboardPage(decoded, token));
  }

  if (path === '/logout') {
    const res = redirectResponse('/login');
    res.headers.append('Set-Cookie', clearCookie(hostname));
    return res;
  }

  if (path === '/health') {
    return corsResponse({ status: 'ok' }, 200, origin);
  }

  // Non-auth routes: proxy to the Navigwiz app
  const appUrl = env.NAVIGWIZ_APP_URL || NAVIGWIZ_APP;
  const targetUrl = appUrl + url.pathname + url.search;
  const token = getTokenFromReq(request);
  const headers = new Headers(request.headers);
  if (token) headers.set('X-Acro-Token', token);
  try {
    const proxyRes = await fetch(new Request(targetUrl, {
      method: request.method,
      headers,
      body: request.body,
    }));
    if (proxyRes.status === 404) {
      const indexRes = await fetch(appUrl + '/index.html');
      return new Response(indexRes.body, { status: 200, headers: indexRes.headers });
    }
    return new Response(proxyRes.body, { status: proxyRes.status, headers: proxyRes.headers });
  } catch {
    return new Response('Service unavailable', { status: 502 });
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      const origin = request.headers.get('Origin') || 'https://navigwiz.acronous.com';
      return new Response(null, { headers: {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Credentials': 'true',
        'Access-Control-Max-Age': '86400',
      }});
    }

    if (!env?.JWT_SECRET) {
      if (url.pathname === '/health') return corsResponse({ status: 'ok' }, 200);
      return corsResponse({ error: 'Authentication not configured' }, 500);
    }

    // Handle ?token=xxx from URL (passed by auth dashboard via SSO redirect)
    const urlToken = url.searchParams.get('token');
    if (urlToken) {
      const decoded = await verifyJWT(urlToken, env.JWT_SECRET);
      if (decoded) {
        url.searchParams.delete('token');
        const cleanPath = url.pathname + url.search + url.hash;
        const res = redirectResponse(cleanPath);
        res.headers.append('Set-Cookie', setCookie(urlToken, url.hostname));
        return res;
      }
    }

    return handleAuthRequest(request, url, env);
  },
};
