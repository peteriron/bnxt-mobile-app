/* BNXT League fan app – clickable prototype (vanilla JS, no build step). Data: window.BNXT + window.IMG from data.js */
(() => {
'use strict';
const D = window.BNXT, IMG = window.IMG || {};
const NOW = new Date('2026-11-03T19:00:00');
const SK = D.statKeys; const I = k => 2 + SK.indexOf(k); const A = k => SK.indexOf(k);
const TM = Object.fromEntries(D.teams.map(t => [t.id, t]));
const PL = Object.fromEntries(D.players.map(p => [p.id, p]));
const GM = Object.fromEntries(D.games.map(g => [g.id, g]));
const ST = Object.fromEntries(D.standings.map(s => [s.team, s]));
const NICK = {541:'Giants Antwerp',561:'Brussels',557:'Okapi Aalst',537:'Spirou Basket',545:'Limburg United',539:'Oostende',549:'Landstede Hammers',555:'Heroes Den Bosch',559:'Leuven Bears',547:'Donar',553:'ZZ Leiden',551:'Rotterdam City',563:'Kangoeroes Mechelen',565:'Kortrijk Spurs',567:'CB Liège',543:'Mons'};
const CITY = {541:'Antwerp',561:'Brussels',557:'Aalst',537:'Charleroi',545:'Hasselt',539:'Ostend',549:'Zwolle',555:"'s-Hertogenbosch",559:'Leuven',547:'Groningen',553:'Leiden',551:'Rotterdam',563:'Mechelen',565:'Kortrijk',567:'Liège',543:'Mons'};
const NAT = {USA:['🇺🇸','United States'],BEL:['🇧🇪','Belgium'],FIN:['🇫🇮','Finland'],ANG:['🇦🇴','Angola'],NED:['🇳🇱','Netherlands'],BUL:['🇧🇬','Bulgaria'],FRA:['🇫🇷','France'],SUI:['🇨🇭','Switzerland'],GEO:['🇬🇪','Georgia'],ESP:['🇪🇸','Spain'],CAN:['🇨🇦','Canada'],AUS:['🇦🇺','Australia'],SLO:['🇸🇮','Slovenia'],GRE:['🇬🇷','Greece'],IRL:['🇮🇪','Ireland'],LAT:['🇱🇻','Latvia'],GBR:['🇬🇧','Great Britain']};
const FLAG = {BE:'🇧🇪', NL:'🇳🇱'};
const POS = {point_guard:['PG','Point guard'],shooting_guard:['SG','Shooting guard'],small_forward:['SF','Small forward'],power_forward:['PF','Power forward'],center:['C','Center']};
const LEAD = [['efficiency','VAL','Efficiency','val'],['points','PTS','Points','pts'],['total_rebound','REB','Rebounds','reb'],['assist','AST','Assists','ast'],['steal','STL','Steals','stl'],['block','BLK','Blocks','blk'],['two_point_percent','2P%','2-point %',null],['three_point_percent','3P%','3-point %',null],['free_throw_percent','FT%','Free throw %',null]];

/* ---------- helpers ---------- */
const $ = (s, r = document) => r.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const store = { get(k){ try { return localStorage.getItem(k); } catch { return null; } }, set(k,v){ try { v==null?localStorage.removeItem(k):localStorage.setItem(k,v); } catch {} } };
const gdate = g => new Date(g.t.replace(' ', 'T'));
const fmtDay = d => d.toLocaleDateString('en-GB', {weekday:'short', day:'numeric', month:'short'});
const fmtLongDay = d => d.toLocaleDateString('en-GB', {weekday:'long', day:'numeric', month:'long'});
const fmtTime = d => d.toLocaleTimeString('en-GB', {hour:'2-digit', minute:'2-digit'});
const r1 = x => (Math.round(x * 10) / 10).toFixed(1);
const pct = (m, a) => a ? (100 * m / a) : 0;
const ord = n => n + (['th','st','nd','rd'][(n % 100 - 20) % 10] || ['th','st','nd','rd'][n % 100] || 'th');
const age = dob => { if (!dob) return null; const b = new Date(dob); let a = NOW.getFullYear() - b.getFullYear(); if (NOW < new Date(NOW.getFullYear(), b.getMonth(), b.getDate())) a--; return a; };
const nick = id => NICK[id] || TM[id].name;
const posShort = p => p ? p.split('-').map(x => (POS[x] || [x])[0]).join('/') : '–';
const posLong = p => p ? p.split('-').map(x => (POS[x] || [, x])[1]).join(' / ') : 'Position n/a';
const daysUntil = d => Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate())) / 864e5);
const relDay = d => { const n = daysUntil(d); return n === 0 ? 'Today' : n === 1 ? 'Tomorrow' : n === -1 ? 'Yesterday' : (n > 1 && n < 7) ? d.toLocaleDateString('en-GB', {weekday:'long'}) : fmtDay(d); };

const ICON = {
  home:'<svg viewBox="0 0 24 24" fill="currentColor"><path d="M11.3 2.7a1 1 0 0 1 1.4 0l8.2 7.6c.7.6.2 1.7-.7 1.7H19v7.5a1.5 1.5 0 0 1-1.5 1.5H15v-5.5a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1V21H6.5A1.5 1.5 0 0 1 5 19.5V12h-1.2c-.9 0-1.4-1.1-.7-1.7l8.2-7.6Z"/></svg>',
  games:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3v18M5.6 5.6c3.2 2.8 3.2 10 0 12.8M18.4 5.6c-3.2 2.8-3.2 10 0 12.8"/></svg>',
  standings:'<svg viewBox="0 0 24 24" fill="currentColor"><rect x="3" y="12" width="5" height="9" rx="1.5"/><rect x="9.5" y="5" width="5" height="16" rx="1.5"/><rect x="16" y="9" width="5" height="12" rx="1.5"/></svg>',
  stats:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 17l5.5-6 4 4L21 6"/><path d="M15 6h6v6"/></svg>',
  clubs:'<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.3 4 5.2v6.2c0 4.9 3.3 8.7 8 10.3 4.7-1.6 8-5.4 8-10.3V5.2l-8-2.9Z"/></svg>',
  back:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>',
  chev:'<svg class="chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M9 5l7 7-7 7"/></svg>',
  search:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5 21 21"/></svg>',
  gear:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.2-4 4.4-6 8-6s6.8 2 8 6"/></svg>',
  star:'<svg viewBox="0 0 24 24" fill="currentColor"><path d="m12 2.5 2.9 6 6.6.8-4.9 4.6 1.3 6.5L12 17.2l-5.9 3.2 1.3-6.5-4.9-4.6 6.6-.8 2.9-6Z"/></svg>',
  staro:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="m12 2.5 2.9 6 6.6.8-4.9 4.6 1.3 6.5L12 17.2l-5.9 3.2 1.3-6.5-4.9-4.6 6.6-.8 2.9-6Z"/></svg>',
  ticket:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M3 8a2 2 0 0 0 2-2h14a2 2 0 0 0 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 0-2 2H5a2 2 0 0 0-2-2v-2a2 2 0 0 0 0-4V8Z"/><path d="M14 6v12" stroke-dasharray="2 2.5"/></svg>',
  tv:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/></svg>',
  pin:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 21s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12Z"/><circle cx="12" cy="9" r="2.5"/></svg>',
  cal:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg>',
  ext:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/></svg>',
  vs:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4 3 8l4 4M3 8h13M17 12l4 4-4 4M21 16H8"/></svg>',
  globe:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.7 5.6 3.7 9s-1.2 6.4-3.7 9c-2.5-2.6-3.7-5.6-3.7-9S9.5 5.6 12 3Z"/></svg>',
  info:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/></svg>',
  replay:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12a8 8 0 1 0 2.4-5.7L4 8.5"/><path d="M4 4v4.5h4.5"/></svg>',
};

const DARK = {};
const logo = (id, s = 28) => IMG['t' + id] ? `<img class="logo${DARK[id] ? ' plate' : ''}" src="${IMG['t' + id]}" width="${s}" height="${s}" alt=""${DARK[id] ? ` style="padding:${Math.max(2, Math.round(s * .14))}px"` : ''}>` : `<span class="logo" style="width:${s}px;height:${s}px"></span>`;
const avatar = (pid, s = 40) => { const p = PL[pid]; if (!p) return ''; const src = IMG['p' + pid];
  return src ? `<span class="av" style="width:${s}px;height:${s}px;background:color-mix(in srgb,${tc(p.team)} 35%,var(--surface3))"><img src="${src}" alt=""></span>`
             : `<span class="av ini" style="width:${s}px;height:${s}px;background:color-mix(in srgb,${tc(p.team)} 35%,var(--surface3))">${esc((p.first[0] || '') + (p.last[0] || ''))}</span>`; };
const pname = p => `${p.first} ${p.last}`;
const pshort = p => `${p.first ? p.first[0] + '. ' : ''}${p.last}`;

/* team colour from logo pixels */
const TC = {};
const tc = id => TC[id] || '#6441ff';
function extractColors() {
  return Promise.all(D.teams.map(t => new Promise(res => {
    const src = IMG['t' + t.id]; if (!src) return res();
    const im = new Image(); im.onload = () => {
      try {
        const c = document.createElement('canvas'); c.width = c.height = 40; const x = c.getContext('2d', {willReadFrequently:true});
        x.drawImage(im, 0, 0, 40, 40); const d = x.getImageData(0, 0, 40, 40).data; const buckets = {};
        for (let i = 0; i < d.length; i += 4) {
          if (d[i + 3] < 200) continue; const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
          const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, s = mx === mn ? 0 : (mx - mn) / (1 - Math.abs(2 * l - 1));
          if (s < .35 || l < .12 || l > .85) continue;
          let h = mx === r ? ((g - b) / (mx - mn)) % 6 : mx === g ? (b - r) / (mx - mn) + 2 : (r - g) / (mx - mn) + 4; h = (h * 60 + 360) % 360;
          const k = Math.round(h / 20); (buckets[k] ||= {n:0, r:0, g:0, b:0}); const B = buckets[k]; B.n += s; B.r += d[i] * s; B.g += d[i + 1] * s; B.b += d[i + 2] * s;
        }
        let lum = 0, n = 0; for (let i = 0; i < d.length; i += 4) if (d[i + 3] > 200) { lum += (.2126 * d[i] + .7152 * d[i + 1] + .0722 * d[i + 2]) / 255; n++; }
        if (n && lum / n < .3) DARK[t.id] = true;
        const best = Object.values(buckets).sort((a, b) => b.n - a.n)[0];
        if (best && best.n > 8) TC[t.id] = `rgb(${best.r / best.n | 0},${best.g / best.n | 0},${best.b / best.n | 0})`;
      } catch {}
      res();
    }; im.onerror = () => res(); im.src = src;
  })));
}

/* ---------- derived data ---------- */
const finished = D.games.filter(g => g.status === 'finished');
const teamGames = id => D.games.filter(g => g.home === id || g.away === id);
const won = (g, id) => (g.home === id ? g.hs > g.as : g.as > g.hs);
const form = id => finished.filter(g => g.home === id || g.away === id).sort((a, b) => b.t.localeCompare(a.t)).slice(0, 5).map(g => won(g, id) ? 'W' : 'L');
const formHTML = id => `<span class="form">${form(id).map(r => `<i class="${r}">${r}</i>`).join('')}</span>`;
const TEAMAGG = {};
D.teams.forEach(t => TEAMAGG[t.id] = {gp:0, pts:0, opp:0, reb:0, ast:0, stl:0, blk:0, tov:0, fgm:0, fga:0, tpm:0, tpa:0, ftm:0, fta:0});
finished.forEach(g => { if (!g.box) return; [[g.home, g.away], [g.away, g.home]].forEach(([a, b]) => {
  const t = g.box[a]?.total, o = g.box[b]?.total; if (!t) return; const X = TEAMAGG[a];
  X.gp++; X.pts += t[A('pts')]; X.opp += o ? o[A('pts')] : 0; X.reb += t[A('reb')]; X.ast += t[A('ast')]; X.stl += t[A('stl')]; X.blk += t[A('blk')]; X.tov += t[A('tov')];
  X.fgm += t[A('fgm')]; X.fga += t[A('fga')]; X.tpm += t[A('3pm')]; X.tpa += t[A('3pa')]; X.ftm += t[A('ftm')]; X.fta += t[A('fta')]; }); });
