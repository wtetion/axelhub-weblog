const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, X-Axel-Api-Key, X-Axel-User-Key, X-Axel-Mutation-Token',
  'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS',
};
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 30;
const STALE_AFTER_MS = 45000;
const MAX_EVENTS = 2000;
const MAX_GRAPH_POINTS = 5000;
const PUBLIC_BASE_FALLBACK = 'https://axelhub-api.workers.dev';

const json = (data, status = 200, extra = {}) => new Response(JSON.stringify(data), {
  status,
  headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS, ...extra },
});
const htmlish = new Set(['/login', '/signup']);
const enc = new TextEncoder();
const b64u = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const b64uText = (s) => b64u(enc.encode(s));
const unb64u = (s) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - (s.length % 4)) % 4)), c => c.charCodeAt(0));
const str = (v, fallback = '') => v == null ? fallback : String(v);
const num = (v, fallback = 0) => Number.isFinite(Number(v)) ? Number(v) : fallback;
const now = () => Date.now();
const uid = () => crypto.randomUUID();

async function sha256Hex(value) {
  const d = await crypto.subtle.digest('SHA-256', enc.encode(String(value)));
  return [...new Uint8Array(d)].map(x => x.toString(16).padStart(2, '0')).join('');
}
async function hmacHex(secret, value) {
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(value));
  return [...new Uint8Array(sig)].map(x => x.toString(16).padStart(2, '0')).join('');
}
async function passwordRecord(password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const baseKey = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations: 210000, hash: 'SHA-256' }, baseKey, 256);
  return { salt: b64u(salt), hash: b64u(bits) };
}
async function verifyPassword(password, user) {
  try {
    const baseKey = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
    const salt = unb64u(user.password_salt);
    const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations: 210000, hash: 'SHA-256' }, baseKey, 256);
    const a = b64u(bits);
    return a === user.password_hash;
  } catch { return false; }
}
function cookieMap(request) {
  const out = {};
  for (const part of (request.headers.get('Cookie') || '').split(';')) {
    const i = part.indexOf('=');
    if (i > 0) out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}
async function signSession(secret, userId, issuedAt) {
  const payload = `${userId}.${issuedAt}`;
  return `${b64uText(payload)}.${await hmacHex(secret, payload)}`;
}
async function getSessionUser(request, env) {
  const token = cookieMap(request).axel_session || '';
  const [payload64, sig] = token.split('.');
  if (!payload64 || !sig) return null;
  try {
    const payload = new TextDecoder().decode(unb64u(payload64));
    const [userId, issuedRaw] = payload.split('.');
    const issued = Number(issuedRaw);
    if (!userId || !Number.isFinite(issued) || now() - issued > SESSION_TTL_MS) return null;
    const expected = await hmacHex(env.AUTH_SECRET, payload);
    if (sig.length !== expected.length) return null;
    let diff = 0; for (let i = 0; i < expected.length; i++) diff |= sig.charCodeAt(i) ^ expected.charCodeAt(i);
    if (diff !== 0) return null;
    const row = await env.DB.prepare('SELECT * FROM users WHERE id = ? AND status = \'active\'').bind(userId).first();
    return row || null;
  } catch { return null; }
}
async function sessionCookie(env, userId) {
  const token = await signSession(env.AUTH_SECRET, userId, now());
  return `axel_session=${encodeURIComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Secure; Max-Age=${Math.floor(SESSION_TTL_MS / 1000)}`;
}
function clearCookie() { return 'axel_session=; Path=/; HttpOnly; SameSite=Lax; Secure; Max-Age=0'; }
function publicUser(user, env, origin = '') {
  const base = (str(env.PUBLIC_BASE_URL) || origin || PUBLIC_BASE_FALLBACK).replace(/\/$/, '');
  return { userId: user.id, username: user.username, telemetryKey: user.telemetry_key, publicUrl: base };
}
async function requireWebAuth(request, env) {
  const user = await getSessionUser(request, env);
  return user || null;
}
async function authTelemetry(request, env) {
  const supplied = request.headers.get('x-axel-api-key') || request.headers.get('x-axel-user-key') || '';
  if (!supplied) return null;
  const row = await env.DB.prepare('SELECT * FROM users WHERE telemetry_key = ? AND status = \'active\'').bind(supplied).first();
  return row || null;
}
function normalizeInventoryItems(items) {
  if (!Array.isArray(items)) return [];
  return items.slice(0, 200).map(x => ({
    name: str(x.name || x.eggName, 'Unknown Egg'),
    rarity: str(x.rarity || x.rarityName || x.rarityType, 'Unknown'),
    rarityColor: str(x.rarityColor, '#6B7280'),
    mutation: str(x.mutation, 'Normal'),
    count: Math.max(1, num(x.count, 1)),
    finalValue: x.finalValue == null ? null : num(x.finalValue),
    uid: x.uid ? str(x.uid) : undefined,
  }));
}
function normalizeTelemetry(body) {
  const inventory = body.inventory || {};
  const stats = body.stats || {};
  return {
    account: str(body.account || body.username || body.name || body.displayName, 'Unknown'),
    displayName: str(body.displayName, str(body.account || body.username || body.name, 'Unknown')),
    device: str(body.device, '').toLowerCase() === 'mobile' ? 'Mobile' : 'PC',
    pc: body.pc == null ? '' : str(body.pc, ''),
    money: num(body.money ?? stats.money), speed: num(body.speed ?? stats.speed),
    eggInventory: num(body.eggInventory ?? inventory.eggs), eggCapacity: num(body.eggCapacity ?? inventory.eggCapacity),
    petInventory: num(body.petInventory ?? inventory.pets), petCapacity: num(body.petCapacity ?? inventory.petCapacity),
    baseLevel: body.baseLevel ?? body.baseTier ?? stats.baseLevel ?? stats.baseTier ?? inventory.baseLevel ?? 0,
    treadmillLevel: body.treadmillLevel ?? body.treadmillTier ?? stats.treadmillLevel ?? stats.treadmillTier ?? inventory.treadmillLevel ?? 0,
    eggsStolen: num(body.eggsStolen), petsHatched: num(body.petsHatched),
    eggItems: normalizeInventoryItems(body.eggItems || inventory.eggItems),
    currentEvent: 'No Event', currentArea: str(body.currentArea || body.area || '', ''),
    activity: str(body.activity || body.action || body.statusText, 'Idle'),
    activityDetail: str(body.activityDetail || body.actionDetail, ''),
    latestStolenEgg: body.latestStolenEgg && typeof body.latestStolenEgg === 'object' ? {
      name: str(body.latestStolenEgg.name, 'Unknown Egg'), rarity: str(body.latestStolenEgg.rarity, 'Unknown'),
      rarityColor: str(body.latestStolenEgg.rarityColor, '#6B7280'), mutation: str(body.latestStolenEgg.mutation, 'Normal'),
      imageUrl: str(body.latestStolenEgg.imageUrl, ''), finalValue: body.latestStolenEgg.finalValue == null ? null : num(body.latestStolenEgg.finalValue),
      area: str(body.latestStolenEgg.area, ''), stolenAt: str(body.latestStolenEgg.stolenAt, ''),
    } : null,
    jobId: str(body.jobId || body.jobID, 'Unknown'), placeId: str(body.placeId, ''), uptimeSeconds: num(body.uptimeSeconds),
    status: 'online', lastSeen: new Date().toISOString(), updatedAt: now(),
  };
}
function publicAccount(account) { return { ...account, live: now() - account.updatedAt <= STALE_AFTER_MS }; }

async function getMeta(env, userId) {
  let row = await env.DB.prepare('SELECT * FROM site_meta WHERE user_id = ?').bind(userId).first();
  if (!row) {
    await env.DB.prepare('INSERT INTO site_meta (user_id, started_at, reset_stolen_base) VALUES (?, ?, ?)').bind(userId, now(), '{}').run();
    row = await env.DB.prepare('SELECT * FROM site_meta WHERE user_id = ?').bind(userId).first();
  }
  if (now() - Number(row.started_at) >= 30 * 60 * 1000) {
    const accounts = await env.DB.prepare('SELECT account, data_json FROM accounts WHERE user_id = ?').bind(userId).all();
    const reset = {};
    for (const r of accounts.results) {
      try { reset[r.account] = num(JSON.parse(r.data_json).eggsStolen); } catch {}
    }
    await env.DB.prepare('UPDATE site_meta SET started_at = ?, reset_stolen_base = ? WHERE user_id = ?').bind(now(), JSON.stringify(reset), userId).run();
    row.started_at = now(); row.reset_stolen_base = JSON.stringify(reset);
  }
  return row;
}
async function buildGraphPoint(env, userId, account, previous) {
  const meta = await getMeta(env, userId);
  const reset = JSON.parse(meta.reset_stolen_base || '{}');
  if (reset[account.account] == null) reset[account.account] = num(account.eggsStolen);
  let moneyPerSecond = 0, stolenDelta = 0;
  if (previous && Number.isFinite(Number(previous.updatedAt))) {
    const dt = Math.max(0.001, (now() - Number(previous.updatedAt)) / 1000);
    moneyPerSecond = Math.max(0, (num(account.money) - num(previous.money)) / dt);
    stolenDelta = Math.max(0, num(account.eggsStolen) - num(previous.eggsStolen));
  }
  await env.DB.prepare('UPDATE site_meta SET reset_stolen_base = ? WHERE user_id = ?').bind(JSON.stringify(reset), userId).run();
  await env.DB.prepare('INSERT INTO graph_points (user_id, t, account, display_name, speed, money_per_second, eggs_stolen) VALUES (?, ?, ?, ?, ?, ?, ?)')
    .bind(userId, now(), account.account, account.displayName, num(account.speed), moneyPerSecond, Math.max(0, num(account.eggsStolen) - num(reset[account.account])))
    .run();
  await env.DB.prepare('DELETE FROM graph_points WHERE user_id = ? AND id NOT IN (SELECT id FROM graph_points WHERE user_id = ? ORDER BY id DESC LIMIT ?)').bind(userId, userId, MAX_GRAPH_POINTS).run();
  return { moneyPerSecond, stolenDelta };
}
async function mutationToken(env, userId) { return sha256Hex(`${env.AUTH_SECRET}|delete|${userId}`); }

async function handleApi(request, env, url) {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
  if (url.pathname === '/api/health' && request.method === 'GET') return json({ ok: true, service: 'Axel Web Log (Cloudflare Worker)', now: new Date().toISOString() });

  if (url.pathname === '/api/auth/signup' && request.method === 'POST') {
    const body = await request.json().catch(() => ({}));
    const username = str(body.username).trim(), password = str(body.password);
    if (!/^[A-Za-z0-9._-]{3,32}$/.test(username)) return json({ ok: false, error: 'username_must_be_3_to_32_chars' }, 400);
    if (password.length < 8 || password.length > 200) return json({ ok: false, error: 'password_must_be_8_to_200_chars' }, 400);
    const taken = await env.DB.prepare('SELECT id FROM users WHERE lower(username) = lower(?)').bind(username).first();
    if (taken) return json({ ok: false, error: 'username_taken' }, 409);
    const id = uid(), telemetryKey = `axel_${crypto.randomUUID().replace(/-/g, '')}${crypto.randomUUID().replace(/-/g, '')}`.slice(0, 61);
    const pw = await passwordRecord(password);
    await env.DB.prepare('INSERT INTO users (id, username, password_hash, password_salt, telemetry_key, created_at, status) VALUES (?, ?, ?, ?, ?, ?, \'active\')')
      .bind(id, username, pw.hash, pw.salt, telemetryKey, new Date().toISOString()).run();
    await env.DB.prepare('INSERT INTO site_meta (user_id, started_at, reset_stolen_base) VALUES (?, ?, ?)').bind(id, now(), '{}').run();
    return json({ ok: true, user: publicUser({ id, username, telemetry_key: telemetryKey }, env, new URL(request.url).origin) }, 200, { 'Set-Cookie': await sessionCookie(env, id) });
  }
  if (url.pathname === '/api/auth/login' && request.method === 'POST') {
    const body = await request.json().catch(() => ({}));
    const username = str(body.username).trim(), password = str(body.password);
    const user = await env.DB.prepare('SELECT * FROM users WHERE lower(username) = lower(?)').bind(username).first();
    if (!user || user.status === 'disabled' || !(await verifyPassword(password, user))) return json({ ok: false, error: 'invalid_credentials' }, 401);
    return json({ ok: true, user: publicUser(user, env, new URL(request.url).origin) }, 200, { 'Set-Cookie': await sessionCookie(env, user.id) });
  }
  if (url.pathname === '/api/auth/logout' && request.method === 'POST') return json({ ok: true }, 200, { 'Set-Cookie': clearCookie() });
  if (url.pathname === '/api/auth/me' && request.method === 'GET') {
    const user = await getSessionUser(request, env); if (!user) return json({ ok: false, error: 'login_required' }, 401); return json({ ok: true, user: publicUser(user, env, new URL(request.url).origin) });
  }

  const user = await requireWebAuth(request, env);
  if (!user) {
    if (url.pathname.startsWith('/api/')) return json({ ok: false, error: 'login_required' }, 401);
  }
  if (url.pathname === '/api/context' && request.method === 'GET') {
    return json({ ok: true, siteId: user.id, siteUrl: str(env.PUBLIC_BASE_URL, request.url.split('/api/context')[0]), mutationToken: await mutationToken(env, user.id), user: publicUser(user, env, new URL(request.url).origin) });
  }
  if (url.pathname === '/api/accounts' && request.method === 'GET') {
    const rows = await env.DB.prepare('SELECT data_json FROM accounts WHERE user_id = ? ORDER BY updated_at DESC').bind(user.id).all();
    const accounts = rows.results.map(r => publicAccount(JSON.parse(r.data_json)));
    return json({ ok: true, siteId: user.id, players: accounts.length, servers: new Set(accounts.map(a => a.jobId).filter(Boolean)).size, events: Number((await env.DB.prepare('SELECT COUNT(*) c FROM events WHERE user_id = ?').bind(user.id).first()).c || 0), joins: 0, accounts });
  }
  if (url.pathname === '/api/analytics' && request.method === 'GET') {
    const rows = await env.DB.prepare('SELECT data_json FROM accounts WHERE user_id = ?').bind(user.id).all();
    const accounts = rows.results.map(r => JSON.parse(r.data_json)), live = accounts.filter(a => now() - a.updatedAt <= STALE_AFTER_MS);
    const sums = accounts.reduce((s,a) => ({ eggInventory:s.eggInventory+num(a.eggInventory), petInventory:s.petInventory+num(a.petInventory), eggsStolen:s.eggsStolen+num(a.eggsStolen), money:s.money+num(a.money) }), { eggInventory:0, petInventory:0, eggsStolen:0, money:0 });
    const ev = Number((await env.DB.prepare('SELECT COUNT(*) c FROM events WHERE user_id = ?').bind(user.id).first()).c || 0);
    return json({ ok:true, siteId:user.id, players:accounts.length, livePlayers:live.length, servers:new Set(accounts.map(a=>a.jobId).filter(Boolean)).size, events:ev, joins:0, totalEggInventory:sums.eggInventory, totalPetInventory:sums.petInventory, totalEggsStolen:sums.eggsStolen, totalMoney:sums.money, currentEvent:'No Event', currentArea:live[0]?.currentArea||'', currentActivity:live[0]?.activity||'Idle', currentActivityDetail:live[0]?.activityDetail||'' });
  }
  if (url.pathname === '/api/graph' && request.method === 'GET') {
    const accountFilter = str(url.searchParams.get('account') || '');
    const meta = await getMeta(env, user.id);
    const rows = accountFilter
      ? await env.DB.prepare('SELECT * FROM graph_points WHERE user_id = ? AND account = ? ORDER BY t ASC').bind(user.id, accountFilter).all()
      : await env.DB.prepare('SELECT * FROM graph_points WHERE user_id = ? ORDER BY t ASC').bind(user.id).all();
    const latest = new Map(); for (const r of rows.results) latest.set(r.account, r);
    const summary = { speed:0, moneyPerSecond:0, eggsStolen:0 }; for (const p of latest.values()) { summary.speed += num(p.speed); summary.moneyPerSecond += num(p.money_per_second); summary.eggsStolen += num(p.eggs_stolen); }
    const accountRows = await env.DB.prepare('SELECT account, data_json FROM accounts WHERE user_id = ?').bind(user.id).all();
    const accounts = accountRows.results.map(r => { const a = JSON.parse(r.data_json); return { account:a.account, displayName:a.displayName||a.account }; });
    return json({ ok:true, siteId:user.id, resetAt:new Date(Number(meta.started_at)+30*60*1000).toISOString(), startedAt:new Date(Number(meta.started_at)).toISOString(), account:accountFilter, accounts, summary, series:rows.results.map(p=>({t:p.t,account:p.account,displayName:p.display_name,speed:num(p.speed),moneyPerSecond:num(p.money_per_second),eggsStolen:num(p.eggs_stolen)})) });
  }
  if (url.pathname === '/api/events' && request.method === 'GET') {
    const rows = await env.DB.prepare('SELECT payload_json FROM events WHERE user_id = ? ORDER BY created_at DESC LIMIT 250').bind(user.id).all();
    return json({ ok:true, siteId:user.id, events:rows.results.map(r => JSON.parse(r.payload_json)) });
  }
  if (url.pathname === '/api/inventory' && request.method === 'GET') {
    const rows = await env.DB.prepare('SELECT data_json FROM accounts WHERE user_id = ? ORDER BY updated_at DESC').bind(user.id).all();
    const accounts = rows.results.map(r=>{const a=JSON.parse(r.data_json);return {...a,currentEvent:'No Event',live:now()-a.updatedAt<=STALE_AFTER_MS};});
    return json({ ok:true, siteId:user.id, accounts });
  }
  if (url.pathname === '/api/telemetry' && request.method === 'POST') {
    const telemetryUser = await authTelemetry(request, env);
    if (!telemetryUser) return json({ ok:false, error:'invalid_telemetry_key' }, 401);
    const body = await request.json().catch(() => ({}));
    const account = normalizeTelemetry(body);
    const prevRow = await env.DB.prepare('SELECT data_json FROM accounts WHERE user_id = ? AND account = ?').bind(telemetryUser.id, account.account).first();
    const previous = prevRow ? JSON.parse(prevRow.data_json) : null;
    const graph = await buildGraphPoint(env, telemetryUser.id, account, previous);
    await env.DB.prepare(`INSERT INTO accounts (user_id, account, data_json, updated_at) VALUES (?, ?, ?, ?) ON CONFLICT(user_id, account) DO UPDATE SET data_json=excluded.data_json, updated_at=excluded.updated_at`).bind(telemetryUser.id, account.account, JSON.stringify(account), account.updatedAt).run();
    const event = { id:uid(), type:previous?'telemetry':'join', account:account.account, displayName:account.displayName, device:account.device, jobId:account.jobId, eggInventory:account.eggInventory, eggCapacity:account.eggCapacity, petInventory:account.petInventory, petCapacity:account.petCapacity, money:account.money, currentEvent:'No Event', currentArea:account.currentArea||'', activity:account.activity, activityDetail:account.activityDetail, latestStolenEgg:account.latestStolenEgg, eggItems:account.eggItems, createdAt:account.lastSeen };
    await env.DB.prepare('INSERT INTO events (user_id, type, account, payload_json, created_at) VALUES (?, ?, ?, ?, ?)').bind(telemetryUser.id, event.type, account.account, JSON.stringify(event), account.updatedAt).run();
    await env.DB.prepare('DELETE FROM events WHERE user_id = ? AND id NOT IN (SELECT id FROM events WHERE user_id = ? ORDER BY id DESC LIMIT ?)').bind(telemetryUser.id, telemetryUser.id, MAX_EVENTS).run();
    return json({ ok:true, receivedAt:account.lastSeen, siteId:telemetryUser.id, account:account.account, displayName:account.displayName, dashboardUrl:str(env.PUBLIC_BASE_URL, request.url.split('/api/telemetry')[0]) });
  }
  if (url.pathname === '/api/accounts/' && request.method === 'DELETE') return json({ ok:false,error:'account_not_found' },404);
  if (url.pathname.startsWith('/api/accounts/') && request.method === 'DELETE') {
    const key = decodeURIComponent(url.pathname.slice('/api/accounts/'.length));
    const token = request.headers.get('x-axel-mutation-token') || '';
    if (token !== await mutationToken(env, user.id)) return json({ ok:false,error:'invalid_mutation_token' },401);
    const exists = await env.DB.prepare('SELECT id FROM accounts WHERE user_id = ? AND account = ?').bind(user.id,key).first(); if (!exists) return json({ ok:false,error:'account_not_found' },404);
    await env.DB.batch([
      env.DB.prepare('DELETE FROM accounts WHERE user_id = ? AND account = ?').bind(user.id,key),
      env.DB.prepare('DELETE FROM graph_points WHERE user_id = ? AND account = ?').bind(user.id,key),
      env.DB.prepare('DELETE FROM events WHERE user_id = ? AND account = ?').bind(user.id,key),
    ]); return json({ ok:true, siteId:user.id });
  }
  if (url.pathname === '/api/reset' && request.method === 'POST') {
    await env.DB.batch([
      env.DB.prepare('DELETE FROM accounts WHERE user_id = ?').bind(user.id),
      env.DB.prepare('DELETE FROM graph_points WHERE user_id = ?').bind(user.id),
      env.DB.prepare('DELETE FROM events WHERE user_id = ?').bind(user.id),
      env.DB.prepare('UPDATE site_meta SET started_at = ?, reset_stolen_base = ? WHERE user_id = ?').bind(now(),'{}',user.id),
    ]); return json({ ok:true, siteId:user.id });
  }
  if (url.pathname === '/api/stream' && request.method === 'GET') return json({ ok:true, mode:'polling', intervalMs:10000 });
  if (url.pathname === '/api/egg-source' && request.method === 'GET') return json({ url:'https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-eggs-list/' });
  if (url.pathname === '/api/egg-image' && request.method === 'GET') return await eggImageProxy(request, env);
  return null;
}

async function eggImageProxy(request, env) {
  const name = str(new URL(request.url).searchParams.get('name')); if (!name) return new Response(null,{status:400,headers:CORS});
  const source = 'https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-eggs-list/';
  try {
    const page = await fetch(source, { headers:{'User-Agent':'Mozilla/5.0 Axel-Web-Log'} });
    const html = await page.text();
    const esc = name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    const m = new RegExp('(?:alt|title)=["\\\'][^"\\\']*'+esc+'[^"\\\']*["\\\'][^>]*>.*?<img[^>]+src=["\\\']([^"\\\']+)', 'i').exec(html)
      || new RegExp('<img[^>]+src=["\\\']([^"\\\']+)["\\\'][^>]*>.*?'+esc, 'i').exec(html);
    if (!m) return new Response(null,{status:404,headers:CORS});
    const src = new URL(m[1], source).toString();
    const img = await fetch(src, { headers:{'User-Agent':'Mozilla/5.0 Axel-Web-Log','Referer':source} });
    const h = new Headers(CORS); h.set('Cache-Control','public, max-age=86400'); if(img.headers.get('content-type')) h.set('Content-Type',img.headers.get('content-type'));
    return new Response(img.body,{status:img.status,headers:h});
  } catch { return new Response(null,{status:502,headers:CORS}); }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      const api = await handleApi(request, env, url);
      if (api) return api;
    }
    if (url.pathname === '/site' || url.pathname.startsWith('/site/')) {
      const user = await getSessionUser(request, env);
      return Response.redirect(new URL(user ? '/' : '/login.html', request.url), 302);
    }
    if (url.pathname === '/') {
      const user = await getSessionUser(request, env);
      return env.ASSETS.fetch(new Request(new URL(user ? '/index.html' : '/login.html', request.url), request));
    }
    return env.ASSETS.fetch(request);
  },
};
