const $=id=>document.getElementById(id);

const I18N={
  en:{
    'header.webLog':'Web Log','header.subtitle':'Live game telemetry & control dashboard','common.discord':'Discord ↗','common.copyTelemetry':'Copy telemetry key','common.signOut':'Sign out','common.refresh':'Refresh','common.allAccounts':'All Accounts','common.live':'Live','common.latest':'latest','common.estimated':'estimated','common.window30m':'this 30m window','common.waitingTelemetry':'Waiting for telemetry…','common.currentEvent':'current event','common.currentArea':'current area','common.idle':'Idle','common.noEvent':'No Event','telemetry.label':'TELEMETRY TOKEN','telemetry.subtitle':'Your private connection token','telemetry.copy':'COPY TOKEN','telemetry.privateLog':'PRIVATE WEB LOG','footer.text':'AXEL HUB WEB LOG · Node.js telemetry server ·',
    'nav.accounts':'Accounts','nav.inventory':'Inventory','nav.analytics':'Analytics','nav.graph':'Graph','clock.yourTime':'YOUR TIME',
    'accounts.eyebrow':'PLAYER ACCOUNTS','accounts.title':'Live Accounts','accounts.subtitle':'See what every connected character is doing right now.',
    'stats.players':'PLAYERS','stats.trackedAccounts':'tracked accounts','stats.servers':'SERVERS','stats.jobIds':'job ids','stats.currentActivity':'CURRENT ACTIVITY','stats.waitingTelemetry':'waiting for telemetry','stats.joins':'JOINS','stats.joinEvents':'join events',
    'playerLog.title':'Player Log','playerLog.subtitle':'Account · Activity · Levels · Game stats','common.live':'Live','liveActivity.title':'Live Activity','liveActivity.subtitle':'Exactly what each account is doing',
    'table.account':'ACCOUNT','table.device':'DEVICE','table.activity':'ACTIVITY','table.baseLevel':'BASE LEVEL','table.treadmillLevel':'TREADMILL LEVEL','table.money':'MONEY','table.speed':'SPEED','table.jobId':'JOB ID','table.lastSeen':'LAST SEEN',
    'inventory.eyebrow':'INVENTORY','inventory.title':'Egg Inventory','inventory.subtitle':'Collected eggs, rarity colors and matching images.','inventory.search':'Search eggs...','inventory.inInventory':'Eggs in inventory',
    'analytics.eyebrow':'LIVE ANALYTICS','analytics.title':'Live Analytics','analytics.subtitle':'Realtime activity across connected accounts.','analytics.eggsStolen':'EGGS STOLEN','analytics.combinedLifetime':'combined lifetime','analytics.eggsInventory':'EGGS IN INVENTORY','analytics.allAccounts':'all connected accounts','analytics.noActiveReport':'No active report',
    'events.title':'Latest Stolen','events.subtitle':'Latest stolen egg activity',
    'common.all':'All','common.unknownEgg':'Unknown Egg','common.noMatchingEggs':'No eggs match the current filters','common.noAccounts':'No accounts yet — send telemetry.','common.noActiveAccounts':'No active accounts.','common.noEvents':'No events yet.','common.noArea':'No area',
    'common.copyJob':'Copy full Job ID','common.total':'total','common.liveNow':'LIVE · now','common.offlineNow':'LIVE · now','common.stolen':'stolen','common.delete':'Delete','common.copyData':'Copy data','table.actions':'ACTIONS',
    'graph.eyebrow':'GRAPH','graph.title':'Live Graph','graph.subtitle':'Speed, Money/s and Stolen Eggs • resets every 30 minutes.','graph.resetEvery':'30 MIN RESET','graph.speed':'SPEED','graph.moneyPerSecond':'MONEY / S','graph.stolen':'STOLEN EGGS','graph.latest':'latest','graph.estimated':'estimated','graph.window30m':'this 30m window','graph.speedTitle':'Speed','graph.speedTrend':'Live speed trend','graph.moneyTitle':'Money / s','graph.moneyDesc':'Estimated from money delta','graph.stolenTitle':'Stolen Eggs','graph.stolenDesc':'Cumulative this 30 minute window','analytics.event':'EVENT','analytics.noEvent':'No Event','analytics.currentEvent':'current event','analytics.area':'AREA','analytics.currentArea':'current area'
  },
  th:{
    'header.webLog':'Web Log','header.subtitle':'ข้อมูลเกมแบบเรียลไทม์และแดชบอร์ดควบคุม','common.discord':'Discord ↗','common.copyTelemetry':'คัดลอก Telemetry Token','common.signOut':'ออกจากระบบ','common.refresh':'รีเฟรช','common.allAccounts':'ทุกบัญชี','common.live':'ออนไลน์','common.latest':'ล่าสุด','common.estimated':'โดยประมาณ','common.window30m':'ในช่วง 30 นาทีนี้','common.waitingTelemetry':'กำลังรอ telemetry…','common.currentEvent':'อีเวนต์ปัจจุบัน','common.currentArea':'พื้นที่ปัจจุบัน','common.idle':'ไม่มีการทำงาน','common.noEvent':'ยังไม่มีอีเวนต์','telemetry.label':'TELEMETRY TOKEN','telemetry.subtitle':'โทเคนเชื่อมต่อส่วนตัวของคุณ','telemetry.copy':'คัดลอก TOKEN','telemetry.privateLog':'WEB LOG ส่วนตัว','footer.text':'AXEL HUB WEB LOG · เซิร์ฟเวอร์ Node.js telemetry ·',
    'nav.accounts':'บัญชี','nav.inventory':'คลังไข่','nav.analytics':'วิเคราะห์','nav.graph':'กราฟ','clock.yourTime':'เวลาของคุณ',
    'accounts.eyebrow':'บัญชีผู้เล่น','accounts.title':'บัญชีที่ออนไลน์','accounts.subtitle':'ดูว่าตัวละครที่เชื่อมต่อกำลังทำอะไรอยู่ตอนนี้',
    'stats.players':'ผู้เล่น','stats.trackedAccounts':'บัญชีที่ติดตาม','stats.servers':'เซิร์ฟเวอร์','stats.jobIds':'Job ID','stats.currentActivity':'กิจกรรมปัจจุบัน','stats.waitingTelemetry':'กำลังรอข้อมูล','stats.joins':'การเข้าเกม','stats.joinEvents':'รายการเข้าเกม',
    'playerLog.title':'บันทึกผู้เล่น','playerLog.subtitle':'บัญชี · กิจกรรม · อีเวนต์ · พื้นที่ · สถิติเกม','common.live':'ออนไลน์','liveActivity.title':'กิจกรรมสด','liveActivity.subtitle':'กำลังทำอะไรอยู่ในแต่ละบัญชี',
    'table.account':'บัญชี','table.device':'อุปกรณ์','table.activity':'กิจกรรม','table.baseLevel':'ระดับฐาน','table.treadmillLevel':'ระดับลู่วิ่ง','table.money':'เงิน','table.speed':'ความเร็ว','table.jobId':'JOB ID','table.lastSeen':'ออนไลน์ล่าสุด',
    'inventory.eyebrow':'คลังไข่','inventory.title':'Egg Inventory','inventory.subtitle':'ไข่ที่เก็บได้ สีตาม Rarity และรูปภาพที่ตรงกัน','inventory.search':'ค้นหาไข่...','inventory.inInventory':'ไข่ในคลัง',
    'analytics.eyebrow':'วิเคราะห์แบบสด','analytics.title':'Live Analytics','analytics.subtitle':'กิจกรรมแบบเรียลไทม์ของบัญชีที่เชื่อมต่อ','analytics.eggsStolen':'ไข่ที่ขโมยได้','analytics.combinedLifetime':'รวมทั้งหมด','analytics.eggsInventory':'ไข่ในคลัง','analytics.allAccounts':'รวมทุกบัญชี','analytics.noActiveReport':'ยังไม่มีข้อมูลกิจกรรม',
    'events.title':'ไข่ที่ขโมยล่าสุด','events.subtitle':'กิจกรรมการขโมยไข่ล่าสุด',
    'common.all':'ทั้งหมด','common.unknownEgg':'ไข่ไม่ทราบชื่อ','common.noMatchingEggs':'ไม่พบไข่ตามตัวกรอง','common.noAccounts':'ยังไม่มีบัญชี — กรุณาส่ง telemetry','common.noActiveAccounts':'ยังไม่มีบัญชีที่กำลังทำงาน','common.noEvents':'ยังไม่มีอีเวนต์','common.noArea':'ไม่มีข้อมูลพื้นที่',
    'common.copyJob':'คัดลอก Job ID เต็ม','common.total':'ทั้งหมด','common.liveNow':'LIVE · now','common.offlineNow':'LIVE · now','common.stolen':'ขโมยได้','common.delete':'ลบ','common.copyData':'คัดลอกข้อมูล','table.actions':'การจัดการ',
    'graph.eyebrow':'กราฟ','graph.title':'กราฟแบบสด','graph.subtitle':'ความเร็ว เงิน/วินาที และไข่ที่ขโมยได้ • รีเซ็ตทุก 30 นาที','graph.resetEvery':'รีเซ็ต 30 นาที','graph.speed':'ความเร็ว','graph.moneyPerSecond':'เงิน / วินาที','graph.stolen':'ไข่ที่ขโมยได้','graph.latest':'ล่าสุด','graph.estimated':'โดยประมาณ','graph.window30m':'ในช่วง 30 นาทีนี้','graph.speedTitle':'ความเร็ว','graph.speedTrend':'แนวโน้มความเร็วแบบสด','graph.moneyTitle':'เงิน / วินาที','graph.moneyDesc':'คำนวณจากการเปลี่ยนแปลงของเงิน','graph.stolenTitle':'ไข่ที่ขโมยได้','graph.stolenDesc':'ยอดสะสมในช่วง 30 นาที','analytics.event':'อีเวนต์','analytics.noEvent':'ยังไม่มีอีเวนต์','analytics.currentEvent':'อีเวนต์ปัจจุบัน','analytics.area':'พื้นที่','analytics.currentArea':'พื้นที่ปัจจุบัน'
  }
};
let currentLang=localStorage.getItem('axelLang')||'en';
const t=k=>(I18N[currentLang]&&I18N[currentLang][k])||I18N.en[k]||k;
function applyLanguage(){document.documentElement.lang=currentLang==='th'?'th':'en';document.querySelectorAll('[data-i18n]').forEach(el=>el.textContent=t(el.dataset.i18n));document.querySelectorAll('[data-i18n-placeholder]').forEach(el=>el.placeholder=t(el.dataset.i18nPlaceholder));document.querySelectorAll('[data-i18n-title]').forEach(el=>el.title=t(el.dataset.i18nTitle));document.querySelectorAll('.lang-btn').forEach(b=>b.classList.toggle('active',b.dataset.lang===currentLang));const c=$('inventorySearch');if(c)c.placeholder=t('inventory.search');renderInventory();}
function setLanguage(lang){currentLang=lang==='th'?'th':'en';localStorage.setItem('axelLang',currentLang);applyLanguage();refreshAll();}