const tagg = id => { const X = TEAMAGG[id], n = X.gp || 1; return {gp:X.gp, ppg:X.pts / n, opp:X.opp / n, rpg:X.reb / n, apg:X.ast / n, spg:X.stl / n, bpg:X.blk / n, tpg:X.tov / n, fg:pct(X.fgm, X.fga), tp:pct(X.tpm, X.tpa), ft:pct(X.ftm, X.fta)}; };
const leadRank = (pid, key) => { const i = (D.leaders[key] || []).findIndex(x => x[0] === pid); return i < 0 ? null : i + 1; };
const country = id => TM[id].country;
const rankIn = (c) => D.standings.filter(s => !c || country(s.team) === c).sort((a, b) => a.pos - b.pos);
const zone = id => { const c = country(id); const r = rankIn(c).findIndex(s => s.team === id) + 1;
  if (ST[id].pos === 1) return 'lead'; if (c === 'BE' && r <= 8) return 'be'; if (c === 'NL' && r <= 4) return 'nl'; return null; };
const ZC = {lead:'var(--violet-hi)', be:'var(--lime)', nl:'var(--orange)'};
const playerRows = gid => { const g = GM[gid]; const box = boxOf(g); const out = []; if (!box) return out; for (const tid in box) box[tid].players.forEach(r => out.push([+tid, r])); return out; };

/* ---------- state ---------- */
let FAV = +store.get('bnxt.fav') || null;
let LIVE = null;
const isLive = g => LIVE && g.id === LIVE.id && !LIVE.final;
const boxOf = g => (LIVE && g.id === LIVE.id) ? LIVE.box : g.box;

/* =====================================================================
   Live game simulation (demo): fav club's next game is "in progress"
   ===================================================================== */
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const wpick = (arr, w) => { const s = arr.reduce((a, x) => a + w(x), 0); let r = Math.random() * s; for (const x of arr) { r -= w(x); if (r <= 0) return x; } return arr[0]; };
function startLive() {
  clearInterval(startLive.timer); LIVE = null;
  if (!FAV) return;
  const g = D.games.filter(x => x.status !== 'finished' && (x.home === FAV || x.away === FAV)).sort((a, b) => a.t.localeCompare(b.t))[0];
  if (!g) return;
  const L = LIVE = {id:g.id, period:3, clock:460, hq:[], aq:[], box:{}, onCourt:{}, pbp:[], final:false, hs:0, as:0};
  const f = .58;
  [g.home, g.away].forEach(tid => {
    const ros = D.players.filter(p => p.team === tid && p.avg && p.gp > 0).sort((a, b) => b.avg[A('min')] - a.avg[A('min')]).slice(0, 10);
    const rows = ros.map((p, i) => { const a = k => p.avg[A(k)] * f * rnd(.55, 1.45);
      const r = [p.id, i < 5 ? 1 : 0, ...SK.map(() => 0)];
      const tpm = Math.round(a('3pm')), twm = Math.round(a('2pm')), ftm = Math.round(a('ftm'));
      r[I('min')] = Math.round(p.avg[A('min')] * f); r[I('3pm')] = tpm; r[I('3pa')] = tpm + Math.round(a('3pa') - a('3pm') + .3); r[I('2pm')] = twm; r[I('2pa')] = twm + Math.round(a('2pa') - a('2pm') + .3);
      r[I('ftm')] = ftm; r[I('fta')] = ftm + Math.round(Math.max(0, a('fta') - a('ftm'))); r[I('oreb')] = Math.round(a('oreb')); r[I('dreb')] = Math.round(a('dreb'));
      ['ast','stl','blk','tov','pf'].forEach(k => r[I(k)] = Math.round(a(k))); r[I('pf')] = Math.min(4, r[I('pf')]);
      return r; });
    L.box[tid] = {players:rows, total:SK.map(() => 0)}; L.onCourt[tid] = rows.slice(0, 5).map(r => r[0]);
  });
  recalc();
  const split = (tot) => { const elapsed = 23.8; const q1 = Math.round(tot * 10 / elapsed * rnd(.85, 1.1)); const q2 = Math.round((tot - q1) * 10 / 13.8 * rnd(.9, 1.08)); return [q1, q2, Math.max(0, tot - q1 - q2)]; };
  L.hq = split(L.hs); L.aq = split(L.as);
  L.pbp.push({sys:true, txt:'Start of Q3'});
  for (let i = 0; i < 11; i++) { L.clock -= Math.round(rnd(5, 10)); liveEvent(true); }
  L.clock = Math.max(L.clock, 300);
  let next = Date.now() + rnd(3500, 6500);
  startLive.timer = setInterval(() => {
    if (L.final) return;
    L.clock--; L.onCourt[g.home].concat(L.onCourt[g.away]).forEach(pid => { const r = rowOf(pid); if (r) r[I('min')] += 1 / 60; });
    if (L.clock <= 0) endPeriod();
    else if (Date.now() > next) { liveEvent(false); next = Date.now() + rnd(3500, 7000); }
    liveTick();
  }, 1000);
}
function rowOf(pid) { for (const t in LIVE.box) { const r = LIVE.box[t].players.find(x => x[0] === pid); if (r) return r; } return null; }
function recalc() {
  const L = LIVE, g = GM[L.id];
  for (const tid in L.box) {
    const B = L.box[tid]; B.total = SK.map(() => 0);
    B.players.forEach(r => {
      r[I('fgm')] = r[I('2pm')] + r[I('3pm')]; r[I('fga')] = r[I('2pa')] + r[I('3pa')]; r[I('reb')] = r[I('oreb')] + r[I('dreb')];
      r[I('pts')] = 2 * r[I('2pm')] + 3 * r[I('3pm')] + r[I('ftm')];
      r[I('val')] = r[I('pts')] + r[I('reb')] + r[I('ast')] + r[I('stl')] + r[I('blk')] - (r[I('fga')] - r[I('fgm')]) - (r[I('fta')] - r[I('ftm')]) - r[I('tov')] - r[I('pf')];
      SK.forEach((k, i) => B.total[i] += r[2 + i]);
    });
  }
  L.hs = L.box[g.home].total[A('pts')]; L.as = L.box[g.away].total[A('pts')];
  for (const tid in L.box) { const me = L.box[tid].total[A('pts')], op = L.box[+tid === g.home ? g.away : g.home].total[A('pts')]; L.box[tid].players.forEach(r => r[I('pm')] = 0); L.box[tid].total[A('pm')] = me - op; }
}
function liveEvent(silent) {
  const L = LIVE, g = GM[L.id];
  const off = Math.random() < .52 ? g.home : g.away, def = off === g.home ? g.away : g.home;
  const oc = L.onCourt[off].map(rowOf).filter(Boolean), dc = L.onCourt[def].map(rowOf).filter(Boolean);
  if (!oc.length || !dc.length) return;
  const shooter = wpick(oc, r => (PL[r[0]].avg?.[A('pts')] || 2) + 2), mate = pick(oc.filter(r => r !== shooter)) || shooter, defender = pick(dc);
  const P = r => `<b>${esc(pshort(PL[r[0]]))}</b>`, team = TM[off].short;
  const roll = Math.random(); let txt, pts = 0;
  const assist = () => { if (Math.random() < .6) { mate[I('ast')]++; return ` (assist ${esc(pshort(PL[mate[0]]))})`; } return ''; };
  if (roll < .30) { shooter[I('2pm')]++; shooter[I('2pa')]++; pts = 2; txt = `${P(shooter)} ${pick(['makes a driving layup','hits a pull-up jumper','finishes at the rim','scores on the floater','throws down a dunk','hits the turnaround'])}${assist()}`; }
  else if (roll < .42) { shooter[I('3pm')]++; shooter[I('3pa')]++; pts = 3; txt = `${P(shooter)} ${pick(['buries a three','hits from the corner','drains a step-back three','knocks down a three'])}${assist()}`; }
  else if (roll < .62) { const three = Math.random() < .4; shooter[I(three ? '3pa' : '2pa')]++; const oreb = Math.random() < .27; const rb = oreb ? pick(oc) : defender; rb[I(oreb ? 'oreb' : 'dreb')]++;
    txt = `${P(shooter)} misses the ${three ? 'three' : 'jumper'}, ${oreb ? 'offensive' : 'defensive'} rebound ${esc(pshort(PL[rb[0]]))}`; }
  else if (roll < .70) { const m = (Math.random() < .76) + (Math.random() < .76); shooter[I('fta')] += 2; shooter[I('ftm')] += m; defender[I('pf')]++; pts = m; txt = `${P(shooter)} makes ${m} of 2 free throws`; }
  else if (roll < .79) { shooter[I('tov')]++; defender[I('stl')]++; txt = `${P(defender)} steals it from ${esc(pshort(PL[shooter[0]]))}`; }
  else if (roll < .86) { defender[I('pf')]++; txt = `Foul on <b>${esc(pshort(PL[defender[0]]))}</b> (${defender[I('pf')]} PF)`; }
  else if (roll < .92) { shooter[I('2pa')]++; defender[I('blk')]++; txt = `${P(defender)} blocks ${esc(pshort(PL[shooter[0]]))}`; }
  else if (roll < .96) { // substitution
    const bench = L.box[off].players.filter(r => !L.onCourt[off].includes(r[0])); if (bench.length) { const inn = pick(bench), outi = Math.floor(Math.random() * 5); const out = L.onCourt[off][outi]; L.onCourt[off][outi] = inn[0];
      txt = `Sub ${esc(team)}: <b>${esc(pshort(PL[inn[0]]))}</b> in for ${esc(pshort(PL[out]))}`; } else txt = `Timeout ${esc(nick(off))}`; }
  else txt = `Timeout <b>${esc(nick(off))}</b>`;
  recalc();
  if (pts) { const q = off === g.home ? L.hq : L.aq; q[L.period - 1] = (q[L.period - 1] || 0) + pts; }
  L.pbp.unshift({p:L.period, c:L.clock, team:off, txt, pts, hs:L.hs, as:L.as, three:pts === 3 && roll >= .30 && roll < .42});
  if (!silent) onLiveEvent(off, pts);
}
function endPeriod() {
  const L = LIVE;
  L.pbp.unshift({sys:true, txt:`End of Q${L.period}`});
  if (L.period >= 4 && L.hs !== L.as) { L.final = true; L.pbp.unshift({sys:true, txt:'Final'}); clearInterval(startLive.timer); invalidateAll(); toast('Final: ' + TM[GM[L.id].home].short + ' ' + L.hs + '–' + L.as + ' ' + TM[GM[L.id].away].short); return; }
  L.period++; L.clock = L.period > 4 ? 300 : 600; L.hq[L.period - 1] = 0; L.aq[L.period - 1] = 0; L.pbp.unshift({sys:true, txt:`Start of ${L.period > 4 ? 'OT' : 'Q' + L.period}`});
}
const clockTxt = () => { if (!LIVE) return ''; if (LIVE.final) return 'Final'; const c = Math.max(0, LIVE.clock); return `${LIVE.period > 4 ? 'OT' : 'Q' + LIVE.period} ${Math.floor(c / 60)}:${String(c % 60).padStart(2, '0')}`; };
function liveTick() { document.querySelectorAll('[data-lv="clock"]').forEach(e => e.textContent = clockTxt()); }
function onLiveEvent(team, pts) {
  const L = LIVE;
  document.querySelectorAll('[data-lv="hs"],[data-lv="as"]').forEach(e => { const v = e.dataset.lv === 'hs' ? L.hs : L.as; if (+e.textContent !== v) { e.textContent = v; e.classList.remove('bump'); void e.offsetWidth; e.classList.add('bump'); } });
  document.querySelectorAll('[data-lv="last"]').forEach(e => e.innerHTML = lastPlayHTML());
  refreshLiveViews(true);
}
const lastPlayHTML = () => { const e = LIVE && LIVE.pbp.find(x => !x.sys); return e ? `${logo(e.team, 18)}<span>${e.txt}</span>` : ''; };
function refreshLiveViews(isEvent) { allRoutes().forEach(r => { if (r.name === 'game' && LIVE && r.id === LIVE.id) rerender(r, isEvent); }); }

