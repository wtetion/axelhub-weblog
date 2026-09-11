const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');
const http = require('http');

const app = express();
app.use(express.json({ limit: '512kb' }));
app.use(express.urlencoded({ extended: false }));
app.use(express.static(path.join(__dirname, 'public'), { index: false }));

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const API_KEY = process.env.AXEL_API_KEY || 'change-me';
const DATA_DIR = path.resolve(process.env.DATA_DIR || path.join(__dirname, 'data'));
const PUBLIC_BASE_URL = String(process.env.PUBLIC_BASE_URL || 'https://Axelhub.ud0').replace(/\/$/, '');
const AUTH_SECRET = process.env.AUTH_SECRET || 'change-this-auth-secret';
const SESSION_TTL_MS = Number(process.env.SESSION_TTL_MS || 1000 * 60 * 60 * 24 * 30);
const USERS_FILE = path.join(DATA_DIR, 'users.xlsx');
const MAX_EVENTS = Number(process.env.MAX_EVENTS || 2000);
const STALE_AFTER_MS = Number(process.env.STALE_AFTER_MS || 45000);
const STORE_FILE = path.join(DATA_DIR, 'store.json');
const EGG_CATALOG_FILE = path.join(DATA_DIR, 'egg_catalog.json');
const ELDORADO_EGGS_URL = 'https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-eggs-list/';