const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const fmt=v=>{const n=Number(v||0);if(!Number.isFinite(n))return '0';for(const[u,d]of [['T',1e12],['B',1e9],['M',1e6],['K',1e3]])if(Math.abs(n)>=d)return (n/d).toFixed(2).replace(/\.00$/,'')+u;return Math.round(n).toLocaleString();};
const ago=iso=>{if(!iso)return '—';const sec=Math.max(0,Math.floor((Date.now()-new Date(iso).getTime())/1000));return sec<2?'now':sec<60?`${sec}s ago`:sec<3600?`${Math.floor(sec/60)}m ago`:`${Math.floor(sec/3600)}h ago`;};
const lastSeenExact=iso=>{if(!iso)return '—';const d=new Date(iso);if(Number.isNaN(d.getTime()))return '—';return new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Bangkok',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false}).format(d)+' GMT+7';};
const rarityColor=r=>({Eternal:'#FF7048',Secret:'#48E5D4',Cosmic:'#8B78FF',Mythic:'#FF5E5A',Mythical:'#FF5E5A',Legendary:'#FFC44D',Epic:'#B47CFF',Rare:'#5B8CFF',Uncommon:'#57D68D',Common:'#A8B0BC',Titan:'#FF4268',Divine:'#FF4AAE',Transcendent:'#FF4AAE',Superior:'#FF4AAE',Limited:'#FF5874',Exotic:'#C36CFF',Exclusive:'#40D7C2',Admin:'#FF4F4F',Prismatic:'#FFC34D',Rainbow:'#FFC34D','Squishy God':'#FFC34D',BrainrotGod:'#FFC34D',SuperRare:'#70AEFF',Celestial:'#40DDF0',Basic:'#A7B0BD',Unknown:'#7A8494'}[String(r||'Unknown').trim()]||'#7A8494');
const safeColor=c=>/^#[0-9a-f]{6}$/i.test(String(c||''))?String(c):'#6B7280';
const mutationClass=m=>{const v=String(m||'').trim().toLowerCase();if(v==='rainbow')return 'mutation-rainbow';if(v==='golden'||v==='gold')return 'mutation-golden';return '';};
const mutationMarkup=m=>{const v=String(m||'').trim();if(!v||v==='Normal')return '';const cls=mutationClass(v);return `<em class="mutation-tag ${cls}">${esc(v)}</em>`;};
let inventoryAccountFilter='all'; let inventoryRarityFilter='all'; let inventorySearch=''; let latestInventoryAccounts=[];
const SITE_ID=(location.pathname.match(/^\/site\/([^/]+)/)||[])[1]||''; let MUTATION_TOKEN=''; let CURRENT_USER=null; const withSite=u=>u; async function get(u){const r=await fetch(withSite(u),{cache:'no-store',credentials:'same-origin'});if(r.status===401){location.href='/login.html';throw new Error('login_required');}if(!r.ok)throw new Error(r.status);return r.json();} async function loadMutationToken(){try{const c=await get('/api/context');MUTATION_TOKEN=c.mutationToken||'';CURRENT_USER=c.user||null;renderCurrentUser();}catch(e){console.warn('context',e);}} function renderCurrentUser(){const n=document.getElementById('authUserName');if(n)n.textContent=CURRENT_USER?.username||'User';const k=document.getElementById('telemetryKey');if(k)k.textContent=CURRENT_USER?.telemetryKey||'—';const u=document.getElementById('publicUrl');if(u)u.textContent=CURRENT_USER?.publicUrl||'http://127.0.0.1:3000';}

function activityBadge(x){const a=String(x.activity||'Idle');const l=a.toLowerCase();let cls='idle';if(l.includes('steal'))cls='steal';else if(l.includes('tread'))cls='tread';else if(l.includes('hatch'))cls='hatch';else if(l.includes('sell'))cls='sell';else if(l.includes('plant'))cls='plant';else if(l.includes('return'))cls='return';else if(l.includes('hop'))cls='hop';return `<span class="activity-badge ${cls}">${esc(a)}</span>`;}
function eggImage(name){return `/api/egg-image?name=${encodeURIComponent(name||'')}`;}
function renderInventory(){
  const accounts=latestInventoryAccounts||[];
  const accountTabs=$('inventoryAccounts');
  const rarityHost=$('inventoryRarities');
  const search=$('inventorySearch');
  if(search && search.value!==inventorySearch) search.value=inventorySearch;
  const items=[];
  for(const a of accounts){
    if(inventoryAccountFilter!=='all' && String(a.account)!==inventoryAccountFilter) continue;
    for(const it of (a.eggItems||[])) items.push({...it, count:Math.max(1,Number(it.count||1)), account:a.account, displayName:a.displayName||a.account});
  }
  const rarityCounts={};
  for(const it of items){const r=String(it.rarity||'Unknown'); rarityCounts[r]=(rarityCounts[r]||0)+Math.max(1,Number(it.count||1));}
  const order=['Eternal','Secret','Cosmic','Mythic','Legendary','Epic','Rare','Uncommon','Common','Titan','Divine','Limited','Exotic','Exclusive','Admin','Rainbow','Basic','Unknown'];
  const rarities=Object.keys(rarityCounts).sort((a,b)=>{const ia=order.indexOf(a),ib=order.indexOf(b);return (ia<0?999:ia)-(ib<0?999:ib)||a.localeCompare(b);});
  accountTabs.innerHTML=[`<button class="inventory-tab ${inventoryAccountFilter==='all'?'active':''}" data-inv-account="all">${t('common.all')} <em>${items.reduce((n,x)=>n+Math.max(1,Number(x.count||1)),0)}</em></button>`].concat(accounts.map(a=>{
    const c=(a.eggItems||[]).reduce((n,x)=>n+Math.max(1,Number(x.count||1)),0); return `<button class="inventory-tab ${inventoryAccountFilter===a.account?'active':''}" data-inv-account="${esc(a.account)}">${esc(a.displayName||a.account)} <em>${c}</em></button>`;
  })).join('');
  rarityHost.innerHTML=[`<button class="rarity-chip ${inventoryRarityFilter==='all'?'active':''}" data-inv-rarity="all">${t('common.all')} <em>${items.reduce((n,x)=>n+Math.max(1,Number(x.count||1)),0)}</em></button>`].concat(rarities.map(r=>{const c=safeColor(rarityColor(r));return `<button class="rarity-chip ${inventoryRarityFilter===r?'active':''}" style="--dot:${c}" data-inv-rarity="${esc(r)}"><i class="dot"></i>${esc(r)} <em>${rarityCounts[r]}</em></button>`;})).join('');
  const q=inventorySearch.trim().toLowerCase();
  const filtered=items.filter(it=>(inventoryRarityFilter==='all'||String(it.rarity||'Unknown')===inventoryRarityFilter)&&(!q||String(it.name||'').toLowerCase().includes(q)));
  $('inventoryCount').textContent=`${filtered.reduce((n,x)=>n+Math.max(1,Number(x.count||1)),0)} ${t('common.total')}`;
  $('inventoryGrid').className='inventory-grid browser-grid';
  $('inventoryGrid').innerHTML=filtered.length?filtered.map(it=>{const c=safeColor(rarityColor(it.rarity));return `<article class="egg-card inventory-browser-card" style="--rarity:${c}"><div class="egg-image"><img loading="lazy" src="${eggImage(it.name)}" onerror="this.onerror=null;this.src='/assets/egg-fallback.svg'"><span>x${fmt(it.count||1)}</span></div><b>${esc(it.name||t('common.unknownEgg'))}</b><div class="egg-bottom"><small class="egg-rarity" style="color:${c}">${esc(it.rarity||'Unknown')}</small>${mutationMarkup(it.mutation)}</div>${it.finalValue!=null?`<div class="egg-final-value">FINAL VALUE <strong>${fmt(it.finalValue)}</strong></div>`:''}<small style="display:block;padding:0 9px 9px;color:#53667c;font-size:8px">${esc(it.displayName)}</small></article>`}).join(''):`<div class="inventory-empty-filter">${t('common.noMatchingEggs')}</div>`;
}
function bindInventoryControls(){
  document.addEventListener('click',e=>{const a=e.target.closest('[data-inv-account]'); if(a){inventoryAccountFilter=a.dataset.invAccount||'all';renderInventory();return;} const r=e.target.closest('[data-inv-rarity]'); if(r){inventoryRarityFilter=r.dataset.invRarity||'all';renderInventory();return;}});
  let inventorySearchTimer=0;
  $('inventorySearch')?.addEventListener('input',e=>{
    inventorySearch=e.target.value||'';
    clearTimeout(inventorySearchTimer);
    inventorySearchTimer=setTimeout(()=>renderInventory(),180);
  });
  $('inventorySearch')?.addEventListener('keydown',e=>{if(e.key==='Escape'){e.currentTarget.value='';inventorySearch='';clearTimeout(inventorySearchTimer);renderInventory();e.currentTarget.blur();}});
}
bindInventoryControls();
async function refreshAll(){try{const a=await get('/api/accounts');$('players').textContent=a.players;$('servers').textContent=a.servers;$('joins').textContent=a.joins;const first=a.accounts.find(x=>x.live)||a.accounts[0]||{};$('currentActivity').textContent=first.activity||'Idle';$('currentActivityDetail').textContent=first.activityDetail||'waiting for telemetry';
$('accountRows').innerHTML=a.accounts.length?a.accounts.map(x=>{
  const rowData={account:x.account,displayName:x.displayName,device:x.device,money:x.money,moneyPerSecond:x.moneyPerSecond||0,speed:x.speed,baseLevel:x.baseLevel??'—',treadmillLevel:x.treadmillLevel??'—',eggInventory:x.eggInventory,eggCapacity:x.eggCapacity,petInventory:x.petInventory,petCapacity:x.petCapacity,eggsStolen:x.eggsStolen,activity:x.activity,jobId:x.jobId,lastSeen:x.lastSeen,live:x.live};
  return `<tr><td><b>${esc(x.account || x.displayName || 'Unknown')}</b><small>${esc(x.displayName && x.displayName!==x.account ? '@'+x.displayName : '')}</small><button class="copy-inline" type="button" data-copy-value="${esc(x.account||'')}" title="${t('common.copyData')}">⧉</button></td><td><span class="device-badge ${String(x.device||'PC').toLowerCase()}"><i></i>${esc(x.device||'PC')}</span><button class="copy-inline" type="button" data-copy-value="${esc(x.device||'')}" title="${t('common.copyData')}">⧉</button></td><td>${activityBadge(x)}<small>${esc(x.activityDetail||'')}</small></td><td>${esc(x.baseLevel??'—')}</td><td>${esc(x.treadmillLevel??'—')}</td><td>${fmt(x.money)}<button class="copy-inline" type="button" data-copy-value="${esc(x.money??0)}" title="${t('common.copyData')}">⧉</button></td><td>${fmt(x.speed)}</td><td class="job-cell"><code class="job-id" title="${esc(x.jobId||'')}">${esc((x.jobId||'').slice(0,14))}${(x.jobId||'').length>14?'…':''}</code><button class="copy-job" type="button" data-job-id="${esc(x.jobId||'')}" title="${t('common.copyJob')}" aria-label="${t('common.copyJob')}">⧉</button></td><td class="last-seen-cell"><span class="${x.live?'live-text':'offline-text'}">${x.live?'🟢 LIVE · now':'🔴 LIVE · now'}</span><small>${ago(x.lastSeen)}</small></td></tr>`;
}).join(''):`<tr><td colspan="9" class="empty">${t('common.noAccounts')}</td></tr>`;
$('activityList').innerHTML=a.accounts.length?a.accounts.slice(0,20).map(x=>`<div class="activity-item"><div class="activity-main"><div class="activity-top"><b>${esc(x.displayName||x.account)}</b>${activityBadge(x)}</div><p>${esc(x.activityDetail||'Idle')}</p></div><div class="activity-right"><span class="${x.live?'live-text':'offline-text'}">${x.live?'🟢 LIVE · now':'🔴 LIVE · now'}</span><small>${ago(x.lastSeen)}</small></div></div>`).join(''):`<div class="empty">${t('common.noActiveAccounts')}</div>`;
const inv=await get('/api/inventory'); latestInventoryAccounts=inv.accounts||[]; renderInventory();
const an=await get('/api/analytics');$('aStolen').textContent=fmt(an.totalEggsStolen);$('aEggInventory').textContent=fmt(an.totalEggInventory);$('aActivity').textContent=an.currentActivity||t('common.idle');$('aActivityDetail').textContent=an.currentActivityDetail||t('analytics.noActiveReport');if($('aEvent'))$('aEvent').textContent='No Event';if($('aArea'))$('aArea').textContent=an.currentArea||'—';
refreshGraph();
const ev=await get('/api/events');$('eventsList').innerHTML=ev.events.length?ev.events.slice(0,80).map(e=>{const egg=e.latestStolenEgg;const c=safeColor(rarityColor(egg?.rarity));const area=e.currentArea||egg?.area||'—';return `<div class="event-row" style="--rarity:${c}"><div class="rarity-bar"></div><div class="event-content"><div class="event-title"><b>${esc(e.displayName||e.account)}</b><span>•</span>${activityBadge(e)}</div><div class="event-meta-line"><span>Event: <strong>No Event</strong></span><span>Area: <strong>${esc(area)}</strong></span></div>${egg?`<div class="stolen"><img src="${eggImage(egg.name)}" onerror="this.onerror=null;this.src='/assets/egg-fallback.svg'"><div><b>${esc(egg.name)}</b><span style="color:${c}">${esc(egg.rarity)}</span>${mutationMarkup(egg.mutation)}${egg.finalValue!=null?`<small class="event-final-value">FINAL ${fmt(egg.finalValue)}</small>`:''}</div></div>`:''}</div><div class="event-time"><b>${esc(e.live?'LIVE':'')}</b><strong>${esc(lastSeenExact(e.createdAt))}</strong><span>${ago(e.createdAt)}</span></div></div>`}).join(''):`<div class="empty">${t('common.noEvents')}</div>`;}catch(e){console.warn('refresh',e);}}
function updateClock(){const parts=new Intl.DateTimeFormat('en-US',{timeZone:'Asia/Bangkok',hour:'2-digit',minute:'2-digit',hour12:true}).format(new Date()).split(' ');$('clock').textContent=parts[0]||'--:--';$('clockAmpm').textContent=parts[1]||'--';}
updateClock();setInterval(updateClock,1000);
let graphAccountFilter='';
let graphData={series:[],resetAt:null};
let graphResetAtMs=0;
function graphFmt(v){return fmt(v);}
function formatCountdown(ms){ms=Math.max(0,ms);const s=Math.floor(ms/1000);const m=Math.floor(s/60);const ss=s%60;return `${String(m).padStart(2,'0')}:${String(ss).padStart(2,'0')}`;}
const graphAnimations = new Map();
function seriesForAnimation(points, key, count){
  if(!count) return [];
  if(!points.length) return Array.from({length:count},()=>0);
  if(points.length===1) return Array.from({length:count},()=>Number(points[0][key]||0));
  return Array.from({length:count},(_,i)=>{
    const pos=(i/(count-1))*(points.length-1), a=Math.floor(pos), b=Math.min(points.length-1,a+1), t=pos-a;
    return Number(points[a]?.[key]||0)*(1-t)+Number(points[b]?.[key]||0)*t;
  });
}
function drawLineChart(canvasId, points, key, label, unit, instant=false){
  const canvas=$(canvasId); if(!canvas)return;
  const dpr=Math.max(1,window.devicePixelRatio||1), rect=canvas.getBoundingClientRect(); const w=Math.max(320,rect.width), h=Math.max(220,rect.height);
  const pad={l:52,r:18,t:18,b:28}; const cw=w-pad.l-pad.r, ch=h-pad.t-pad.b;
  const color=key==='speed'?'#FFD34F':key==='moneyPerSecond'?'#8FE388':'#7CCBFF';
  const current=seriesForAnimation(points,key,Math.max(2,Math.min(60,points.length||2)));
  let state=graphAnimations.get(canvasId);
  if(!state){state={from:current,to:current,started:performance.now(),duration:420,raf:0}; graphAnimations.set(canvasId,state);}
  else {
    const oldElapsed=Math.min(1,(performance.now()-state.started)/state.duration);
    const eased=oldElapsed<.5?2*oldElapsed*oldElapsed:1-Math.pow(-2*oldElapsed+2,2)/2;
    const old=state.from.map((v,i)=>v+(state.to[i]??v-v)*eased);
    const n=Math.max(current.length,old.length);
    state.from=Array.from({length:n},(_,i)=>old[Math.round((i/Math.max(1,n-1))*(old.length-1))]??0);
    state.to=Array.from({length:n},(_,i)=>current[Math.round((i/Math.max(1,n-1))*(current.length-1))]??0);
    state.started=performance.now(); state.duration=instant?0:420;
  }
  if(state.raf) cancelAnimationFrame(state.raf);
  const render=()=>{
    const canvas=$(canvasId); if(!canvas)return;
    canvas.width=Math.floor(w*dpr); canvas.height=Math.floor(h*dpr); const ctx=canvas.getContext('2d');
    ctx.setTransform(dpr,0,0,dpr,0,0); ctx.clearRect(0,0,w,h);
    const elapsed=state.duration===0?1:Math.min(1,(performance.now()-state.started)/state.duration);
    const t=elapsed<.5?2*elapsed*elapsed:1-Math.pow(-2*elapsed+2,2)/2;
    const vals=Array.from({length:Math.max(state.from.length,state.to.length)},(_,i)=>{const a=state.from[i]??0,b=state.to[i]??0;return a+(b-a)*t;});
    const max=Math.max(1,...vals), min=Math.min(0,...vals), span=max-min||1;
    ctx.font='11px Manrope, sans-serif'; ctx.strokeStyle='rgba(255,255,255,.07)'; ctx.lineWidth=1;
    for(let i=0;i<4;i++){const y=pad.t+(ch*i/3);ctx.beginPath();ctx.moveTo(pad.l,y);ctx.lineTo(w-pad.r,y);ctx.stroke();const v=max-(span*i/3);ctx.fillStyle='rgba(142,158,177,.68)';ctx.fillText(graphFmt(v),8,y+4);}
    if(!vals.length || (points.length===0 && vals.every(v=>v===0))){ctx.fillStyle='rgba(108,125,148,.75)';ctx.fillText(t('common.waitingTelemetry'),pad.l+15,pad.t+ch/2);ctx.fillStyle='rgba(108,125,148,.75)';ctx.font='10px Manrope, sans-serif';ctx.fillText(label,pad.l,h-8);ctx.textAlign='right';ctx.fillText(unit||'',w-pad.r,h-8);ctx.textAlign='left';return;}
    const coords=vals.map((v,i)=>{const x=vals.length===1?pad.l+cw/2:pad.l+(i/(vals.length-1))*cw;const y=pad.t+(1-(v-min)/span)*ch;return{x,y};});
    const grad=ctx.createLinearGradient(0,pad.t,0,h-pad.b);grad.addColorStop(0,color+'44');grad.addColorStop(1,'rgba(0,0,0,0)');
    ctx.beginPath();coords.forEach((c,i)=>i?ctx.lineTo(c.x,c.y):ctx.moveTo(c.x,c.y));ctx.lineTo(coords[coords.length-1].x,h-pad.b);ctx.lineTo(coords[0].x,h-pad.b);ctx.closePath();ctx.fillStyle=grad;ctx.fill();
    ctx.beginPath();coords.forEach((c,i)=>i?ctx.lineTo(c.x,c.y):ctx.moveTo(c.x,c.y));ctx.strokeStyle=color;ctx.lineWidth=2.2;ctx.lineCap='round';ctx.lineJoin='round';ctx.shadowBlur=13;ctx.shadowColor=color+'99';ctx.stroke();ctx.shadowBlur=0;
    const last=coords[coords.length-1];ctx.beginPath();ctx.arc(last.x,last.y,4,0,Math.PI*2);ctx.fillStyle=color;ctx.shadowBlur=18;ctx.shadowColor=color;ctx.fill();ctx.shadowBlur=0;
    ctx.fillStyle='rgba(108,125,148,.75)';ctx.font='10px Manrope, sans-serif';ctx.fillText(label,pad.l,h-8);ctx.textAlign='right';ctx.fillText(unit||'',w-pad.r,h-8);ctx.textAlign='left';
    if(elapsed<1){state.raf=requestAnimationFrame(render);} else {state.raf=0;}
  };
  render();
}
async function refreshGraph(){
  try{
    const data=await get(`/api/graph${graphAccountFilter?'&account='+encodeURIComponent(graphAccountFilter):''}`); graphData=data||{};
    const select=$('graphAccount'); if(select){const current=graphAccountFilter; const opts=[`<option value="">${t('common.allAccounts')}</option>`].concat((data.accounts||[]).map(a=>`<option value="${esc(a.account)}">${esc(a.displayName||a.account)}</option>`)); select.innerHTML=opts.join('');select.value=current;}
    $('gSpeed').textContent=graphFmt(data.summary?.speed||0);$('gMoney').textContent=graphFmt(data.summary?.moneyPerSecond||0);$('gStolen').textContent=graphFmt(data.summary?.eggsStolen||0);
    graphResetAtMs=new Date(data.resetAt).getTime();
    const now=Date.now();$('graphReset').textContent=formatCountdown(Math.max(0,graphResetAtMs-now));
    const series=data.series||[];drawLineChart('speedChart',series,'speed',t('graph.speed'),'studs/s');drawLineChart('moneyChart',series,'moneyPerSecond',t('graph.moneyPerSecond'),'/s');drawLineChart('stolenChart',series,'eggsStolen',t('graph.stolen'),'eggs');
  }catch(e){console.warn('graph',e);}
}
setInterval(()=>{
  if(!graphResetAtMs) return;
  const now=Date.now();
  $('graphReset').textContent=formatCountdown(Math.max(0,graphResetAtMs-now));
  if(graphResetAtMs && now>=graphResetAtMs){ graphResetAtMs=0; refreshGraph(); }
},1000);
$('graphAccount')?.addEventListener('change',e=>{graphAccountFilter=e.target.value||'';refreshGraph();});
window.addEventListener('resize',()=>{const s=graphData.series||[];drawLineChart('speedChart',s,'speed',t('graph.speed'),'studs/s');drawLineChart('moneyChart',s,'moneyPerSecond',t('graph.moneyPerSecond'),'/s');drawLineChart('stolenChart',s,'eggsStolen',t('graph.stolen'),'eggs');});

document.querySelectorAll('[data-tab]').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('[data-tab]').forEach(x=>x.classList.toggle('active',x===b));document.querySelectorAll('.view').forEach(v=>v.classList.toggle('active',v.id===b.dataset.tab));if(b.dataset.tab==='graph')refreshGraph();}));
async function copyText(text,button){try{await navigator.clipboard.writeText(String(text));if(button){const old=button.textContent;button.textContent='✓';setTimeout(()=>button.textContent=old,900);}}catch(err){const ta=document.createElement('textarea');ta.value=String(text);ta.style.position='fixed';ta.style.opacity='0';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');if(button){const old=button.textContent;button.textContent='✓';setTimeout(()=>button.textContent=old,900);}}finally{ta.remove();}}}
document.querySelectorAll('.lang-btn').forEach(b=>b.addEventListener('click',()=>setLanguage(b.dataset.lang))); applyLanguage(); $('refresh').addEventListener('click',refreshAll);document.getElementById('logoutBtn')?.addEventListener('click',async()=>{try{await fetch('/api/auth/logout',{method:'POST',credentials:'same-origin'});}finally{location.href='/login.html';}});[document.getElementById('copyTelemetryKey'),document.getElementById('copyTelemetryKeyTop')].forEach(btn=>btn?.addEventListener('click',()=>copyText(CURRENT_USER?.telemetryKey||'',btn)));document.addEventListener('click',async e=>{const job=e.target.closest('.copy-job');if(job){await copyText(job.dataset.jobId||'',job);return;}const inline=e.target.closest('.copy-inline');if(inline){await copyText(inline.dataset.copyValue||'',inline);return;}const row=e.target.closest('.copy-row');if(row){let value='';try{value=JSON.stringify(JSON.parse(decodeURIComponent(row.dataset.copyRow)),null,2);}catch{value=row.dataset.copyRow||'';}await copyText(value,row);return;}const del=e.target.closest('.delete-account');if(del){const account=decodeURIComponent(del.dataset.account||'');if(!account)return;if(!confirm(`Delete account "${account}" from this site?`))return;try{const r=await fetch(withSite('/api/accounts/'+encodeURIComponent(account)),{method:'DELETE',headers:{'x-axel-mutation-token':MUTATION_TOKEN}});const data=await r.json();if(!r.ok||!data.ok)throw new Error(data.error||r.status);await refreshAll();}catch(err){alert((currentLang==='th'?'ลบข้อมูลไม่สำเร็จ: ':'Delete failed: ')+err.message);}}});loadMutationToken().then(refreshAll);setInterval(refreshAll,10000);
// Inspired by the supplied glassmorphism source: animated radial ambient field with mouse parallax.
const canvas=$('bg-canvas'),ctx=canvas.getContext('2d');let w=0,h=0,mx=.5,my=.5,animT=0;function resize(){w=canvas.width=innerWidth;h=canvas.height=innerHeight;}addEventListener('resize',resize);addEventListener('mousemove',e=>{mx=e.clientX/innerWidth;my=e.clientY/innerHeight;});resize();function render(){animT+=.004;const gx=w*(.25+mx*.3),gy=h*(.18+my*.3);const g=ctx.createRadialGradient(gx,gy,20,w*.5,h*.5,Math.max(w,h)*.85);g.addColorStop(0,'rgba(255,210,82,.08)');g.addColorStop(.45,'rgba(255,53,72,.025)');g.addColorStop(1,'rgba(2,3,5,0)');ctx.fillStyle='#020305';ctx.fillRect(0,0,w,h);ctx.fillStyle=g;ctx.fillRect(0,0,w,h);for(let i=0;i<26;i++){const a=animT+i*.7;const x=w*(.5+.38*Math.cos(a*.21+i));const y=h*(.5+.38*Math.sin(a*.17+i*1.7));ctx.beginPath();ctx.arc(x,y,1.2+(i%3),0,Math.PI*2);ctx.fillStyle=`rgba(255,196,65,${.03+(i%4)*.015})`;ctx.fill();}requestAnimationFrame(render);}render();