/* =====================================================================
   Navigation
   ===================================================================== */
const TABS = [['home','Home'],['games','Games'],['standings','Standings'],['stats','Stats'],['clubs','Clubs']];
const stacks = {}; let curTab = 'home'; const routeOf = new WeakMap();
const allRoutes = () => Object.values(stacks).flat();
const topRoute = () => stacks[curTab][stacks[curTab].length - 1];
function buildChrome() {
  const panes = $('#panes');
  panes.innerHTML = TABS.map(([k]) => `<div class="pane" id="pane-${k}"></div>`).join('');
  $('#tabbar').innerHTML = TABS.map(([k, l]) => `<button type="button" class="tab" data-tab="${k}" aria-label="${l}">${ICON[k]}<span>${l}</span></button>`).join('');
  TABS.forEach(([k]) => { stacks[k] = []; mountView({name:k, s:{}}, k, false); });
  switchTab('home');
}
function makeView(route, root) {
  const v = VIEWS[route.name](route);
  const el = document.createElement('section'); el.className = 'view' + (v.hero ? ' hero-view' : '');
  el.innerHTML = `<header class="nav">${root ? '<span></span>' : `<button class="back" type="button" data-act="back">${ICON.back}<span>${esc(route.backLabel || 'Back')}</span></button>`}<div class="nav-title">${esc(v.title)}</div><div class="nav-act">${v.actions || ''}</div></header><div class="scroller"><div class="content">${v.large ? `<h1 class="lt">${esc(v.title)}</h1>` : ''}${v.body}</div></div>`;
  const sc = el.querySelector('.scroller');
  sc.addEventListener('scroll', () => el.classList.toggle('scrolled', sc.scrollTop > (v.large ? 34 : v.hero ? 150 : 8)), {passive:true});
  route.el = el; route.v = v; routeOf.set(el, route);
  return el;
}
function mountView(route, tab, animate) {
  const st = stacks[tab]; const prev = st[st.length - 1];
  const el = makeView(route, st.length === 0);
  if (animate) el.classList.add('enter');
  $('#pane-' + tab).appendChild(el); st.push(route);
  route.v.mount && route.v.mount(el, route);
  if (animate) { void el.offsetWidth; el.classList.remove('enter'); prev && prev.el.classList.add('below'); }
  else if (prev) prev.el.classList.add('below');
}
function push(route) { const cur = topRoute(); route.backLabel = cur.v.backTitle || cur.v.title; route.s = route.s || {}; mountView(route, curTab, true); }
function pop() {
  const st = stacks[curTab]; if (st.length < 2) return; const r = st.pop(); const prev = st[st.length - 1];
  void r.el.offsetWidth; r.el.classList.add('enter'); prev.el.classList.remove('below');
  if (prev.dirty) { prev.dirty = false; rerender(prev); }
  setTimeout(() => r.el.remove(), 400);
}
function popToRoot(tab) { const st = stacks[tab]; while (st.length > 1) { const r = st.pop(); r.el.remove(); } st[0].el.classList.remove('below'); st[0].el.querySelector('.scroller').scrollTo({top:0, behavior:'smooth'}); rerender(st[0]); }
function switchTab(tab) {
  if (tab === curTab && stacks[tab].length > 1) return popToRoot(tab);
  curTab = tab;
  document.querySelectorAll('.pane').forEach(p => p.classList.toggle('on', p.id === 'pane-' + tab));
  document.querySelectorAll('.tab').forEach(b => { b.classList.toggle('on', b.dataset.tab === tab); b.setAttribute('aria-current', b.dataset.tab === tab ? 'page' : 'false'); });
  const t = topRoute(); if (t && t.dirty) { t.dirty = false; rerender(t); }
}
function rerender(route, fromLive) {
  if (!route.el) return;
  const sc = route.el.querySelector('.scroller'); const top = sc.scrollTop;
  const hs = [...route.el.querySelectorAll('[data-keep]')].map(e => [e.dataset.keep, e.scrollLeft]);
  const v = VIEWS[route.name](route); route.v = v;
  route.el.querySelector('.content').innerHTML = (v.large ? `<h1 class="lt">${esc(v.title)}</h1>` : '') + v.body;
  route.el.querySelector('.nav-act').innerHTML = v.actions || '';
  route.el.querySelector('.nav-title').textContent = v.title;
  sc.scrollTop = top; hs.forEach(([k, x]) => { const e = route.el.querySelector(`[data-keep="${k}"]`); if (e) e.scrollLeft = x; });
  if (fromLive) route.el.querySelectorAll('.pb').forEach((e, i) => { if (i === 0 && !e.classList.contains('sys')) e.classList.add('new'); });
  v.mount && v.mount(route.el, route);
}
function invalidateAll() { allRoutes().forEach(r => { r.dirty = true; }); const t = topRoute(); if (t) { t.dirty = false; rerender(t); } }

/* ---------- toast & sheet ---------- */
let toastT;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.remove('on'), 2400); }
function openSheet(title, html, mount) { $('#sheet-title').textContent = title; $('#sheet-b').innerHTML = html; $('#sheet').classList.add('open'); $('#sheet-b').scrollTop = 0; mount && mount($('#sheet-b')); }
function closeSheet() { $('#sheet').classList.remove('open'); }

/* =====================================================================
   Shared components
   ===================================================================== */
function gameRow(g, opt = {}) {
  const d = gdate(g), live = isLive(g), fin = g.status === 'finished' || (LIVE && g.id === LIVE.id && LIVE.final);
  const hs = live || (LIVE && g.id === LIVE.id) ? LIVE.hs : g.hs, as = live || (LIVE && g.id === LIVE.id) ? LIVE.as : g.as;
  const side = (id, sc, osc, k) => `<div class="g-t ${fin && sc > osc ? 'win' : live ? 'win' : ''} ${id === FAV ? 'fav' : ''}">${logo(id, 26)}<span class="nm">${esc(nick(id))}</span>${fin || live ? `<span class="sc"${live ? ` data-lv="${k}"` : ''}>${sc}</span>` : ''}</div>`;
  const meta = live ? `<span class="pill live" style="justify-self:end">Live</span><b data-lv="clock">${clockTxt()}</b>`
    : fin ? `<b>Final</b><span>${opt.noDate ? '' : fmtDay(d)}</span>` : `<b>${fmtTime(d)}</b><span>${opt.noDate ? '' : relDay(d)}</span>`;
  return `<button type="button" class="g-row" data-go="game:${g.id}"><div class="g-teams">${side(g.home, hs, as, 'hs')}${side(g.away, as, hs, 'as')}</div><div class="g-meta">${meta}</div></button>`;
}
function groupByDay(games, desc) {
  const m = new Map(); games.forEach(g => { const k = g.t.slice(0, 10); if (!m.has(k)) m.set(k, []); m.get(k).push(g); });
  const keys = [...m.keys()].sort(); if (desc) keys.reverse();
  return keys.map(k => { const d = new Date(k + 'T12:00:00'); const n = daysUntil(d); const lab = n === 0 ? 'Today' : n === 1 ? 'Tomorrow' : n === -1 ? 'Yesterday' : fmtLongDay(d);
    return `<div class="games-day"><span class="cap">${lab}</span><div class="list">${m.get(k).map(g => gameRow(g, {noDate:true})).join('')}</div></div>`; }).join('');
}
const seg = (k, cur, opts) => `<div class="seg" role="tablist">${opts.map(([v, l]) => `<button type="button" role="tab" aria-selected="${cur === v}" class="${cur === v ? 'on' : ''}" data-act="seg" data-k="${k}" data-v="${v}">${l}</button>`).join('')}</div>`;
const secH = (t, more) => `<div class="sec-h"><h2>${t}</h2>${more || ''}</div>`;

/* =====================================================================
   Views
   ===================================================================== */
const VIEWS = {};

/* ---------- HOME ---------- */
VIEWS.home = () => {
  if (!FAV) return {title:'Home', body:''};
  const t = TM[FAV], s = ST[FAV];
  const tg = teamGames(FAV).sort((a, b) => a.t.localeCompare(b.t));
  const last = tg.filter(g => g.status === 'finished').pop();
  const upcoming = tg.filter(g => g.status !== 'finished' && !(LIVE && g.id === LIVE.id));
  const next = upcoming[0];
  let html = `<div class="home-head">${logo(FAV, 46)}<div class="who"><span class="cap">My club</span><h1>${esc(nick(FAV))}</h1></div><div class="acts"><button class="circ" type="button" data-act="search" aria-label="Search">${ICON.search}</button><button class="circ" type="button" data-act="settings" aria-label="Settings">${ICON.gear}</button></div></div>`;
  if (LIVE) { const g = GM[LIVE.id]; const L = LIVE;
    html += `<button type="button" class="livecard" style="--tc:${tc(FAV)}" data-go="game:${g.id}">
      <div class="lc-top">${L.final ? '<span class="pill">Final</span>' : `<span class="pill live"><span data-lv="clock">${clockTxt()}</span></span>`}<span class="demo">Simulated</span></div>
      <div class="lc-score"><div class="lc-team">${logo(g.home, 52)}<span>${esc(nick(g.home))}</span></div>
      <div class="lc-num"><span data-lv="hs">${L.hs}</span><span class="dash">–</span><span data-lv="as">${L.as}</span></div>
      <div class="lc-team">${logo(g.away, 52)}<span>${esc(nick(g.away))}</span></div></div>
      <div class="lc-last" data-lv="last">${lastPlayHTML()}</div></button>`; }
  html += `<div class="duo">`;
  if (next) { const d = gdate(next); const opp = next.home === FAV ? next.away : next.home; const n = daysUntil(d);
    html += `<button type="button" class="card mini" data-go="game:${next.id}"><span class="cap">Next game</span><div class="vs">${logo(opp, 30)}<span>${next.home === FAV ? 'vs' : '@'} ${esc(TM[opp].short)}</span></div><div><div class="big">${n <= 0 ? 'Today' : 'In ' + n + 'd'}</div><div class="t2 muted" style="font-size:13px;margin-top:4px">${fmtDay(d)} · ${fmtTime(d)}</div></div></button>`; }
  if (last) { const opp = last.home === FAV ? last.away : last.home; const w = won(last, FAV); const my = last.home === FAV ? last.hs : last.as, op = last.home === FAV ? last.as : last.hs;
    html += `<button type="button" class="card mini" data-go="game:${last.id}"><span class="cap">Last result</span><div class="vs">${logo(opp, 30)}<span>${last.home === FAV ? 'vs' : '@'} ${esc(TM[opp].short)}</span></div><div style="display:flex;align-items:center;gap:8px"><span class="pill ${w ? 'w' : 'l'}">${w ? 'W' : 'L'}</span><span class="big">${my}–${op}</span></div></button>`; }
  html += `</div>`;
  // standing
  const c = country(FAV), natRank = rankIn(c).findIndex(x => x.team === FAV) + 1, z = zone(FAV);
  const all = rankIn(), i = all.findIndex(x => x.team === FAV), win = all.slice(Math.max(0, Math.min(i - 2, all.length - 5)), Math.max(0, Math.min(i - 2, all.length - 5)) + 5);
  html += `<div class="sec">${secH('Standing', '<button type="button" class="more" data-tab="standings">Full table</button>')}<button type="button" class="card standcard" data-tab="standings">
    <div class="sc-head"><div class="sc-pos">${s.pos}<sup>${ord(s.pos).replace(/\d+/, '')}</sup></div><div><div style="font-weight:700;font-size:16px">${s.w}–${s.l} · ${s.streak[0] === 'W' ? 'Won' : 'Lost'} ${s.streak.slice(1)}</div><div class="muted" style="font-size:13px;margin-top:3px">${ord(natRank)} of the ${c === 'BE' ? 'Belgian' : 'Dutch'} clubs · ${z && z !== 'lead' ? 'in a playoff place' : z === 'lead' ? 'top of the league' : 'outside the playoff places'}</div></div></div>
    ${win.map(r => `<div class="sr ${r.team === FAV ? 'me' : ''}"><span class="p">${r.pos}</span>${logo(r.team, 22)}<span>${esc(nick(r.team))}</span><span class="r">${r.w}–${r.l}</span><span class="r">${r.diff > 0 ? '+' : ''}${r.diff}</span></div>`).join('')}</button></div>`;
  // team leaders
  const ros = D.players.filter(p => p.team === FAV && p.avg && p.gp > 0);
  const best = k => ros.slice().sort((a, b) => b.avg[A(k)] - a.avg[A(k)])[0];
  html += `<div class="sec">${secH('Club leaders', `<button type="button" class="more" data-go="club:${FAV}">Roster</button>`)}<div class="leaders4">${[['pts','PTS'],['reb','REB'],['ast','AST'],['val','VAL']].map(([k, l]) => { const p = best(k); return p ? `<button type="button" class="card ld" data-go="player:${p.id}">${avatar(p.id, 42)}<div style="min-width:0"><div class="k">${l}</div><div class="v">${r1(p.avg[A(k)])}</div><div class="n">${esc(pshort(p))}</div></div></button>` : ''; }).join('')}</div></div>`;
  // around the league
  const lastDay = finished.map(g => g.t).sort().pop().slice(0, 10);
  const recent = finished.filter(g => g.t.slice(0, 10) >= new Date(new Date(lastDay).getTime() - 3 * 864e5).toISOString().slice(0, 10)).sort((a, b) => b.t.localeCompare(a.t));
  html += `<div class="sec">${secH('Around the league', '<button type="button" class="more" data-tab="games">All games</button>')}<div class="carousel" data-keep="atl">${recent.map(g => `<button type="button" class="card rc" data-go="game:${g.id}"><span class="cap">${fmtDay(gdate(g))}</span><div class="l ${g.hs > g.as ? 'win' : ''}">${logo(g.home, 22)}${esc(TM[g.home].short)}<span class="s">${g.hs}</span></div><div class="l ${g.as > g.hs ? 'win' : ''}">${logo(g.away, 22)}${esc(TM[g.away].short)}<span class="s">${g.as}</span></div></button>`).join('')}</div></div>`;
  // league leaders teaser
  html += `<div class="sec">${secH('League leaders', '<button type="button" class="more" data-tab="stats">See all</button>')}<div class="list">${D.leaders.efficiency.slice(0, 3).map(([pid, v], i) => { const p = PL[pid]; return `<button type="button" class="row rk-row" data-go="player:${pid}"><span class="rk">${i + 1}</span>${avatar(pid, 40)}<div class="grow"><div class="t1">${esc(pname(p))}</div><div class="t2">${esc(nick(p.team))}</div></div><div style="text-align:right"><div class="val">${r1(v)}</div><div class="cap" style="font-size:10px">VAL</div></div></button>`; }).join('')}</div></div>`;
  return {title:nick(FAV), backTitle:'Home', body:html};
};