const XLSX = require('xlsx');
function ensureDataDir(){ fs.mkdirSync(DATA_DIR,{recursive:true}); }
function loadUserRows(){ ensureDataDir(); try{ if(!fs.existsSync(USERS_FILE)) return []; const wb=XLSX.readFile(USERS_FILE); const ws=wb.Sheets[wb.SheetNames[0]]; return ws?XLSX.utils.sheet_to_json(ws,{defval:''}):[]; }catch(e){ console.error('users.xlsx read failed:',e.message); return []; } }
function saveUserRows(rows){ ensureDataDir(); const wb=XLSX.utils.book_new(); const ws=XLSX.utils.json_to_sheet(rows,{header:['userId','username','passwordHash','passwordSalt','telemetryKey','createdAt','status']}); XLSX.utils.book_append_sheet(wb,ws,'Users'); XLSX.writeFile(wb,USERS_FILE); }
let userRows=loadUserRows();
function findUserByUsername(username){const k=String(username||'').trim().toLowerCase();return userRows.find(u=>String(u.username||'').trim().toLowerCase()===k)||null;}
function findUserByTelemetryKey(key){return userRows.find(u=>String(u.telemetryKey||'')===String(key||''))||null;}
function makePasswordRecord(password){const salt=crypto.randomBytes(16).toString('hex');return{passwordSalt:salt,passwordHash:crypto.scryptSync(String(password),salt,64).toString('hex')};}
function verifyPassword(password,user){try{const a=Buffer.from(crypto.scryptSync(String(password),String(user.passwordSalt),64).toString('hex'),'hex');const b=Buffer.from(String(user.passwordHash||''),'hex');return a.length===b.length&&crypto.timingSafeEqual(a,b);}catch{return false;}}
function base64url(v){return Buffer.from(String(v)).toString('base64').replace(/=+$/,'').replace(/\+/g,'-').replace(/\//g,'_');}
function signSession(userId,issuedAt){const payload=`${userId}.${issuedAt}`;return `${base64url(payload)}.${crypto.createHmac('sha256',AUTH_SECRET).update(payload).digest('hex')}`;}
function parseCookies(req){const out={};for(const part of String(req.headers.cookie||'').split(';')){const i=part.indexOf('=');if(i>0)out[part.slice(0,i).trim()]=decodeURIComponent(part.slice(i+1).trim());}return out;}
function getSessionUser(req){const token=parseCookies(req).axel_session||'';const [payload64,sig]=token.split('.');if(!payload64||!sig)return null;try{const payload=Buffer.from(payload64.replace(/-/g,'+').replace(/_/g,'/'),'base64').toString('utf8');const [userId,issuedRaw]=payload.split('.');const issued=Number(issuedRaw);if(!userId||!Number.isFinite(issued)||Date.now()-issued>SESSION_TTL_MS)return null;const expected=signSession(userId,issued).split('.')[1];const a=Buffer.from(sig),b=Buffer.from(expected);if(a.length!==b.length||!crypto.timingSafeEqual(a,b))return null;return userRows.find(u=>String(u.userId)===String(userId))||null;}catch{return null;}}
function setSessionCookie(res,userId){res.setHeader('Set-Cookie',`axel_session=${encodeURIComponent(signSession(userId,Date.now()))}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${Math.floor(SESSION_TTL_MS/1000)}`);}
function clearSessionCookie(res){res.setHeader('Set-Cookie','axel_session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0');}
function userPublic(u){return{userId:String(u.userId),username:String(u.username),telemetryKey:String(u.telemetryKey),publicUrl:PUBLIC_BASE_URL};}
function requireWebAuth(req,res,next){const u=getSessionUser(req);if(!u)return res.status(401).json({ok:false,error:'login_required'});req.authUser=u;next();}
function authTelemetry(req,res,next){const supplied=req.get('x-axel-api-key')||req.get('x-axel-user-key')||'';const u=findUserByTelemetryKey(supplied);if(u){req.authUser=u;return next();}if(supplied&&supplied===API_KEY&&userRows.length===0){req.authUser={userId:'legacy',username:'legacy',telemetryKey:API_KEY};return next();}return res.status(401).json({ok:false,error:'invalid_telemetry_key'});}
function userSiteId(req){return String(req.authUser?.userId||'legacy');}
function newUserData(){return{accounts:{},events:[],joins:[],graph:{startedAt:Date.now(),points:[],resetStolenBase:{}}};}

function loadStore(){
  try{
    const parsed=JSON.parse(fs.readFileSync(STORE_FILE,'utf8'));
    if(parsed&&parsed.users)return parsed;
    if(parsed&&parsed.sites){const legacy=newUserData();for(const site of Object.values(parsed.sites)){Object.assign(legacy.accounts,site?.accounts||{});legacy.events.push(...(Array.isArray(site?.events)?site.events:[]));legacy.joins.push(...(Array.isArray(site?.joins)?site.joins:[]));if(Array.isArray(site?.graph?.points))legacy.graph.points.push(...site.graph.points);}return{users:{legacy}};}
    if(parsed&&parsed.accounts)return{users:{legacy:{accounts:parsed.accounts||{},events:parsed.events||[],joins:parsed.joins||[],graph:{startedAt:Date.now(),points:[],resetStolenBase:{}}}}};
  }catch{}
  return{users:{}};
}
let store = loadStore();
const clientsBySite = new Map();

function saveStore() {
  fs.mkdirSync(path.dirname(STORE_FILE), { recursive: true });
  const tmp = `${STORE_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(store, null, 2));
  fs.renameSync(tmp, STORE_FILE);
}
function getRequestedSiteId(req) { return userSiteId(req); }
function ensureGraph(site) {
  if (!site.graph || typeof site.graph !== 'object') site.graph = { startedAt: Date.now(), points: [], resetStolenBase: {} };
  if (!Number.isFinite(Number(site.graph.startedAt))) site.graph.startedAt = Date.now();
  if (!Array.isArray(site.graph.points)) site.graph.points = [];
  if (!site.graph.resetStolenBase || typeof site.graph.resetStolenBase !== 'object') site.graph.resetStolenBase = {};
  const now = Date.now();
  if (now - Number(site.graph.startedAt) >= 30 * 60 * 1000) {
    site.graph = { startedAt: now, points: [], resetStolenBase: {} };
    for (const [account, data] of Object.entries(site.accounts || {})) {
      site.graph.resetStolenBase[account] = Number(data.eggsStolen || 0);
    }
  }
  return site.graph;
}
function getSite(req) { const id=getRequestedSiteId(req); if(!store.users[id]) store.users[id]=newUserData(); ensureGraph(store.users[id]); return {id,data:store.users[id]}; }
function sendEvent(siteId, payload) {
  const clients = clientsBySite.get(siteId);
  if (!clients) return;
  const data = `data: ${JSON.stringify(payload)}\n\n`;
  for (const res of clients) { try { res.write(data); } catch { clients.delete(res); } }
}
function auth(req, res, next) {
  const supplied = req.get('x-axel-api-key') || req.query.key || '';
  if (supplied !== API_KEY) return res.status(401).json({ ok: false, error: 'invalid_api_key' });
  next();
}
function num(v, fallback=0) { const n = Number(v); return Number.isFinite(n) ? n : fallback; }
function str(v, fallback='') { return v == null ? fallback : String(v); }
function normalizeInventoryItems(items) {
  if (!Array.isArray(items)) return [];
  return items.slice(0, 200).map(x => ({
    name: str(x.name || x.eggName, 'Unknown Egg'),
    rarity: str(x.rarity || x.rarityName || x.rarityType, 'Unknown'),
    rarityColor: str(x.rarityColor, '#6B7280'),
    mutation: str(x.mutation, 'Normal'),
    count: Math.max(1, num(x.count, 1)),
    finalValue: x.finalValue == null ? null : num(x.finalValue),
    uid: x.uid ? str(x.uid) : undefined
  }));
}
function normalizeTelemetry(body, ownerUserId) {
  const now = Date.now();
  const account = str(body.account || body.username || body.name || body.displayName, 'Unknown');
  const inventory = body.inventory || {};
  const stats = body.stats || {};
  const siteId = String(ownerUserId || 'legacy');
  return {
    siteId,
    account,
    displayName: str(body.displayName, account),
    device: (str(body.device, '')).toLowerCase() === 'mobile' ? 'Mobile' : 'PC',
    pc: body.pc == null ? '' : str(body.pc, ''),
    money: num(body.money ?? stats.money),
    speed: num(body.speed ?? stats.speed),
    eggInventory: num(body.eggInventory ?? inventory.eggs),
    eggCapacity: num(body.eggCapacity ?? inventory.eggCapacity),
    petInventory: num(body.petInventory ?? inventory.pets),
    petCapacity: num(body.petCapacity ?? inventory.petCapacity),
    baseLevel: body.baseLevel ?? body.baseTier ?? stats.baseLevel ?? stats.baseTier ?? inventory.baseLevel ?? 0,
    treadmillLevel: body.treadmillLevel ?? body.treadmillTier ?? stats.treadmillLevel ?? stats.treadmillTier ?? inventory.treadmillLevel ?? 0,
    eggsStolen: num(body.eggsStolen),
    petsHatched: num(body.petsHatched),
    eggItems: normalizeInventoryItems(body.eggItems || inventory.eggItems),
    currentEvent: 'No Event',
    currentArea: str(body.currentArea || body.area || '', ''),
    activity: str(body.activity || body.action || body.statusText, 'Idle'),
    activityDetail: str(body.activityDetail || body.actionDetail, ''),
    latestStolenEgg: body.latestStolenEgg && typeof body.latestStolenEgg === 'object' ? {
      name: str(body.latestStolenEgg.name, 'Unknown Egg'),
      rarity: str(body.latestStolenEgg.rarity, 'Unknown'),
      rarityColor: str(body.latestStolenEgg.rarityColor, '#6B7280'),
      mutation: str(body.latestStolenEgg.mutation, 'Normal'),
      imageUrl: str(body.latestStolenEgg.imageUrl, ''),
      finalValue: body.latestStolenEgg.finalValue == null ? null : num(body.latestStolenEgg.finalValue),
      area: str(body.latestStolenEgg.area, ''),
      stolenAt: str(body.latestStolenEgg.stolenAt, '')
    } : null,
    jobId: str(body.jobId || body.jobID, 'Unknown'),
    placeId: str(body.placeId, ''),
    uptimeSeconds: num(body.uptimeSeconds),
    status: 'online',
    lastSeen: new Date(now).toISOString(),
    updatedAt: now
  };
}
function publicAccount(account) {
  const site = Object.values(store.users || {}).find(s => s?.accounts?.[account.account] === account);
  let moneyPerSecond = 0;
  if (site?.graph?.points) {
    for (let i = site.graph.points.length - 1; i >= 0; i--) {
      const p = site.graph.points[i];
      if (p.account === account.account) { moneyPerSecond = Number(p.moneyPerSecond || 0); break; }
    }
  }
  return { ...account, device: account.device === 'Mobile' ? 'Mobile' : 'PC', moneyPerSecond,
    live: Date.now() - account.updatedAt <= STALE_AFTER_MS };
}

function buildGraphPoint(site, account) {
  const graph = ensureGraph(site);
  const now = Date.now();
  const previous = site.accounts[account.account];
  if (!Object.prototype.hasOwnProperty.call(graph.resetStolenBase, account.account)) {
    graph.resetStolenBase[account.account] = Number(account.eggsStolen || 0);
  }
  let moneyPerSecond = 0;
  let stolenDelta = 0;
  if (previous && Number.isFinite(Number(previous.updatedAt))) {
    const dt = Math.max(0.001, (now - Number(previous.updatedAt)) / 1000);
    const moneyDelta = Number(account.money || 0) - Number(previous.money || 0);
    moneyPerSecond = Math.max(0, moneyDelta / dt);
    stolenDelta = Math.max(0, Number(account.eggsStolen || 0) - Number(previous.eggsStolen || 0));
  }
  graph.points.push({
    t: now,
    account: account.account,
    displayName: account.displayName,
    speed: Number(account.speed || 0),
    moneyPerSecond,
    eggsStolen: Math.max(0, Number(account.eggsStolen || 0) - Number(graph.resetStolenBase[account.account] || 0)),
    stolenDelta
  });
  if (graph.points.length > 5000) graph.points.splice(0, graph.points.length - 5000);
  return graph;
}

app.get('/api/health',(_req,res)=>res.json({ok:true,service:'Axel Web Log',now:new Date().toISOString()}));
app.get('/api/auth/me',(req,res)=>{const user=getSessionUser(req);if(!user)return res.status(401).json({ok:false,error:'login_required'});res.json({ok:true,user:userPublic(user)});});
app.post('/api/auth/signup',(req,res)=>{const username=String(req.body?.username||'').trim(),password=String(req.body?.password||'');if(!/^[A-Za-z0-9._-]{3,32}$/.test(username))return res.status(400).json({ok:false,error:'username_must_be_3_to_32_chars'});if(password.length<8||password.length>200)return res.status(400).json({ok:false,error:'password_must_be_8_to_200_chars'});if(findUserByUsername(username))return res.status(409).json({ok:false,error:'username_taken'});const userId=crypto.randomUUID(),telemetryKey=`axel_${crypto.randomBytes(24).toString('hex')}`,pw=makePasswordRecord(password),row={userId,username,...pw,telemetryKey,createdAt:new Date().toISOString(),status:'active'};userRows.push(row);saveUserRows(userRows);store.users[userId]=newUserData();saveStore();setSessionCookie(res,userId);res.json({ok:true,user:userPublic(row)});});
app.post('/api/auth/login',(req,res)=>{const username=String(req.body?.username||'').trim(),password=String(req.body?.password||''),user=findUserByUsername(username);if(!user||user.status==='disabled'||!verifyPassword(password,user))return res.status(401).json({ok:false,error:'invalid_credentials'});setSessionCookie(res,user.userId);res.json({ok:true,user:userPublic(user)});});
app.post('/api/auth/logout',(_req,res)=>{clearSessionCookie(res);res.json({ok:true});});
app.get('/api/context',requireWebAuth,(req,res)=>{const site=getSite(req),mutationToken=crypto.createHash('sha256').update(`${AUTH_SECRET}|delete|${site.id}`).digest('hex');res.json({ok:true,siteId:site.id,siteUrl:PUBLIC_BASE_URL,mutationToken,user:userPublic(req.authUser)});});
app.get('/api/accounts',requireWebAuth,(req,res)=>{const site=getSite(req),accounts=Object.values(site.data.accounts).sort((a,b)=>b.updatedAt-a.updatedAt).map(publicAccount);res.json({ok:true,siteId:site.id,players:accounts.length,servers:new Set(accounts.map(a=>a.jobId).filter(Boolean)).size,events:site.data.events.length,joins:site.data.joins.length,accounts});});
app.get('/api/analytics',requireWebAuth,(req,res)=>{const site=getSite(req),accounts=Object.values(site.data.accounts),live=accounts.filter(a=>Date.now()-a.updatedAt<=STALE_AFTER_MS);const totalEggInventory=accounts.reduce((s,a)=>s+num(a.eggInventory),0),totalPetInventory=accounts.reduce((s,a)=>s+num(a.petInventory),0),totalEggsStolen=accounts.reduce((s,a)=>s+num(a.eggsStolen),0),totalMoney=accounts.reduce((s,a)=>s+num(a.money),0);res.json({ok:true,siteId:site.id,players:accounts.length,livePlayers:live.length,servers:new Set(accounts.map(a=>a.jobId).filter(Boolean)).size,events:site.data.events.length,joins:site.data.joins.length,totalEggInventory,totalPetInventory,totalEggsStolen,totalMoney,currentEvent:'No Event',currentArea:live[0]?.currentArea||'',currentActivity:live[0]?.activity||'Idle',currentActivityDetail:live[0]?.activityDetail||''});});
app.get('/api/graph',requireWebAuth,(req,res)=>{const site=getSite(req),graph=ensureGraph(site.data),accountFilter=str(req.query?.account||'',''),points=graph.points.filter(p=>!accountFilter||p.account===accountFilter),accounts=Array.from(new Map(Object.values(site.data.accounts).map(a=>[a.account,{account:a.account,displayName:a.displayName||a.account}])).values()),latestByAccount=new Map();for(const p of points)latestByAccount.set(p.account,p);const summary={speed:0,moneyPerSecond:0,eggsStolen:0};if(accountFilter){const latest=latestByAccount.get(accountFilter);if(latest){summary.speed=latest.speed;summary.moneyPerSecond=latest.moneyPerSecond;summary.eggsStolen=latest.eggsStolen;}}else for(const p of latestByAccount.values()){summary.speed+=p.speed;summary.moneyPerSecond+=p.moneyPerSecond;summary.eggsStolen+=p.eggsStolen;}res.json({ok:true,siteId:site.id,resetAt:new Date(Number(graph.startedAt)+30*60*1000).toISOString(),startedAt:new Date(Number(graph.startedAt)).toISOString(),account:accountFilter,accounts,summary,series:points.map(p=>({t:p.t,account:p.account,displayName:p.displayName,speed:p.speed,moneyPerSecond:p.moneyPerSecond,eggsStolen:p.eggsStolen}))});});
app.get('/api/events',requireWebAuth,(req,res)=>{const site=getSite(req);res.json({ok:true,siteId:site.id,events:site.data.events.slice(-250).reverse()});});
app.get('/api/inventory',requireWebAuth,(req,res)=>{const site=getSite(req);const accounts=Object.values(site.data.accounts).map(a=>({account:a.account,displayName:a.displayName,eggInventory:a.eggInventory,eggCapacity:a.eggCapacity,petInventory:a.petInventory,petCapacity:a.petCapacity,eggsStolen:a.eggsStolen,petsHatched:a.petsHatched,currentEvent:'No Event',currentArea:a.currentArea||'',activity:a.activity,activityDetail:a.activityDetail,eggItems:a.eggItems||[],latestStolenEgg:a.latestStolenEgg,baseLevel:a.baseLevel??0,treadmillLevel:a.treadmillLevel??0,lastSeen:a.lastSeen,live:Date.now()-a.updatedAt<=STALE_AFTER_MS}));res.json({ok:true,siteId:site.id,accounts});});
app.post('/api/telemetry',authTelemetry,(req,res)=>{const account=normalizeTelemetry(req.body||{}, req.authUser?.userId),site=getSite(req),previous=site.data.accounts[account.account];if(!site.data.graph)site.data.graph={startedAt:Date.now(),points:[],resetStolenBase:{}};ensureGraph(site.data);if(previous)buildGraphPoint(site.data,account);else{ensureGraph(site.data).resetStolenBase[account.account]=Number(account.eggsStolen||0);ensureGraph(site.data).points.push({t:Date.now(),account:account.account,displayName:account.displayName,speed:Number(account.speed||0),moneyPerSecond:0,eggsStolen:0,stolenDelta:0});}site.data.accounts[account.account]=account;const event={id:crypto.randomUUID(),type:previous?'telemetry':'join',account:account.account,displayName:account.displayName,device:account.device,jobId:account.jobId,eggInventory:account.eggInventory,eggCapacity:account.eggCapacity,petInventory:account.petInventory,petCapacity:account.petCapacity,money:account.money,currentEvent:'No Event',currentArea:account.currentArea||'',activity:account.activity,activityDetail:account.activityDetail,latestStolenEgg:account.latestStolenEgg,eggItems:account.eggItems,createdAt:account.lastSeen};site.data.events.push(event);if(!previous)site.data.joins.push({account:account.account,jobId:account.jobId,createdAt:account.lastSeen});if(site.data.events.length>MAX_EVENTS)site.data.events.splice(0,site.data.events.length-MAX_EVENTS);if(site.data.joins.length>MAX_EVENTS)site.data.joins.splice(0,site.data.joins.length-MAX_EVENTS);try{saveStore();}catch(e){console.error('saveStore:',e.message);}sendEvent(site.id,{type:'telemetry',account:publicAccount(account),event});res.json({ok:true,receivedAt:account.lastSeen,siteId:site.id,account:account.account,displayName:account.displayName,dashboardUrl:PUBLIC_BASE_URL});});
app.delete('/api/accounts/:account',requireWebAuth,(req,res)=>{const site=getSite(req),key=req.params.account,token=crypto.createHash('sha256').update(`${AUTH_SECRET}|delete|${site.id}`).digest('hex');if(String(req.headers['x-axel-mutation-token']||'')!==token)return res.status(401).json({ok:false,error:'invalid_mutation_token'});if(!site.data.accounts[key])return res.status(404).json({ok:false,error:'account_not_found'});delete site.data.accounts[key];if(site.data.graph?.resetStolenBase)delete site.data.graph.resetStolenBase[key];if(Array.isArray(site.data.graph?.points))site.data.graph.points=site.data.graph.points.filter(p=>p.account!==key);saveStore();sendEvent(site.id,{type:'account_removed',account:key});res.json({ok:true,siteId:site.id});});
app.post('/api/reset',requireWebAuth,(req,res)=>{const site=getSite(req);site.data=newUserData();store.users[site.id]=site.data;saveStore();sendEvent(site.id,{type:'reset'});res.json({ok:true,siteId:site.id});});
app.get('/api/stream',requireWebAuth,(req,res)=>{const site=getSite(req);res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache','Connection':'keep-alive'});res.write(`data: ${JSON.stringify({type:'hello',siteId:site.id})}\\n\\n`);if(!clientsBySite.has(site.id))clientsBySite.set(site.id,new Set());clientsBySite.get(site.id).add(res);req.on('close',()=>clientsBySite.get(site.id)?.delete(res));});

// ---- Eldorado egg image catalog / proxy ----
let eggCatalog = (()=>{try{return JSON.parse(fs.readFileSync(EGG_CATALOG_FILE,'utf8'));}catch{return {updatedAt:0,rows:[]};}})();
function decodeHtml(s){return String(s).replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&nbsp;/g,' ').replace(/&lt;/g,'<').replace(/&gt;/g,'>');}
function cleanText(s){return decodeHtml(String(s).replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').trim());}
function normalizeName(s){return cleanText(s).toLowerCase().replace(/[^a-z0-9]+/g,' ').replace(/\begg\b/g,'').trim();}
function extractImageFromRow(row){
  const tags=[...String(row).matchAll(/<img\b[^>]*>/gi)].map(m=>m[0]);
  for(const tag of tags){
    const attrs={};
    for(const m of tag.matchAll(/([\w:-]+)\s*=\s*["']([^"']*)["']/g)) attrs[m[1].toLowerCase()]=decodeHtml(m[2]);
    const src=attrs.src||attrs['data-src']||attrs['data-lazy-src']||((attrs.srcset||'').split(',')[0]||'').trim().split(' ')[0];
    if(src && !src.startsWith('data:')) return new URL(src,ELDORADO_EGGS_URL).toString();
  }
  return '';
}
function fetchUrl(url){return new Promise((resolve,reject)=>{const lib=url.startsWith('https')?https:http;const req=lib.get(url,{headers:{'User-Agent':'Mozilla/5.0 Axel-Web-Log'}},r=>{if(r.statusCode>=300&&r.statusCode<400&&r.headers.location)return resolve(fetchUrl(new URL(r.headers.location,url).toString()));let data='';r.setEncoding('utf8');r.on('data',c=>{data+=c;if(data.length>8_000_000) r.destroy(new Error('response too large'));});r.on('end',()=>r.statusCode>=200&&r.statusCode<300?resolve(data):reject(new Error(`HTTP ${r.statusCode}`)));});req.on('error',reject);req.setTimeout(15000,()=>req.destroy(new Error('timeout')));});}
async function refreshEggCatalog(){
  const html=await fetchUrl(ELDORADO_EGGS_URL);
  const rows=[];
  for(const m of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)){
    const row=m[1];
    const text=cleanText(row); if(!text) continue;
    const img=extractImageFromRow(row); if(!img) continue;
    const namePart=text.split(/\b(Common|Uncommon|Rare|Epic|Legendary|Mythic|Cosmic|Secret|Eternal|Divine|Titan)\b/i)[0].trim();
    if(namePart.length>2 && namePart.length<120) rows.push({name:cleanText(namePart),key:normalizeName(namePart),image:img});
  }
  const seen=new Set(); eggCatalog={updatedAt:Date.now(),rows:rows.filter(r=>{if(seen.has(r.key))return false;seen.add(r.key);return true;})};
  fs.mkdirSync(path.dirname(EGG_CATALOG_FILE),{recursive:true}); fs.writeFileSync(EGG_CATALOG_FILE,JSON.stringify(eggCatalog,null,2));
  return eggCatalog;
}
function findEggImage(name){
  const key=normalizeName(name);
  if(!key)return '';
  let exact=eggCatalog.rows.find(r=>r.key===key); if(exact)return exact.image;
  return eggCatalog.rows.find(r=>r.key.includes(key)||key.includes(r.key))?.image||'';
}
app.get('/api/egg-image', async (req,res)=>{
  const name=str(req.query.name,'');
  if(!name)return res.status(400).end();
  if(Date.now()-(eggCatalog.updatedAt||0)>24*60*60*1000 || eggCatalog.rows.length===0){try{await refreshEggCatalog();}catch{}}
  const src=findEggImage(name);
  if(!src)return res.status(404).end();
  res.setHeader('Cache-Control','public, max-age=86400');
  try{
    const lib=src.startsWith('https')?https:http;
    lib.get(src,{headers:{'User-Agent':'Mozilla/5.0 Axel-Web-Log','Referer':ELDORADO_EGGS_URL}},r=>{
      if(r.statusCode>=300&&r.statusCode<400&&r.headers.location)return res.redirect(new URL(r.headers.location,src).toString());
      if(r.statusCode!==200){res.status(502).end();return;}
      if(r.headers['content-type'])res.setHeader('Content-Type',r.headers['content-type']);
      r.pipe(res);
    }).on('error',()=>res.status(502).end());
  }catch{res.status(502).end();}
});
app.get('/api/egg-source',(_req,res)=>res.json({url:ELDORADO_EGGS_URL}));
app.get('/site/:siteId',(req,res)=>res.redirect(getSessionUser(req)?'/':'/login.html'));
app.get('/',(req,res)=>{if(!getSessionUser(req))return res.redirect('/login.html');res.sendFile(path.join(__dirname,'public','index.html'));});
app.get('*',(req,res)=>{if(!getSessionUser(req))return res.redirect('/login.html');res.sendFile(path.join(__dirname,'public','index.html'));});
app.listen(PORT,HOST,()=>{console.log(`Axel Web Log running at ${PUBLIC_BASE_URL} (http://${HOST}:${PORT})`);console.log(`Legacy API key: ${API_KEY === 'change-me' ? 'local-only fallback' : 'configured'}`);console.log(`Egg image source: ${ELDORADO_EGGS_URL}`);});