/* ---------- GAMES ---------- */
VIEWS.games = (r) => {
  const s = r.s; s.mode ||= 'upcoming'; s.mine ??= false;
  let gs = D.games.filter(g => !s.mine || g.home === FAV || g.away === FAV);
  let html = seg('mode', s.mode, [['upcoming','Upcoming'],['results','Results']]);
  html += `<div class="chips" style="margin-top:12px"><button type="button" class="chip ${s.mine ? '' : 'on'}" data-act="seg" data-k="mine" data-v="0">All clubs</button>${FAV ? `<button type="button" class="chip ${s.mine ? 'on' : ''}" data-act="seg" data-k="mine" data-v="1">${logo(FAV, 18)} ${esc(nick(FAV))}</button>` : ''}</div>`;
  if (s.mode === 'upcoming') {
    const lv = LIVE && !LIVE.final && gs.find(g => g.id === LIVE.id);
    if (lv) html += `<div class="games-day"><span class="cap" style="color:#ff8a99">Live now</span><div class="list">${gameRow(lv, {noDate:true})}</div></div>`;
    const up = gs.filter(g => g.status !== 'finished' && !(LIVE && g.id === LIVE.id));
    html += up.length ? groupByDay(up) : `<div class="empty">No upcoming games in the published schedule yet.</div>`;
  } else {
    const fin = gs.filter(g => g.status === 'finished');
    const lf = LIVE && LIVE.final && gs.find(g => g.id === LIVE.id);
    if (lf) html += `<div class="games-day"><span class="cap">Today</span><div class="list">${gameRow(lf, {noDate:true})}</div></div>`;
    html += groupByDay(fin, true);
  }
  return {title:'Games', large:true, body:html};
};

/* ---------- GAME DETAIL ---------- */
VIEWS.game = (r) => {
  const g = GM[r.id], d = gdate(g), live = isLive(g), simulated = LIVE && g.id === LIVE.id;
  const fin = g.status === 'finished' || (simulated && LIVE.final);
  const hs = simulated ? LIVE.hs : g.hs, as = simulated ? LIVE.as : g.as;
  const hq = simulated ? LIVE.hq : g.hq, aq = simulated ? LIVE.aq : g.aq;
  const box = boxOf(g);
  const s = r.s; s.tab ||= live ? 'pbp' : fin ? 'sum' : 'pre';
  const metaTop = live ? `<span class="pill live"><span data-lv="clock">${clockTxt()}</span></span> <span class="demo" style="margin-left:6px">Simulated</span>`
    : `${fin ? 'Final' : relDay(d) + ' · ' + fmtTime(d)} · ${esc(g.arena || CITY[g.home])}`;
  const mid = (fin || live) ? `<div class="gh-num"><span class="${fin && hs < as ? 'lose' : ''}" ${live ? 'data-lv="hs"' : ''}>${hs}</span><span class="dash">–</span><span class="${fin && as < hs ? 'lose' : ''}" ${live ? 'data-lv="as"' : ''}>${as}</span></div>`
    : `<div class="gh-time">${fmtTime(d)}</div><span class="cap">${fmtDay(d)}</span>`;
  let html = `<div class="gh" style="--hc:${tc(g.home)};--ac:${tc(g.away)}"><div class="meta">BNXT League · Regular season</div><div class="meta" style="margin-top:6px">${metaTop}</div>
    <div class="gh-score"><button type="button" class="gh-team" data-go="club:${g.home}">${logo(g.home, 64)}<span class="n">${esc(nick(g.home))}</span><span class="cap" style="font-size:10px">${esc(ST[g.home].w + '–' + ST[g.home].l)} · Home</span></button>
    <div class="gh-mid">${mid}</div>
    <button type="button" class="gh-team" data-go="club:${g.away}">${logo(g.away, 64)}<span class="n">${esc(nick(g.away))}</span><span class="cap" style="font-size:10px">${esc(ST[g.away].w + '–' + ST[g.away].l)} · Away</span></button></div></div>`;
  if (hq && hq.length) {
    const n = Math.max(4, hq.length);
    html += `<div class="card" style="margin-top:4px;overflow:hidden"><table class="qt"><thead><tr><th></th>${Array.from({length:n}, (_, i) => `<th>${i < 4 ? 'Q' + (i + 1) : 'OT'}</th>`).join('')}<th>T</th></tr></thead><tbody>
      ${[[g.home, hq, hs], [g.away, aq, as]].map(([id, q, t]) => `<tr><td><span class="tn">${logo(id, 20)}${esc(TM[id].short)}</span></td>${Array.from({length:n}, (_, i) => `<td>${q[i] ?? '–'}</td>`).join('')}<td class="t">${t}</td></tr>`).join('')}</tbody></table></div>`;
  }
  const tabs = live ? [['pbp','Play-by-play'],['box','Box score'],['sum','Summary'],['info','Info']] : fin ? [['sum','Summary'],['box','Box score'],['info','Info']] : [['pre','Preview'],['info','Info']];
  if (!tabs.find(t => t[0] === s.tab)) s.tab = tabs[0][0];
  html += `<div style="margin-top:16px">${seg('tab', s.tab, tabs)}</div>`;
  if (s.tab === 'pbp') html += `<div class="card pbp" style="margin-top:14px;overflow:hidden">${LIVE.pbp.slice(0, 60).map(e => e.sys ? `<div class="pb sys">${e.txt}</div>` : `<div class="pb ${e.pts ? 'pts' : ''} ${e.three ? 'pts3' : ''}"><span class="clk">${e.p > 4 ? 'OT' : 'Q' + e.p} ${Math.floor(e.c / 60)}:${String(e.c % 60).padStart(2, '0')}</span>${logo(e.team, 24)}<span class="tx">${e.txt}</span><span class="scr">${e.hs}–${e.as}</span></div>`).join('')}</div>`;
  if (s.tab === 'sum' && box) html += summaryHTML(g, box);
  if (s.tab === 'box' && box) { s.team ||= g.home; html += boxHTML(g, box, s.team); }
  if (s.tab === 'pre') html += previewHTML(g);
  if (s.tab === 'info') html += infoHTML(g, d, fin);
  return {title:`${TM[g.home].short} ${fin || live ? hs + '–' + as : 'vs'} ${TM[g.away].short}`, backTitle:'Game', hero:true, body:html};
};
function summaryHTML(g, box) {
  const top = id => box[id].players.slice().sort((a, b) => b[I('val')] - a[I('val')])[0];
  let h = `<div class="sec">${secH('Top performers')}<div class="tp">${[g.home, g.away].map(id => { const r = top(id); if (!r) return ''; const p = PL[r[0]];
    return `<button type="button" class="card" data-go="player:${p.id}">${avatar(p.id, 64)}<div><div style="font-weight:700;font-size:14.5px">${esc(pname(p))}</div><div class="t2 muted" style="font-size:12px;margin-top:2px;display:flex;gap:5px;justify-content:center;align-items:center">${logo(id, 14)}${esc(TM[id].short)} · #${esc(p.num)}</div></div><div class="line"><b>${r[I('pts')]}</b> PTS · <b>${r[I('reb')]}</b> REB · <b>${r[I('ast')]}</b> AST</div><div class="line">VAL <b>${Math.round(r[I('val')])}</b></div></button>`; }).join('')}</div></div>`;
  const T = id => box[id].total; const a = T(g.home), b = T(g.away);
  const rows = [['Field goals', 'fg'], ['3-pointers', 'tp'], ['Free throws', 'ft'], ['Rebounds', 'reb'], ['Assists', 'ast'], ['Steals', 'stl'], ['Blocks', 'blk'], ['Turnovers', 'tov']];
  h += `<div class="sec">${secH('Team comparison')}<div class="card" style="padding:8px 0">${rows.map(([lab, k]) => {
    let x, y, xs, ys;
    if (k === 'fg') { x = pct(a[A('fgm')], a[A('fga')]); y = pct(b[A('fgm')], b[A('fga')]); xs = `${a[A('fgm')]}/${a[A('fga')]}`; ys = `${b[A('fgm')]}/${b[A('fga')]}`; }
    else if (k === 'tp') { x = pct(a[A('3pm')], a[A('3pa')]); y = pct(b[A('3pm')], b[A('3pa')]); xs = `${a[A('3pm')]}/${a[A('3pa')]}`; ys = `${b[A('3pm')]}/${b[A('3pa')]}`; }
    else if (k === 'ft') { x = pct(a[A('ftm')], a[A('fta')]); y = pct(b[A('ftm')], b[A('fta')]); xs = `${a[A('ftm')]}/${a[A('fta')]}`; ys = `${b[A('ftm')]}/${b[A('fta')]}`; }
    else { x = a[A(k)]; y = b[A(k)]; }
    const pctk = ['fg', 'tp', 'ft'].includes(k); const tot = (x + y) || 1; const better = k === 'tov' ? x < y : x > y; const worse = k === 'tov' ? x > y : x < y;
    return `<div class="cmpbar"><div class="lab">${lab}</div><span class="a ${worse ? 'dim' : ''}">${pctk ? Math.round(x) + '%' : x}</span><div><div class="bars"><i style="flex:${x / tot};background:${better ? tc(g.home) : 'var(--surface3)'}"></i><i style="flex:${y / tot};background:${worse ? tc(g.away) : 'var(--surface3)'}"></i></div>${pctk ? `<div style="display:flex;justify-content:space-between;font-size:11px;color:var(--fg3);margin-top:4px"><span>${xs}</span><span>${ys}</span></div>` : ''}</div><span class="b ${better ? 'dim' : ''}">${pctk ? Math.round(y) + '%' : y}</span></div>`; }).join('')}</div></div>`;
  h += `<div class="sec">${secH('Game leaders')}<div class="list">${[['pts','Points'],['reb','Rebounds'],['ast','Assists']].map(([k, l]) => {
    const best = id => box[id].players.slice().sort((p, q) => q[I(k)] - p[I(k)])[0]; const x = best(g.home), y = best(g.away);
    return `<div class="row" style="display:grid;grid-template-columns:1fr auto 1fr;gap:8px"><button type="button" data-go="player:${x[0]}" style="display:flex;gap:8px;align-items:center;min-width:0">${avatar(x[0], 32)}<span style="min-width:0"><span class="t1" style="display:block;font-size:13.5px">${esc(PL[x[0]].last)}</span><span style="font:italic 800 17px var(--display)">${x[I(k)]}</span></span></button><span class="cap" style="align-self:center">${l}</span><button type="button" data-go="player:${y[0]}" style="display:flex;gap:8px;align-items:center;justify-content:flex-end;min-width:0;text-align:right"><span style="min-width:0"><span class="t1" style="display:block;font-size:13.5px">${esc(PL[y[0]].last)}</span><span style="font:italic 800 17px var(--display)">${y[I(k)]}</span></span>${avatar(y[0], 32)}</button></div>`; }).join('')}</div></div>`;
  return h;
}
function boxHTML(g, box, team) {
  const B = box[team]; const showPM = B.players.some(r => r[I('pm')]);
  const cols = [['MIN', r => Math.floor(r[I('min')])], ['PTS', r => r[I('pts')], 1], ['REB', r => r[I('reb')]], ['AST', r => r[I('ast')]], ['STL', r => r[I('stl')]], ['BLK', r => r[I('blk')]], ['FG', r => `${r[I('fgm')]}-${r[I('fga')]}`], ['3P', r => `${r[I('3pm')]}-${r[I('3pa')]}`], ['FT', r => `${r[I('ftm')]}-${r[I('fta')]}`], ['OR', r => r[I('oreb')]], ['TO', r => r[I('tov')]], ['PF', r => r[I('pf')]]].concat(showPM ? [['+/-', r => (r[I('pm')] > 0 ? '+' : '') + r[I('pm')]]] : []).concat([['VAL', r => Math.round(r[I('val')]), 1]]);
  const rows = B.players.slice().sort((a, b) => (b[1] - a[1]) || (b[I('min')] - a[I('min')]));
  const tot = [0, 0, ...B.total];
  return `<div style="margin-top:14px;display:flex;gap:8px">${[g.home, g.away].map(id => `<button type="button" class="chip ${id === team ? 'on' : ''}" data-act="seg" data-k="team" data-v="${id}" style="flex:1;justify-content:center">${logo(id, 20)} ${esc(nick(id))}</button>`).join('')}</div>
  <div class="tblwrap" style="margin-top:10px" data-keep="box"><table class="bx"><thead><tr><th>Player</th>${cols.map(c => `<th>${c[0]}</th>`).join('')}</tr></thead><tbody>
  ${rows.map(r => { const p = PL[r[0]]; return `<tr data-go="player:${r[0]}" style="cursor:pointer"><td><span class="pn"><small>${esc(p?.num ?? '')}</small><span class="${r[1] ? 'st' : ''}">${esc(p ? pshort(p) : '?')}</span></span></td>${cols.map(c => `<td class="${c[2] ? 'hl' : ''}">${c[1](r)}</td>`).join('')}</tr>`; }).join('')}
  <tr class="tot"><td>Team</td>${cols.map(c => `<td>${c[0] === 'MIN' ? '' : c[1](tot)}</td>`).join('')}</tr></tbody></table></div>
  <p class="muted" style="font-size:12px;margin:10px 4px 0"><span style="display:inline-block;width:5px;height:5px;border-radius:50%;background:var(--violet-hi);vertical-align:middle;margin-right:6px"></span>Starter · Scroll the table sideways for more · Tap a player for their page</p>`;
}
function previewHTML(g) {
  const a = tagg(g.home), b = tagg(g.away);
  const rows = [['Record', `${ST[g.home].w}–${ST[g.home].l}`, `${ST[g.away].w}–${ST[g.away].l}`], ['Position', ord(ST[g.home].pos), ord(ST[g.away].pos)], ['Points per game', r1(a.ppg), r1(b.ppg)], ['Points allowed', r1(a.opp), r1(b.opp)], ['Rebounds', r1(a.rpg), r1(b.rpg)], ['Assists', r1(a.apg), r1(b.apg)], ['FG%', r1(a.fg), r1(b.fg)], ['3P%', r1(a.tp), r1(b.tp)]];
  let h = `<div class="sec">${secH('Season so far')}<div class="card" style="overflow:hidden"><table class="qt"><thead><tr><th>${logo(g.home, 22)}</th><th></th><th style="text-align:right;padding-right:14px">${logo(g.away, 22)}</th></tr></thead><tbody>${rows.map(([l, x, y]) => `<tr><td style="font-weight:700;color:var(--fg)">${x}</td><td style="font-size:12px;color:var(--fg3);font-weight:600">${l}</td><td style="text-align:right;padding-right:14px;font-weight:700;color:var(--fg)">${y}</td></tr>`).join('')}
    <tr><td>${formHTML(g.home)}</td><td style="font-size:12px;color:var(--fg3);font-weight:600">Last 5</td><td style="text-align:right;padding-right:14px"><span style="display:inline-flex">${formHTML(g.away)}</span></td></tr></tbody></table></div></div>`;
  h += `<div class="sec">${secH('Players to watch')}<div class="tp">${[g.home, g.away].map(id => { const p = D.players.filter(x => x.team === id && x.avg && x.gp > 0).sort((x, y) => y.avg[A('val')] - x.avg[A('val')])[0]; if (!p) return '<div></div>';
    return `<button type="button" class="card" data-go="player:${p.id}">${avatar(p.id, 64)}<div><div style="font-weight:700;font-size:14.5px">${esc(pname(p))}</div><div class="muted" style="font-size:12px;margin-top:2px">${esc(nick(id))}</div></div><div class="line"><b>${r1(p.avg[A('pts')])}</b> PTS · <b>${r1(p.avg[A('reb')])}</b> REB · <b>${r1(p.avg[A('val')])}</b> VAL</div></button>`; }).join('')}</div></div>`;
  h += `<div class="sec btn-row"><a class="btn pri" href="${esc(TM[g.home].ticket)}" target="_blank" rel="noopener">${ICON.ticket} Tickets</a><button type="button" class="btn" data-act="cal" data-id="${g.id}">${ICON.cal} Add to Calendar</button></div>`;
  const prev = finished.filter(x => (x.home === g.home && x.away === g.away) || (x.home === g.away && x.away === g.home));
  if (prev.length) h += `<div class="sec">${secH('Earlier this season')}<div class="list">${prev.map(x => gameRow(x)).join('')}</div></div>`;
  return h;
}
function infoHTML(g, d, fin) {
  const t = TM[g.home];
  return `<div class="sec list info">
    <div class="row"><span class="ico">${ICON.cal}</span><div class="grow"><div class="t1">${fmtLongDay(d)}</div><div class="t2">Tip-off ${fmtTime(d)} (CET)</div></div></div>
    <div class="row"><span class="ico">${ICON.pin}</span><div class="grow"><div class="t1">${esc(g.arena || 'Arena to be confirmed')}</div><div class="t2">${esc(CITY[g.home])}, ${t.country === 'BE' ? 'Belgium' : 'Netherlands'}</div></div></div>
    <a class="row" href="https://www.bnxt.tv/" target="_blank" rel="noopener"><span class="ico">${ICON.tv}</span><div class="grow"><div class="t1">Where to watch</div><div class="t2">Live and on demand on BNXT.tv</div></div>${ICON.ext.replace('<svg', '<svg class="chev"')}</a>
    ${fin ? '' : `<a class="row" href="${esc(t.ticket)}" target="_blank" rel="noopener"><span class="ico">${ICON.ticket}</span><div class="grow"><div class="t1">Tickets</div><div class="t2">Sold by ${esc(nick(g.home))}</div></div>${ICON.ext.replace('<svg', '<svg class="chev"')}</a>`}
    <a class="row" href="https://bnxtleague.com/en/game-report/${g.id}" target="_blank" rel="noopener"><span class="ico">${ICON.globe}</span><div class="grow"><div class="t1">Game report on bnxtleague.com</div><div class="t2">Official page for this game</div></div>${ICON.ext.replace('<svg', '<svg class="chev"')}</a>
  </div>`;
}

/* ---------- STANDINGS ---------- */
VIEWS.standings = (r) => {
  const s = r.s; s.ph ||= 'league';
  let html = seg('ph', s.ph, [['league','League'],['BE','Belgium'],['NL','Netherlands'],['po','Playoffs']]);
  html += `<p class="muted" style="font-size:13px;margin:12px 4px 0">Regular season 2026-27 · after ${Math.max(...D.standings.map(x => x.w + x.l))} of 30 games</p>`;
  if (s.ph === 'po') html += bracketHTML();
  else {
    const c = s.ph === 'league' ? null : s.ph; const rows = rankIn(c); const cut = c === 'BE' ? 8 : c === 'NL' ? 4 : 0;
    html += `<div class="card" style="margin-top:12px;overflow:hidden"><table class="st-tbl"><thead><tr><th></th><th>Club</th><th>W</th><th>L</th><th>+/-</th><th>Strk</th></tr></thead><tbody>
      ${rows.map((x, i) => { const z = c ? (i < cut ? (c === 'BE' ? 'be' : 'nl') : null) : zone(x.team);
        return `<tr class="${x.team === FAV ? 'me' : ''} ${cut && i === cut ? 'cut' : ''}" data-go="club:${x.team}"><td class="rk" style="--z:${z ? ZC[z] : 'transparent'}">${c ? i + 1 : x.pos}</td><td class="tm"><span class="tmc">${logo(x.team, 24)}<span>${esc(nick(x.team))}</span>${c ? '' : `<span class="flag" aria-label="${x.team && TM[x.team].country}">${FLAG[TM[x.team].country]}</span>`}</span></td><td class="w">${x.w}</td><td>${x.l}</td><td>${x.diff > 0 ? '+' : ''}${x.diff}</td><td style="color:${x.streak[0] === 'W' ? 'var(--win)' : 'var(--loss)'}">${x.streak}</td></tr>`; }).join('')}
    </tbody></table></div>`;
    html += `<div class="card legend" style="margin-top:12px">${!c ? `<div><i style="background:var(--violet-hi)"></i>League leader. First place after game 30 is crowned BNXT Champion.</div>` : ''}${!c || c === 'BE' ? `<div><i style="background:var(--lime)"></i>Belgian playoff place (top 8 Belgian clubs)</div>` : ''}${!c || c === 'NL' ? `<div><i style="background:var(--orange)"></i>Dutch playoff place (top 4 Dutch clubs)</div>` : ''}<div><i style="background:var(--surface3)"></i>No relegation this season</div></div>`;
  }
  html += `<div class="sec card fmt"><h3>How the season works</h3><div>All <b>16 clubs</b> play each other home and away, for <b>30 games</b> each between 2 October 2026 and 8 May 2027. The club on top after game 30 is the <b>BNXT Champion</b>.</div><div>Then each country plays its own playoffs. In <b>Belgium</b> the top 8 play best-of-3 quarter-finals, best-of-5 semi-finals and a best-of-5 final. In the <b>Netherlands</b> the top 4 play best-of-5 semi-finals and a best-of-7 final.</div></div>`;
  return {title:'Standings', large:true, body:html};
};
function bracketHTML() {
  const be = rankIn('BE').slice(0, 8).map(x => x.team), nl = rankIn('NL').slice(0, 4).map(x => x.team);
  const bt = (id, seed) => id ? `<div class="bt ${id === FAV ? 'me' : ''}"><span class="sd">${seed}</span>${logo(id, 20)}<span>${esc(TM[id].short)}</span><span style="margin-left:auto;font-size:12px;color:var(--fg3)">${ST[id].w}–${ST[id].l}</span></div>` : `<div class="bt tbd"><span class="sd"></span>To be decided</div>`;
  const m = (a, sa, b, sb) => `<div class="bm">${bt(a, sa)}${bt(b, sb)}</div>`;
  const tbd = `<div class="bm">${bt(null)}${bt(null)}</div>`;
  return `<div class="sec">${secH(`${FLAG.BE} Belgian playoffs`, '<span class="pill">Projected</span>')}<div class="bracket" data-keep="brbe">
    <div class="bcol"><span class="cap">Quarter-finals · Bo3</span>${m(be[0], 1, be[7], 8)}${m(be[3], 4, be[4], 5)}${m(be[1], 2, be[6], 7)}${m(be[2], 3, be[5], 6)}</div>
    <div class="bcol"><span class="cap">Semi-finals · Bo5</span>${tbd}${tbd}</div><div class="bcol"><span class="cap">Final · Bo5</span>${tbd}</div></div></div>
    <div class="sec">${secH(`${FLAG.NL} Dutch playoffs`, '<span class="pill">Projected</span>')}<div class="bracket" data-keep="brnl">
    <div class="bcol"><span class="cap">Semi-finals · Bo5</span>${m(nl[0], 1, nl[3], 4)}${m(nl[1], 2, nl[2], 3)}</div><div class="bcol"><span class="cap">Final · Bo7</span>${tbd}</div></div></div>
    <p class="muted" style="font-size:12.5px;margin:10px 4px 0">This is how the brackets would look if the regular season ended today. Playoffs start on 14 May 2027, and the higher seed has home-court advantage.</p>`;
}

/* ---------- STATS ---------- */
VIEWS.stats = (r) => {
  const s = r.s; s.mode ||= 'players'; s.cat ||= 'efficiency'; s.tcat ||= 'ppg';
  let html = seg('mode', s.mode, [['players','Players'],['teams','Teams']]);
  if (s.mode === 'players') {
    html += `<div class="chips" style="margin-top:12px" data-keep="cats">${LEAD.map(([k, l]) => `<button type="button" class="chip ${s.cat === k ? 'on' : ''}" data-act="seg" data-k="cat" data-v="${k}">${l}</button>`).join('')}</div>`;
    const L = LEAD.find(x => x[0] === s.cat); const list = D.leaders[s.cat] || []; const isPct = !L[3];
    const fmt = v => isPct ? r1(v) + '%' : r1(v);
    if (list.length) { const [pid, v] = list[0]; const p = PL[pid];
      html += `<button type="button" class="lead-hero" style="margin-top:14px;--tc:${tc(p.team)}" data-go="player:${pid}"><div class="txt"><div><span class="cap" style="color:var(--fg)">${esc(L[2])} leader</span></div><div><div class="v">${fmt(v)}</div><div class="n">${esc(pname(p))}</div><div class="muted" style="font-size:13px;display:flex;gap:6px;align-items:center;margin-top:4px">${logo(p.team, 16)}${esc(nick(p.team))}</div></div></div>${IMG['p' + pid] ? `<img class="ph" src="${IMG['p' + pid]}" alt="">` : '<span></span>'}</button>`;
      const max = list[0][1];
      html += `<div class="list" style="margin-top:12px">${list.slice(1, 20).map(([pid, v], i) => { const p = PL[pid]; return `<button type="button" class="row rk-row" data-go="player:${pid}"><span class="rk">${i + 2}</span>${avatar(pid, 38)}<div class="grow"><div class="t1">${esc(pname(p))}</div><div class="t2">${esc(nick(p.team))}</div><div class="meter"><i style="width:${(100 * v / max).toFixed(1)}%;background:${tc(p.team)}"></i></div></div><span class="val">${fmt(v)}</span></button>`; }).join('')}</div>`;
      html += `<p class="muted" style="font-size:12px;margin:10px 4px 0">Per-game averages, regular season 2026-27. VAL is the FIBA efficiency rating. Shooting percentages need a minimum number of attempts.</p>`;
    }
  } else {
    const TC2 = [['ppg','Points','Points scored per game'],['opp','Defense','Points allowed per game (lower is better)'],['rpg','Rebounds','Rebounds per game'],['apg','Assists','Assists per game'],['fg','FG%','Field goal percentage'],['tp','3P%','3-point percentage'],['spg','Steals','Steals per game'],['tpg','Turnovers','Turnovers per game (lower is better)']];
    html += `<div class="chips" style="margin-top:12px" data-keep="tcats">${TC2.map(([k, l]) => `<button type="button" class="chip ${s.tcat === k ? 'on' : ''}" data-act="seg" data-k="tcat" data-v="${k}">${l}</button>`).join('')}</div>`;
    const c = TC2.find(x => x[0] === s.tcat); const asc = ['opp', 'tpg'].includes(s.tcat);
    const rows = D.teams.map(t => [t.id, tagg(t.id)[s.tcat]]).sort((a, b) => asc ? a[1] - b[1] : b[1] - a[1]);
    const mx = Math.max(...rows.map(x => x[1])), mn = Math.min(...rows.map(x => x[1]));
    html += `<p class="muted" style="font-size:13px;margin:12px 4px 0">${c[2]}</p><div class="list" style="margin-top:10px">${rows.map(([id, v], i) => `<button type="button" class="row rk-row ${id === FAV ? 'me' : ''}" data-go="club:${id}" ${id === FAV ? 'style="background:rgba(226,255,0,.06)"' : ''}><span class="rk">${i + 1}</span>${logo(id, 30)}<div class="grow"><div class="t1">${esc(nick(id))}</div><div class="meter"><i style="width:${(20 + 80 * (v - mn) / ((mx - mn) || 1)).toFixed(1)}%;background:${tc(id)}"></i></div></div><span class="val">${r1(v)}${['fg', 'tp'].includes(s.tcat) ? '%' : ''}</span></button>`).join('')}</div>`;
  }
  return {title:'Stats', large:true, body:html, actions:`<button class="circ" type="button" data-go="compare:0" aria-label="Compare players">${ICON.vs}</button>`};
};

/* ---------- COMPARE ---------- */
const CMP = {a:null, b:null};
VIEWS.compare = () => {
  if (!CMP.a) { const favBest = D.players.filter(p => p.team === FAV && p.avg && p.gp > 0).sort((x, y) => y.avg[A('val')] - x.avg[A('val')])[0]; CMP.a = favBest ? favBest.id : D.leaders.efficiency[1][0]; }
  if (!CMP.b) CMP.b = D.leaders.efficiency.find(x => x[0] !== CMP.a)[0];
  const a = PL[CMP.a], b = PL[CMP.b];
  const slot = (p, k) => `<button type="button" class="card slot ${k}" data-act="cmpPick" data-slot="${k}">${avatar(p.id, 76)}<div class="nm">${esc(pname(p))}</div><div class="tm" style="display:flex;gap:5px;align-items:center">${logo(p.team, 14)}${esc(nick(p.team))}</div><div class="tm">${posShort(p.pos)} · ${p.h ? p.h + ' cm' : '–'} · ${age(p.dob) ?? '–'} yrs</div><span class="swap">Change</span></button>`;
  const v = (p, k) => { const x = p.avg; if (!x) return 0; if (k === 'fg') return pct(x[A('fgm')], x[A('fga')]); if (k === '3p') return pct(x[A('3pm')], x[A('3pa')]); if (k === 'ft') return pct(x[A('ftm')], x[A('fta')]); if (k === 'gp') return p.gp; return x[A(k)]; };
  const stats = [['pts','Points'],['reb','Rebounds'],['ast','Assists'],['stl','Steals'],['blk','Blocks'],['tov','Turnovers'],['fg','FG%'],['3p','3P%'],['ft','FT%'],['val','Efficiency (VAL)'],['min','Minutes'],['gp','Games']];
  const max = {pts:30, reb:12, ast:8, stl:3, blk:2.5, tov:5, fg:100, '3p':100, ft:100, val:30, min:40, gp:30};
  let html = `<div class="cmp-head">${slot(a, 'a')}${slot(b, 'b')}</div><div class="card" style="margin-top:12px;padding:6px 0">${stats.map(([k, l]) => {
    const x = v(a, k), y = v(b, k); const lowGood = k === 'tov'; const aw = lowGood ? x < y : x > y, bw = lowGood ? y < x : y > x; const f = n => ['fg', '3p', 'ft'].includes(k) ? Math.round(n) + '%' : k === 'gp' ? n : r1(n);
    return `<div class="mir"><div class="lab">${l}</div><span class="x ${aw ? '' : 'lo'}">${f(x)}</span><div class="track"><span><i style="width:${Math.min(100, 100 * x / max[k])}%;background:${aw ? 'var(--violet)' : 'var(--fg3)'}"></i></span><span><i style="width:${Math.min(100, 100 * y / max[k])}%;background:${bw ? 'var(--orange)' : 'var(--fg3)'}"></i></span></div><span class="x r ${bw ? '' : 'lo'}">${f(y)}</span></div>`; }).join('')}</div>
    <p class="muted" style="font-size:12px;margin:10px 4px 0">Per-game season averages, 2026-27. The better value in each row is highlighted.</p>`;
  return {title:'Compare', body:html};
};
function cmpPicker(slot) {
  const list = D.players.filter(p => p.avg && p.gp > 0).sort((x, y) => y.avg[A('val')] - x.avg[A('val')]);
  const render = q => { q = q.trim().toLowerCase(); return list.filter(p => !q || pname(p).toLowerCase().includes(q) || nick(p.team).toLowerCase().includes(q)).slice(0, 40).map(p => `<button type="button" class="row" data-act="cmpSet" data-slot="${slot}" data-pid="${p.id}">${avatar(p.id, 38)}<div class="grow"><div class="t1">${esc(pname(p))}</div><div class="t2">${esc(nick(p.team))} · ${r1(p.avg[A('pts')])} PTS · ${r1(p.avg[A('val')])} VAL</div></div></button>`).join('') || '<div class="empty">No players match that search.</div>'; };
  openSheet(slot === 'a' ? 'Choose player 1' : 'Choose player 2', `<label class="search" style="margin-bottom:12px">${ICON.search}<input id="cmp-q" type="search" placeholder="Search by player or club" autocomplete="off"></label><div class="list" id="cmp-list">${render('')}</div>`,
    b => { const i = b.querySelector('#cmp-q'); i.addEventListener('input', () => b.querySelector('#cmp-list').innerHTML = render(i.value)); });
}

/* ---------- CLUBS ---------- */
VIEWS.clubs = (r) => {
  const card = t => `<button type="button" class="card cg ${t.id === FAV ? 'me' : ''}" data-go="club:${t.id}">${t.id === FAV ? `<span class="star">${ICON.star}</span>` : ''}${logo(t.id, 52)}<span class="n">${esc(nick(t.id))}</span><span class="r">${ST[t.id].w}–${ST[t.id].l} · ${ord(ST[t.id].pos)}</span></button>`;
  const grp = (c, l) => `<div class="sec">${secH(`${FLAG[c]} ${l}`, `<span class="muted" style="font-size:13px">${D.teams.filter(t => t.country === c).length} clubs</span>`)}<div class="club-grid">${D.teams.filter(t => t.country === c).sort((a, b) => nick(a.id).localeCompare(nick(b.id))).map(card).join('')}</div></div>`;
  return {title:'Clubs', large:true, body:`<button type="button" class="search" data-act="search" style="width:100%">${ICON.search}<span>Search players and clubs</span></button>${grp('BE', 'Belgium')}${grp('NL', 'Netherlands')}`};
};
VIEWS.club = (r) => {
  const t = TM[r.id], s = ST[t.id], a = tagg(t.id); const st = r.s; st.tab ||= 'roster';
  let html = `<div class="ch" style="--tc:${tc(t.id)}">${IMG['t' + t.id] ? `<img class="wm" src="${IMG['t' + t.id]}" alt="">` : ''}<div class="top">${logo(t.id, 76)}<div style="min-width:0"><h1>${esc(nick(t.id))}</h1><div class="sub">${FLAG[t.country]} ${esc(CITY[t.id])} · ${esc(t.arena || '')}</div><div class="sub" style="margin-top:2px;font-size:12px;color:var(--fg3)">${esc(t.name)}</div></div></div>
    <div class="facts"><div><b>${s.w}–${s.l}</b><span>Record</span></div><div><b>${ord(s.pos)}</b><span>League</span></div><div><b>${r1(a.ppg)}</b><span>PPG</span></div><div><b>${r1(a.opp)}</b><span>Opp PPG</span></div></div>
    <div class="btn-row" style="margin-top:14px;position:relative"><button type="button" class="btn ${t.id === FAV ? 'lime' : ''}" data-act="fav" data-id="${t.id}">${t.id === FAV ? ICON.star + ' My club' : ICON.staro + ' Make my club'}</button><a class="btn pri" href="${esc(t.ticket)}" target="_blank" rel="noopener">${ICON.ticket} Tickets</a></div></div>`;
  html += `<div style="margin-top:14px">${seg('tab', st.tab, [['roster','Roster'],['games','Games'],['stats','Player stats']])}</div>`;
  if (st.tab === 'roster') {
    const ros = D.players.filter(p => p.team === t.id && p.pos !== undefined).sort((x, y) => (+x.num || 99) - (+y.num || 99));
    html += `<div class="list" style="margin-top:12px">${ros.map(p => `<button type="button" class="row" data-go="player:${p.id}"><span style="width:24px;text-align:right;font:italic 800 15px var(--display);color:var(--fg3)">${esc(p.num)}</span>${avatar(p.id, 42)}<div class="grow"><div class="t1">${esc(pname(p))}</div><div class="t2">${posLong(p.pos)}${p.h ? ' · ' + p.h + ' cm' : ''}${NAT[p.nat] ? ' · ' + NAT[p.nat][0] : ''}</div></div>${p.avg ? `<span style="text-align:right"><b style="font:italic 800 16px var(--display)">${r1(p.avg[A('pts')])}</b><span class="cap" style="display:block;font-size:9.5px">PTS</span></span>` : ''}${ICON.chev}</button>`).join('')}</div>`;
    html += `<p class="muted" style="font-size:12px;margin:10px 4px 0">Coaching staff isn't published in the league feed yet.</p>`;
  } else if (st.tab === 'games') {
    const tg = teamGames(t.id).sort((x, y) => x.t.localeCompare(y.t));
    const up = tg.filter(g => g.status !== 'finished'), fin = tg.filter(g => g.status === 'finished').reverse();
    html += `<div class="sec" style="margin-top:16px">${secH('Upcoming')}<div class="list">${up.map(g => gameRow(g)).join('') || '<div class="empty">No games scheduled</div>'}</div></div><div class="sec">${secH('Results', formHTML(t.id))}<div class="list">${fin.map(g => gameRow(g)).join('')}</div></div>`;
  } else {
    st.sort ||= 'pts';
    const ros = D.players.filter(p => p.team === t.id && p.avg && p.gp > 0).sort((x, y) => y.avg[A(st.sort)] - x.avg[A(st.sort)]);
    const cols = [['gp','GP'],['min','MIN'],['pts','PTS'],['reb','REB'],['ast','AST'],['stl','STL'],['blk','BLK'],['tov','TO'],['val','VAL']];
    html += `<div class="tblwrap" style="margin-top:12px" data-keep="pst"><table class="bx"><thead><tr><th>Player</th>${cols.map(([k, l]) => k === 'gp' ? `<th>${l}</th>` : `<th class="${st.sort === k ? 'sort' : ''}" data-act="seg" data-k="sort" data-v="${k}" style="cursor:pointer">${l}</th>`).join('')}<th>FG%</th><th>3P%</th><th>FT%</th></tr></thead><tbody>
      ${ros.map(p => `<tr data-go="player:${p.id}" style="cursor:pointer"><td><span class="pn"><small>${esc(p.num)}</small>${esc(pshort(p))}</span></td>${cols.map(([k]) => `<td class="${st.sort === k ? 'hl' : ''}">${k === 'gp' ? p.gp : r1(p.avg[A(k)])}</td>`).join('')}<td>${r1(pct(p.avg[A('fgm')], p.avg[A('fga')]))}</td><td>${r1(pct(p.avg[A('3pm')], p.avg[A('3pa')]))}</td><td>${r1(pct(p.avg[A('ftm')], p.avg[A('fta')]))}</td></tr>`).join('')}</tbody></table></div><p class="muted" style="font-size:12px;margin:10px 4px 0">Per-game averages. Tap a column heading to sort by it.</p>`;
  }
  return {title:nick(t.id), hero:true, body:html};
};

/* ---------- PLAYER ---------- */
VIEWS.player = (r) => {
  const p = PL[r.id], t = TM[p.team], a = p.avg;
  let html = `<div class="ph" style="--tc:${tc(p.team)}"><div class="jn">${esc(p.num)}</div>${IMG['p' + p.id] ? `<img class="cut" src="${IMG['p' + p.id]}" alt="">` : `<div class="ini-big">${esc((p.first[0] || '') + (p.last[0] || ''))}</div>`}
    <div class="who"><div class="fn">${esc(p.first)}</div><div class="ln">${esc(p.last)}</div><button type="button" class="tm" data-go="club:${t.id}">${logo(t.id, 20)}${esc(nick(t.id))} · #${esc(p.num)}</button></div></div>`;
  html += `<div class="card bio"><div><b>${posShort(p.pos)}</b><span>Position</span></div><div><b>${p.h ? (p.h / 100).toFixed(2) + ' m' : '–'}</b><span>Height</span></div><div><b>${age(p.dob) ?? '–'}</b><span>Age</span></div><div><b>${NAT[p.nat] ? NAT[p.nat][0] + ' ' + esc(p.nat) : esc(p.nat || '–')}</b><span>Nation</span></div></div>`;
  if (!a) { html += `<div class="card empty" style="margin-top:16px">${esc(p.first)} hasn't played a game this season yet.</div>`; return {title:pname(p), hero:true, body:html}; }
  const rb = key => { const k = leadRank(p.id, key); return k && k <= 10 ? `#${k} in league` : ''; };
  html += `<div class="sec">${secH('Season averages', `<span class="muted" style="font-size:13px">${p.gp} games · ${r1(a[A('min')])} min</span>`)}<div class="avg4">${[['pts','PTS','points'],['reb','REB','total_rebound'],['ast','AST','assist'],['val','VAL','efficiency']].map(([k, l, lk]) => `<div class="card"><span class="k">${l}</span><span class="v">${r1(a[A(k)])}</span><span class="rkb">${rb(lk)}</span></div>`).join('')}</div>
    <div class="avg4" style="margin-top:8px">${[['stl','STL','steal'],['blk','BLK','block'],['tov','TO',null],['pf','PF',null]].map(([k, l, lk]) => `<div class="card" style="padding:10px 6px"><span class="k">${l}</span><span class="v" style="font-size:20px">${r1(a[A(k)])}</span>${lk ? `<span class="rkb">${rb(lk)}</span>` : ''}</div>`).join('')}</div></div>`;
  const ring = (lab, m, at) => { const v = pct(m, at), C = 2 * Math.PI * 26; return `<div class="ring"><svg viewBox="0 0 62 62"><circle cx="31" cy="31" r="26" fill="none" stroke="var(--surface3)" stroke-width="6"/><circle cx="31" cy="31" r="26" fill="none" stroke="${tc(p.team)}" stroke-width="6" stroke-linecap="round" stroke-dasharray="${(C * v / 100).toFixed(1)} ${C.toFixed(1)}" transform="rotate(-90 31 31)"/><text x="31" y="35.5" text-anchor="middle" fill="var(--fg)" font-size="13.5" font-weight="800" font-family="-apple-system,BlinkMacSystemFont,sans-serif">${Math.round(v)}%</text></svg><span class="k">${lab}</span><span class="m">${r1(m)}/${r1(at)}</span></div>`; };
  html += `<div class="sec">${secH('Shooting')}<div class="card shoot">${ring('FG', a[A('fgm')], a[A('fga')])}${ring('2PT', a[A('2pm')], a[A('2pa')])}${ring('3PT', a[A('3pm')], a[A('3pa')])}${ring('FT', a[A('ftm')], a[A('fta')])}</div></div>`;
  const log = p.log.map(gid => { const g = GM[gid]; const row = playerRows(gid).find(([, rr]) => rr[0] === p.id); return row ? {g, r:row[1], tid:row[0]} : null; }).filter(Boolean).sort((x, y) => x.g.t.localeCompare(y.g.t));
  if (log.length) {
    const W = 340, H = 110, padL = 22, padR = 14, padT = 14, padB = 22; const pts = log.map(x => x.r[I('pts')]); const mx = Math.max(10, Math.ceil(Math.max(...pts) / 5) * 5);
    const X = i => padL + (log.length === 1 ? (W - padL - padR) / 2 : i * (W - padL - padR) / (log.length - 1)), Y = v => padT + (H - padT - padB) * (1 - v / mx);
    const path = pts.map((v, i) => `${i ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`).join(''); const avg = a[A('pts')];
    const col = tc(p.team);
    html += `<div class="sec">${secH('Points per game')}<div class="card spark"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Points per game this season">
      ${[0, mx / 2, mx].map(v => `<line x1="${padL}" x2="${W - padR}" y1="${Y(v)}" y2="${Y(v)}" stroke="var(--line)" stroke-width="1"/><text x="${padL - 6}" y="${Y(v) + 4}" text-anchor="end" font-size="10" fill="var(--fg3)">${v}</text>`).join('')}
      <line x1="${padL}" x2="${W - padR}" y1="${Y(avg)}" y2="${Y(avg)}" stroke="var(--lime)" stroke-width="1" stroke-dasharray="3 4" opacity=".7"/><text x="${W - padR}" y="${Y(avg) - 5}" text-anchor="end" font-size="10" fill="var(--lime)" font-weight="700">avg ${r1(avg)}</text>
      <path d="${path}L${X(pts.length - 1).toFixed(1)},${Y(0)}L${X(0).toFixed(1)},${Y(0)}Z" fill="${col}" opacity=".16"/><path d="${path}" fill="none" stroke="${col}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>
      ${pts.map((v, i) => `<circle cx="${X(i).toFixed(1)}" cy="${Y(v).toFixed(1)}" r="${i === pts.length - 1 ? 4.5 : 3}" fill="${i === pts.length - 1 ? 'var(--fg)' : col}"/><text x="${X(i).toFixed(1)}" y="${H - 6}" text-anchor="middle" font-size="9.5" fill="var(--fg3)">${esc(TM[log[i].g.home === log[i].tid ? log[i].g.away : log[i].g.home].short)}</text>`).join('')}
    </svg></div></div>`;
    html += `<div class="sec">${secH('Game log')}<div class="list"><div class="gl h"><span style="text-align:left">Game</span><span>MIN</span><span>PTS</span><span>REB</span><span>AST</span></div>${log.slice().reverse().map(({g, r: rr, tid}) => { const opp = g.home === tid ? g.away : g.home; const w = won(g, tid); const my = g.home === tid ? g.hs : g.as, op = g.home === tid ? g.as : g.hs;
      return `<button type="button" class="gl" data-go="game:${g.id}"><span class="o">${logo(opp, 24)}<span style="min-width:0"><span style="display:block;color:var(--fg);font-weight:600">${g.home === tid ? 'vs' : '@'} ${esc(TM[opp].short)}</span><span class="t2"><b style="color:${w ? 'var(--win)' : 'var(--loss)'}">${w ? 'W' : 'L'}</b> ${my}–${op} · ${fmtDay(gdate(g))}</span></span></span><span>${Math.floor(rr[I('min')])}</span><span class="p">${rr[I('pts')]}</span><span>${rr[I('reb')]}</span><span>${rr[I('ast')]}</span></button>`; }).join('')}</div></div>`;
  }
  html += `<div class="sec"><button type="button" class="btn" style="width:100%" data-act="cmpWith" data-pid="${p.id}">${ICON.vs} Compare with another player</button></div>`;
  return {title:pname(p), backTitle:p.last, hero:true, body:html};
};

/* ---------- SEARCH ---------- */
VIEWS.search = (r) => ({title:'Search', body:`<label class="search">${ICON.search}<input id="q-${r.uid}" type="search" placeholder="Players and clubs" autocomplete="off" value="${esc(r.s.q || '')}"></label><div id="res-${r.uid}" style="margin-top:12px"></div>`,
  mount(el, route) { const i = el.querySelector('input'); const out = el.querySelector('[id^="res-"]');
    const run = () => { const q = i.value.trim().toLowerCase(); route.s.q = i.value;
      if (!q) { out.innerHTML = `<p class="cap" style="margin:8px 4px">Try</p><div class="chips">${['Cheeks', 'Antwerp', 'Leiden', 'Murray', 'Donar'].map(x => `<button type="button" class="chip" data-act="fill" data-v="${x}">${x}</button>`).join('')}</div>`; return; }
      const cl = D.teams.filter(t => (t.name + ' ' + nick(t.id) + ' ' + CITY[t.id] + ' ' + t.short).toLowerCase().includes(q));
      const ps = D.players.filter(p => pname(p).toLowerCase().includes(q)).slice(0, 30);
      out.innerHTML = (cl.length ? `<span class="cap" style="display:block;margin:6px 4px 8px">Clubs</span><div class="list">${cl.map(t => `<button type="button" class="row" data-go="club:${t.id}">${logo(t.id, 34)}<div class="grow"><div class="t1">${esc(nick(t.id))}</div><div class="t2">${FLAG[t.country]} ${esc(CITY[t.id])}</div></div>${ICON.chev}</button>`).join('')}</div>` : '')
        + (ps.length ? `<span class="cap" style="display:block;margin:18px 4px 8px">Players</span><div class="list">${ps.map(p => `<button type="button" class="row" data-go="player:${p.id}">${avatar(p.id, 38)}<div class="grow"><div class="t1">${esc(pname(p))}</div><div class="t2">${esc(nick(p.team))} · #${esc(p.num)}</div></div>${ICON.chev}</button>`).join('')}</div>` : '')
        || `<div class="empty">Nothing matches “${esc(i.value)}”. Try a surname or a city.</div>`; };
    i.addEventListener('input', run); route.run = (v) => { i.value = v; run(); }; run(); setTimeout(() => i.focus({preventScroll:true}), 420); }});

/* =====================================================================
   Onboarding & settings
   ===================================================================== */
function clubPickerGrid(sel, act) {
  return ['BE', 'NL'].map(c => `<div class="sec" style="margin-top:14px">${secH(`${FLAG[c]} ${c === 'BE' ? 'Belgium' : 'Netherlands'}`)}<div class="club-grid">${D.teams.filter(t => t.country === c).sort((a, b) => nick(a.id).localeCompare(nick(b.id))).map(t => `<button type="button" class="card cg ${t.id === sel ? 'me' : ''}" data-act="${act}" data-id="${t.id}" aria-pressed="${t.id === sel}">${t.id === sel ? `<span class="star">${ICON.star}</span>` : ''}${logo(t.id, 48)}<span class="n">${esc(nick(t.id))}</span><span class="r">${esc(CITY[t.id])}</span></button>`).join('')}</div></div>`).join('');
}
let onbSel = null;
function showOnboarding(step = 1) {
  const o = $('#onb'); o.hidden = false;
  if (step === 1) o.innerHTML = `<div class="onb-splash"><div class="bg"></div><svg class="court" viewBox="0 0 400 860" preserveAspectRatio="xMidYMid slice" fill="none" stroke="#fff" stroke-width="2"><rect x="20" y="40" width="360" height="780" rx="4"/><line x1="20" y1="430" x2="380" y2="430"/><circle cx="200" cy="430" r="60"/><rect x="140" y="40" width="120" height="190"/><circle cx="200" cy="230" r="60"/><path d="M50 40v90a150 150 0 0 0 300 0V40"/><rect x="140" y="630" width="120" height="190"/><path d="M50 820v-90a150 150 0 0 1 300 0v90"/></svg>
    <div class="wordmark">BNXT<span>LEAGUE</span></div><p>Belgium and the Netherlands, 16 clubs, one league. Live scores, box scores and stats for every game.</p><button type="button" class="btn lime" style="height:54px;border-radius:27px;font-size:17px;position:relative" data-act="onb2">Get started</button></div>`;
  else o.innerHTML = `<div class="onb-pick"><h2>Pick your club</h2><p>Home will show your club's games, standing and leaders. You can change it any time.</p><div class="onb-scroll">${clubPickerGrid(onbSel, 'onbPick')}</div><div class="onb-foot"><button type="button" class="btn pri" data-act="onbDone" ${onbSel ? '' : 'disabled'}>${onbSel ? 'Follow ' + esc(nick(onbSel)) : 'Choose a club to continue'}</button></div></div>`;
}
function setFav(id, silent) {
  FAV = id; store.set('bnxt.fav', id); CMP.a = null; startLive(); invalidateAll();
  if (!silent) toast(`${nick(id)} is now your club`);
}
function settingsSheet() {
  openSheet('Settings', `<div class="list"><button type="button" class="row" data-act="changeFav">${logo(FAV, 34)}<div class="grow"><div class="t2">My club</div><div class="t1">${esc(nick(FAV))}</div></div><span style="color:var(--violet-hi);font-size:14px;font-weight:600">Change</span></button></div>
    <span class="cap" style="display:block;margin:20px 4px 8px">Language</span><div class="list"><div class="row"><div class="grow t1">English</div><span style="color:var(--lime)">✓</span></div><div class="row" style="opacity:.45"><div class="grow t1">Nederlands</div><span class="t2">Coming later</span></div><div class="row" style="opacity:.45"><div class="grow t1">Français</div><span class="t2">Coming later</span></div></div>
    <span class="cap" style="display:block;margin:20px 4px 8px">About</span><div class="list"><button type="button" class="row" data-act="replayOnb"><span class="ico">${ICON.replay}</span><div class="grow t1">Show onboarding again</div></button><div class="row"><span class="ico">${ICON.info}</span><div class="grow"><div class="t1">Data</div><div class="t2" style="white-space:normal">Public data from bnxtleague.com as of ${new Date(D.asOf).toLocaleDateString('en-GB', {day:'numeric', month:'long', year:'numeric'})}. The live game is simulated.</div></div></div></div>`);
}

/* =====================================================================
   Events
   ===================================================================== */
const ACTS = {
  back: () => pop(),
  seg: (a) => { const r = routeOf.get(a.closest('.view')); if (!r) return; const k = a.dataset.k; let v = a.dataset.v; if (k === 'mine') v = v === '1'; else if (k === 'team') v = +v; r.s[k] = v; rerender(r);
    if (k === 'cat' || k === 'tcat') { const c = r.el.querySelector('.chip.on'); c && c.scrollIntoView({inline:'nearest', block:'nearest'}); } },
  search: () => push({name:'search', uid:Math.random().toString(36).slice(2), s:{}}),
  fill: (a) => { const r = routeOf.get(a.closest('.view')); r && r.run && r.run(a.dataset.v); },
  settings: () => settingsSheet(),
  closeSheet: () => closeSheet(),
  changeFav: () => openSheet('Choose your club', clubPickerGrid(FAV, 'sheetFav')),
  sheetFav: (a) => { closeSheet(); setFav(+a.dataset.id); },
  fav: (a) => { const id = +a.dataset.id; if (id === FAV) { toast(`${nick(id)} is already your club`); return; } setFav(id); },
  cal: (a) => { const g = GM[a.dataset.id]; toast(`Calendar event: ${TM[g.home].short}–${TM[g.away].short}, ${fmtDay(gdate(g))} (demo)`); },
  cmpPick: (a) => cmpPicker(a.dataset.slot),
  cmpSet: (a) => { const pid = +a.dataset.pid, sl = a.dataset.slot; const other = sl === 'a' ? 'b' : 'a'; if (CMP[other] === pid) CMP[other] = CMP[sl]; CMP[sl] = pid; closeSheet(); allRoutes().filter(r => r.name === 'compare').forEach(r => rerender(r)); },
  cmpWith: (a) => { CMP.a = +a.dataset.pid; if (CMP.b === CMP.a) CMP.b = null; push({name:'compare', id:0}); },
  onb2: () => showOnboarding(2),
  onbPick: (a) => { onbSel = +a.dataset.id; const sc = $('.onb-scroll')?.scrollTop; showOnboarding(2); $('.onb-scroll').scrollTop = sc; },
  onbDone: () => { if (!onbSel) return; $('#onb').hidden = true; setFav(onbSel, true); switchTab('home'); popToRoot('home'); },
  replayOnb: () => { closeSheet(); onbSel = FAV; showOnboarding(1); },
};
function onClick(e) {
  const a = e.target.closest('[data-go],[data-act],[data-tab]'); if (!a || !$('#screen').contains(a)) return;
  if (a.tagName === 'A') return;
  if (a.dataset.act) { e.preventDefault(); return ACTS[a.dataset.act]?.(a, e); }
  if (a.dataset.tab) return switchTab(a.dataset.tab);
  if (a.dataset.go) { const [name, id] = a.dataset.go.split(':'); push({name, id:+id, s:{}}); }
}

/* ---------- notes panel "jump to" ---------- */
function jump(k) {
  closeSheet(); $('#onb').hidden = true;
  if (k === 'onboarding') { onbSel = FAV; return showOnboarding(1); }
  const go = (tab, route, s) => { switchTab(tab); popToRoot(tab); if (s) { Object.assign(stacks[tab][0].s, s); rerender(stacks[tab][0]); } if (route) setTimeout(() => push(route), 60); };
  const lastFin = finished.slice().sort((a, b) => b.t.localeCompare(a.t)).find(g => g.home === FAV || g.away === FAV) || finished[0];
  if (k === 'live') return LIVE ? go('games', {name:'game', id:LIVE.id, s:{tab:'pbp'}}, {mode:'upcoming'}) : toast('No live game right now');
  if (k === 'box') return go('games', {name:'game', id:lastFin.id, s:{tab:'box'}}, {mode:'results'});
  if (k === 'preview') { const g = D.games.find(x => x.status !== 'finished' && !(LIVE && x.id === LIVE.id)); return go('games', {name:'game', id:g.id, s:{}}, {mode:'upcoming'}); }
  if (k === 'standings') return go('standings', null, {ph:'league'});
  if (k === 'playoffs') return go('standings', null, {ph:'po'});
  if (k === 'leaders') return go('stats', null, {mode:'players', cat:'points'});
  if (k === 'compare') return go('stats', {name:'compare', id:0});
  if (k === 'club') return go('clubs', {name:'club', id:FAV, s:{}});
  if (k === 'player') { const p = D.players.filter(x => x.team === FAV && x.avg).sort((x, y) => y.avg[A('val')] - x.avg[A('val')])[0] || PL[D.leaders.efficiency[0][0]]; return go('clubs', {name:'player', id:p.id}); }
}

/* ---------- fit device to window ---------- */
function fit() {
  const dev = $('#device'), wrap = $('#dwrap');
  if (matchMedia('(max-width:820px)').matches) { dev.style.transform = ''; wrap.style.width = wrap.style.height = ''; return; }
  const sc = Math.min(1, (innerHeight - 40) / 898);
  dev.style.transform = `scale(${sc})`; wrap.style.width = 426 * sc + 'px'; wrap.style.height = 898 * sc + 'px';
}

/* ---------- boot ---------- */
$('#srcnote').innerHTML = `Data: a snapshot of public bnxtleague.com data taken ${new Date(D.asOf).toLocaleDateString('en-GB', {day:'numeric', month:'short', year:'numeric'})}. It covers ${D.teams.length} clubs, ${D.players.length} players, ${finished.length} finished games with box scores and ${D.games.length - finished.length} upcoming games. The live game is simulated from real rosters and season averages.`;
document.addEventListener('click', e => { const j = e.target.closest('[data-jump]'); if (j) jump(j.dataset.jump); });
$('#screen').addEventListener('click', onClick);
addEventListener('resize', fit); fit();
addEventListener('keydown', e => { if (e.key === 'Escape') { if ($('#sheet').classList.contains('open')) closeSheet(); else pop(); } });
extractColors().then(() => {
  if (FAV && !TM[FAV]) FAV = null;
  if (FAV) startLive();
  buildChrome();
  if (!FAV) { onbSel = null; showOnboarding(1); }
});
})();
