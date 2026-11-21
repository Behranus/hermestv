import { SOURCES, REGIONS, CATEGORIES, RADIO_FEATURED, RADIO_COUNTRIES } from './data.js';
// HermesHaber — RSS toplayıcı + Türkçe çeviri (Cloudflare Worker, bağımlılıksız)
const UA =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';


const PER_SOURCE = 10;
const READ_MAX = 18000; // okuyucuda gösterilen en uzun gövde metni
const JINA_READER = 'https://r.jina.ai/';
const FEED_TTL = 300000; // 5 dk
const RAW_TTL = 600000; // 10 dk

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (!path.startsWith('/api/')) return env.ASSETS.fetch(request);
    try {
      if (path === '/api/feed') return await handleFeed(url, env, ctx);
      if (path === '/api/tr') return await handleTr(url, env, ctx);
      if (path === '/api/read') return await handleRead(url, env, ctx);
      if (path === '/api/radio') return await handleRadio(url, env, ctx);
      if (path === '/api/health') return await handleHealth(env, url);
      return json({ error: 'not_found' }, 404);
    } catch (err) {
      return json({ error: 'server_error', message: String(err && err.message ? err.message : err) }, 500);
    }
  },
};

function json(obj, status = 200, extra = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...extra },
  });
}

/* ---------------- önbellek (D1 + isolate içi bellek) ---------------- */
// Not: bu ortamda caches.default kapalı ("not permitted to access the default cache"),
// bu yüzden kalıcı önbellek D1 tablosunda tutuluyor.

const MEM = new Map();
let schemaReady = false;

async function ensureSchema(env) {
  if (schemaReady || !env.DB) return;
  try {
    await env.DB.batch([
      env.DB.prepare('CREATE TABLE IF NOT EXISTS tr_cache (hash TEXT PRIMARY KEY, src TEXT, txt TEXT, created_at INTEGER)'),
      env.DB.prepare('CREATE TABLE IF NOT EXISTS cache_entries (key TEXT PRIMARY KEY, json TEXT, updated_at INTEGER)'),
    ]);
    schemaReady = true;
  } catch {
    /* şema kurulamazsa bellek önbelleğiyle devam */
  }
}

async function cacheRead(env, key, ttl) {
  const mem = MEM.get(key);
  if (mem && Date.now() - mem.at < ttl) return mem.value;
  if (!env.DB) return null;
  await ensureSchema(env);
  try {
    const row = await env.DB.prepare('SELECT json, updated_at FROM cache_entries WHERE key = ?1').bind(key).first();
    if (row && row.json && Date.now() - row.updated_at < ttl) {
      MEM.set(key, { at: row.updated_at, value: row.json });
      return row.json;
    }
  } catch {
    /* yoksay */
  }
  return null;
}

async function cacheWrite(env, key, value, ctx) {
  MEM.set(key, { at: Date.now(), value });
  if (!env.DB) return;
  const run = async () => {
    await ensureSchema(env);
    try {
      await env.DB.prepare('INSERT OR REPLACE INTO cache_entries (key, json, updated_at) VALUES (?1, ?2, ?3)').bind(key, value, Date.now()).run();
    } catch {
      /* yoksay */
    }
  };
  if (ctx) ctx.waitUntil(run());
  else await run();
}

/* ---------------- RSS okuma ---------------- */

function decodeBody(buf, contentType, fallback = 'utf-8') {
  let charset = fallback;
  const m = /charset=["']?([\w-]+)/i.exec(contentType || '');
  if (m) charset = m[1];
  else {
    const head = new TextDecoder('utf-8').decode(buf.slice(0, 400));
    const d = /encoding=["']([\w-]+)["']/i.exec(head);
    if (d) charset = d[1];
  }
  try {
    return new TextDecoder(charset, { fatal: false }).decode(buf);
  } catch {
    return new TextDecoder('utf-8', { fatal: false }).decode(buf);
  }
}

const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'", '#8217': '’', '#8216': '‘', '#8220': '“', '#8221': '”', '#8211': '–', '#8212': '—', '#8230': '…', '#160': ' ' };

function safeCp(n) {
  try {
    return String.fromCodePoint(n);
  } catch {
    return '';
  }
}

function unescapeHtml(s) {
  return String(s)
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => safeCp(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => safeCp(parseInt(d, 10)))
    .replace(/&([a-z]+|#\d+);/gi, (m, e) => (ENTITIES[e] !== undefined ? ENTITIES[e] : m));
}

function stripTags(s) {
  // ÖNEMLİ: CDATA sarmalı önce çözülmeli; yoksa <[^>]*> deseni başlığın tamamını yutar.
  const noCdata = String(s).replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1');
  // Birçok yayın özeti &lt;p&gt; şeklinde kaçışlı HTML içeriyor: önce çöz, sonra etiketleri sil.
  let out = unescapeHtml(noCdata).replace(/<[^>]*>/g, ' ');
  out = unescapeHtml(out).replace(/<[^>]*>/g, ' ');
  return out.replace(/\s+/g, ' ').trim();
}

function tagText(block, names) {
  for (const n of names) {
    const re = new RegExp(`<${n}(?:\\s[^>]*)?>([\\s\\S]*?)</${n}>`, 'i');
    const m = re.exec(block);
    if (m && m[1]) return m[1];
  }
  return '';
}

function itemLink(block) {
  const plain = /<link(?:\s[^>]*)?>([\s\S]*?)<\/link>/i.exec(block);
  if (plain && plain[1] && !/^\s*$/.test(plain[1])) return stripTags(plain[1]);
  const atom = /<link[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["']/i.exec(block) || /<link[^>]*href=["']([^"']+)["']/i.exec(block);
  if (atom) return atom[1];
  const guid = stripTags(tagText(block, ['guid', 'id']));
  if (/^https?:\/\//i.test(guid)) return guid;
  return '';
}

function itemImage(block) {
  const candidates = [
    /<media:content[^>]*url=["']([^"']+)["']/i,
    /<media:thumbnail[^>]*url=["']([^"']+)["']/i,
    /<enclosure[^>]*url=["']([^"']+)["']/i,
  ];
  for (const re of candidates) {
    const m = re.exec(block);
    if (m && /^https?:\/\//i.test(m[1])) return m[1];
  }
  const raw = tagText(block, ['content:encoded', 'description', 'summary']);
  const img = /<img[^>]+src=["']([^"']+)["']/i.exec(raw || '');
  return img && /^https?:\/\//i.test(img[1]) ? img[1] : '';
}

const MAX_PER_REGION = 14; // tek bölge akışında üst sınır
const ALL_PER_REGION = 2; // "Tümü" akışında her bölgeden kaynak sayısı

function pickSources(region, category) {
  const cat = category || 'all';
  const inCat = (s) => (cat === 'all' ? s.category === 'world' : s.category === cat);

  if (!region || region === 'all') {
    // Dünyanın tamamı: bölgeler arasında dengeli örnekleme (tek istekte makul kalsın).
    const byRegion = new Map();
    for (const s of SOURCES) {
      if (!inCat(s)) continue;
      if (!byRegion.has(s.region)) byRegion.set(s.region, []);
      byRegion.get(s.region).push(s);
    }
    const per = cat === 'all' ? ALL_PER_REGION : 2;
    const cap = cat === 'all' ? 28 : 12;
    const out = [];
    for (let i = 0; i < per; i += 1) {
      for (const list of byRegion.values()) {
        if (list[i] && out.length < cap) out.push(list[i]);
      }
    }
    return out;
  }

  return SOURCES.filter((s) => s.region === region && inCat(s)).slice(0, MAX_PER_REGION);
}

function parseFeed(xml, source) {
  const items = [];
  const blocks = xml.match(/<item(?:\s[^>]*)?>[\s\S]*?<\/item>/gi) || xml.match(/<entry(?:\s[^>]*)?>[\s\S]*?<\/entry>/gi) || [];
  for (const block of blocks) {
    const title = stripTags(tagText(block, ['title']));
    if (!title) continue;
    const rawSummary = tagText(block, ['description', 'summary', 'content:encoded', 'content']);
    let summary = stripTags(rawSummary);
    // Kartlarda daha uzun özet gösterilsin diye sınır 900 karakter.
    if (summary.length > 900) summary = summary.slice(0, 895).trimEnd() + '…';
    if (summary && summary.toLowerCase() === title.toLowerCase()) summary = '';
    const dateRaw = stripTags(tagText(block, ['pubDate', 'dc:date', 'published', 'updated', 'date']));
    const ts = Date.parse(dateRaw);
    items.push({
      title,
      summary,
      link: itemLink(block),
      image: itemImage(block),
      publishedAt: Number.isFinite(ts) ? ts : Date.now(),
      source: source.id,
      sourceName: source.name,
      country: source.country,
      flag: source.flag,
      region: source.region,
      category: source.category || 'world',
      lang: source.lang,
    });
    if (items.length >= PER_SOURCE) break;
  }
  return items;
}

async function loadSource(source, env, ctx) {
  const key = `raw:${source.id}`;
  const cached = await cacheRead(env, key, RAW_TTL);
  if (cached) {
    try {
      return JSON.parse(cached);
    } catch {
      /* düş */
    }
  }
  let items = [];
  try {
    const res = await fetch(source.url, {
      headers: { 'user-agent': UA, accept: 'application/rss+xml, application/xml, text/xml, */*' },
      signal: AbortSignal.timeout(12000),
    });
    if (res.ok) {
      const buf = await res.arrayBuffer();
      const text = decodeBody(buf, res.headers.get('content-type'), 'utf-8');
      items = parseFeed(text, source);
    }
  } catch {
    items = [];
  }
  if (items.length) await cacheWrite(env, key, JSON.stringify(items), ctx);
  return items;
}

function mergeItems(lists) {
  const seen = new Set();
  const items = [];
  for (const list of lists)
    for (const it of list) {
      const k = `${it.source}|${it.title.toLowerCase().slice(0, 80)}`;
      if (seen.has(k)) continue;
      seen.add(k);
      items.push(it);
    }
  items.sort((a, b) => b.publishedAt - a.publishedAt);
  return items.map((it, i) => ({ ...it, id: `${it.source}-${i}` }));
}

/* ---------------- çeviri (ücretsiz Google uç noktası) ---------------- */
// Gemini kotası dolduğu için anahtarsız çalışan bu uç kullanılıyor:
// clients5.google.com/translate_a/t?client=dict-chrome-ex — çoklu metin ve uzun
// gövde destekliyor, kota anahtarı istemiyor.

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const TR_ENDPOINT = 'https://clients5.google.com/translate_a/t';
const TR_PROXY = 'https://mozhi.ducks.party/api/translate';
const TR_MARK = '[[[HERMES]]]';
const TR_CHUNK = 4000; // tek istekte gönderilen toplam (URL kodlanmış) bayt

async function sha256(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function cacheLookupMany(env, hashes) {
  const out = new Map();
  const pending = [];
  for (const h of hashes) {
    if (MEM.has(h)) out.set(h, MEM.get(h));
    else pending.push(h);
  }
  if (pending.length && env.DB) {
    await ensureSchema(env);
    for (let i = 0; i < pending.length; i += 80) {
      const slice = pending.slice(i, i + 80);
      const params = slice.map((_, j) => `?${j + 1}`).join(',');
      try {
        const stmt = env.DB.prepare(`SELECT hash, txt FROM tr_cache WHERE hash IN (${params})`).bind(...slice);
        const { results } = await stmt.all();
        for (const row of results || []) {
          if (row && row.hash && row.txt) {
            out.set(row.hash, row.txt);
            MEM.set(row.hash, row.txt);
          }
        }
      } catch {
        /* yoksay */
      }
    }
  }
  return out;
}

async function cacheStoreMany(env, pairs, ctx) {
  for (const p of pairs) MEM.set(p.hash, p.txt);
  if (!env.DB || !pairs.length) return;
  const run = async () => {
    await ensureSchema(env);
    try {
      const stmts = pairs.map((p) =>
        env.DB.prepare('INSERT OR REPLACE INTO tr_cache (hash, src, txt, created_at) VALUES (?1, ?2, ?3, ?4)').bind(
          p.hash,
          String(p.src || '').slice(0, 400),
          p.txt,
          Date.now(),
        ),
      );
      for (let i = 0; i < stmts.length; i += 50) await env.DB.batch(stmts.slice(i, i + 50));
    } catch {
      /* yoksay */
    }
  };
  if (ctx) ctx.waitUntil(run());
  else await run();
}

/** Tek metni çevirir: önce mozhi köprüsü, olmazsa doğrudan Google ucu. */
async function trRequest(text, sl) {
  const lang = sl && sl !== 'auto' ? sl : 'auto';
  try {
    const u = new URL(TR_PROXY);
    u.searchParams.set('engine', 'google');
    u.searchParams.set('from', lang);
    u.searchParams.set('to', 'tr');
    u.searchParams.set('text', text);
    const res = await fetch(u.toString(), { headers: { 'user-agent': UA, accept: 'application/json' }, signal: AbortSignal.timeout(15000) });
    if (res.ok) {
      const data = await res.json();
      const out = data && typeof data['translated-text'] === 'string' ? data['translated-text'] : '';
      if (out.trim()) return out;
    }
  } catch {
    /* yedek uca geç */
  }
  try {
    const u = new URL(TR_ENDPOINT);
    u.searchParams.set('client', 'dict-chrome-ex');
    u.searchParams.set('sl', lang);
    u.searchParams.set('tl', 'tr');
    u.searchParams.set('q', text);
    const res = await fetch(u.toString(), { headers: { 'user-agent': UA, accept: '*/*' }, signal: AbortSignal.timeout(12000) });
    if (!res.ok) return null;
    const data = await res.json();
    if (!Array.isArray(data)) return null;
    return typeof data[0] === 'string' ? data[0] : null;
  } catch {
    return null;
  }
}

/** Metin dizisini tek dilde çevirir; başarısız parçalar '' olarak döner. */
async function translateTexts(texts, sl) {
  const out = new Array(texts.length).fill('');
  const chunks = [];
  let cur = [];
  let len = 0;
  texts.forEach((text, idx) => {
    // Arapça/Kiril karakterler URL'de 6 bayta kadar çıkıyor: parçayı kodlanmış boyuta göre böl.
    const add = encodeURIComponent(text).length + 30;
    if (cur.length && len + add > TR_CHUNK) {
      chunks.push(cur);
      cur = [];
      len = 0;
    }
    cur.push({ text, idx });
    len += add;
  });
  if (cur.length) chunks.push(cur);

  const single = async (c) => {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const r = await trRequest(c.text, sl);
      if (r && r.trim()) {
        out[c.idx] = r.trim();
        return;
      }
    }
  };

  const run = async (chunk, depth = 0) => {
    if (!chunk.length) return;
    if (chunk.length === 1) return single(chunk[0]);
    const joined = chunk.map((c) => c.text).join(`\n${TR_MARK}\n`);
    let translated = await trRequest(joined, sl);
    if (!translated) translated = await trRequest(joined, sl);
    if (!translated) {
      // İstek reddedildi (çoğunlukla URL fazla uzun): parçayı ikiye böl.
      if (chunk.length > 1 && depth < 3) {
        const mid = Math.ceil(chunk.length / 2);
        return Promise.all([run(chunk.slice(0, mid), depth + 1), run(chunk.slice(mid), depth + 1)]);
      }
      return Promise.all(chunk.map(single));
    }
    const parts = translated.split(TR_MARK);
    if (parts.length !== chunk.length) {
      if (depth < 3 && chunk.length > 1) {
        const mid = Math.ceil(chunk.length / 2);
        return Promise.all([run(chunk.slice(0, mid), depth + 1), run(chunk.slice(mid), depth + 1)]);
      }
      return Promise.all(chunk.map(single));
    }
    parts.forEach((p, i) => {
      out[chunk[i].idx] = p.replace(/\s+/g, ' ').trim();
    });
  };

  // Aşırı eşzamanlı istek olmaması için 6'lık gruplar.
  for (let i = 0; i < chunks.length; i += 6) {
    await Promise.all(chunks.slice(i, i + 6).map(run));
  }
  return out;
}

/**
 * Başlık/özet metinlerini çevirir.
 * entries: [{ text, lang }] — aynı metinler tekilleştirilir.
 * Dönen: Map(hash -> Türkçe metin)
 */
async function translateEntries(env, entries, ctx) {
  const unique = new Map();
  for (const e of entries) {
    const text = (e.text || '').trim();
    if (text.length < 2) continue;
    const hash = await sha256(text);
    if (!unique.has(hash)) unique.set(hash, { hash, text, lang: e.lang || 'auto' });
  }
  const list = [...unique.values()];
  const cached = await cacheLookupMany(env, list.map((x) => x.hash));
  const missing = list.filter((x) => !cached.has(x.hash));

  if (missing.length) {
    const byLang = new Map();
    for (const m of missing) {
      const key = /^[a-z]{2}$/.test(m.lang) ? m.lang : 'auto';
      if (!byLang.has(key)) byLang.set(key, []);
      byLang.get(key).push(m);
    }
    const stored = [];
    const groups = [...byLang.entries()];
    for (let g = 0; g < groups.length; g += 3) {
      await Promise.all(groups.slice(g, g + 3).map(async ([lang, group]) => {
        const results = await translateTexts(group.map((x) => x.text), lang);
        results.forEach((txt, i) => {
          if (!txt) return;
          cached.set(group[i].hash, txt);
          stored.push({ hash: group[i].hash, src: group[i].text, txt });
        });
      }));
    }
    if (stored.length) await cacheStoreMany(env, stored, ctx);
  }
  return cached;
}

/* ---------------- uçlar ---------------- */

async function translateItems(items, env, ctx) {
  const entries = [];
  for (const it of items) {
    entries.push({ text: it.title, lang: it.lang });
    if (it.summary) entries.push({ text: it.summary, lang: it.lang });
  }
  const map = await translateEntries(env, entries, ctx);
  let translated = 0;
  const out = [];
  for (const it of items) {
    const titleTr = it.title ? map.get(await sha256(it.title)) || '' : '';
    const summaryTr = it.summary ? map.get(await sha256(it.summary)) || '' : '';
    const ok = Boolean(titleTr);
    if (ok) translated += 1;
    out.push({ ...it, titleTr: titleTr || it.title, summaryTr: summaryTr || '', trSource: ok ? 'google' : '' });
  }
  return { items: out, translated };
}

async function handleFeed(url, env, ctx) {
  const region = (url.searchParams.get('region') || 'all').toLowerCase();
  const category = (url.searchParams.get('category') || 'all').toLowerCase();
  const refresh = url.searchParams.get('refresh') === '1';
  const sources = pickSources(region, category);
  if (!sources.length) return json({ error: 'unknown_source', hint: 'region=europe|usa|canada|latam|africa|middleeast|turkey|china|russia|southasia|eastasia|seasia|oceania · category=politics|business|tech|science|health|climate|sport|culture' }, 400);

  const cacheKey = `feed:v4:${region}:${category}`;
  if (!refresh) {
    const cached = await cacheRead(env, cacheKey, FEED_TTL);
    if (cached) {
      // Çeviri kapsamı düşük kaldıysa 90 saniye sonra yeniden denemek için önbelleği atla.
      let usable = true;
      try {
        const parsed = JSON.parse(cached);
        const total = parsed.total || 0;
        const ratio = total ? (parsed.translated || 0) / total : 1;
        if (ratio < 0.8 && Date.now() - (parsed.updatedAt || 0) > 90000) usable = false;
      } catch {
        usable = false;
      }
      if (usable) {
        return new Response(cached, { headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=120' } });
      }
    }
  }

  const lists = await Promise.all(sources.map((s) => loadSource(s, env, ctx)));
  const items = mergeItems(lists);
  const { items: translatedItems, translated } = await translateItems(items, env, ctx);

  const perSource = {};
  for (const it of items) perSource[it.source] = (perSource[it.source] || 0) + 1;

  const body = JSON.stringify({
    region,
    category,
    regions: REGIONS,
    categories: CATEGORIES,
    updatedAt: Date.now(),
    total: translatedItems.length,
    translated,
    engine: 'google',
    translationError: null,
    translationEnabled: true,
    items: translatedItems,
    sources: sources.map((s) => ({
      id: s.id,
      name: s.name,
      country: s.country,
      flag: s.flag,
      region: s.region,
      category: s.category,
      count: perSource[s.id] || 0,
    })),
  });
  ctx.waitUntil(cacheWrite(env, cacheKey, body, ctx));
  return new Response(body, {
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=120' },
  });
}

// Eski istemciler için: bölgedeki haberlerin başlık/özet çevirisini döndürür.
async function handleTr(url, env, ctx) {
  const region = (url.searchParams.get('region') || 'all').toLowerCase();
  const category = (url.searchParams.get('category') || 'all').toLowerCase();
  const skip = Math.max(0, parseInt(url.searchParams.get('skip') || '0', 10) || 0);
  const take = Math.min(40, Math.max(1, parseInt(url.searchParams.get('take') || '20', 10) || 20));
  const sources = pickSources(region, category);
  if (!sources.length) return json({ error: 'unknown_region' }, 400);

  const lists = await Promise.all(sources.map((s) => loadSource(s, env, ctx)));
  const items = mergeItems(lists);
  const slice = items.slice(skip, skip + take);
  const { items: translatedItems, translated } = await translateItems(slice, env, ctx);
  return json({
    region,
    skip,
    total: items.length,
    done: skip + slice.length,
    translated,
    engine: 'google',
    error: null,
    items: translatedItems.map((it) => ({ id: it.id, titleTr: it.titleTr, summaryTr: it.summaryTr, trSource: it.trSource })),
  });
}

function stripInline(html) {
  return unescapeHtml(String(html).replace(/<[^>]*>/g, ' ')).replace(/\s+/g, ' ').trim();
}

// Sayfa altbilgisi, çerez uyarısı, abonelik kutusu gibi gövdeye ait olmayan paragraflar (çok dilli).
const BOILER = /(©|copyright|all rights reserved|tüm hakları saklıdır|tous droits réservés|todos los derechos|tutti i diritti|alle rechte|все права|جميع الحقوق|subscribe|abone ol|abonnez|suscríb|abbonati|abonnieren|подпис|перейдите по ссылке|электронной почте|اشترك|newsletter|bülten|cookie|çerez|privacy policy|gizlilik politikası|politique de confidentialité|política de privacidad|datenschutz|mentions légales|impressum|terms of (use|service)|kullanım koşulları|follow us|bizi takip|share this|paylaş|advertisement|reklam|publicité|publicidad|pubblicità|werbung|sign in|giriş yap|register|kayıt ol|read more|devamını oku|download the app|uygulamayı indir|app store|google play|tel\.|телефон|tel:|telefon|e-?posta|ros?komnadzor|tescil|registration number|kayıt numarası|jsc |llc |a\.ş\.|ltd\.|оторг|редакция|реклама)/i;
const PAYWALL = /(subscribers? only|for subscribers|available to subscribers|только для подписчиков|для подписчиков|premium (article|content)|bu içerik abonelere|contenido exclusivo|contenu réservé|contenuto riservato)/i;

function cleanLines(text) {
  return String(text)
    .split('\n')
    .map((l) => l.replace(/\s+/g, ' ').trim())
    .filter((l) => l.length > 40 && !isBoilerplate(l));
}

/** JSON-LD articleBody — birçok sitede gövde metni burada hazır durur. */
function extractJsonLd(html) {
  let best = '';
  for (const m of String(html).matchAll(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi)) {
    let data;
    try {
      data = JSON.parse(m[1].trim());
    } catch {
      continue;
    }
    const walk = (node) => {
      if (!node || typeof node !== 'object') return;
      if (Array.isArray(node)) {
        node.forEach(walk);
        return;
      }
      if (typeof node.articleBody === 'string' && node.articleBody.length > best.length) best = node.articleBody;
      for (const v of Object.values(node)) if (v && typeof v === 'object') walk(v);
    };
    walk(data);
  }
  return best ? cleanLines(stripInline(best).replace(/\.\s+/g, '.\n')).join('\n\n') : '';

}

function isBoilerplate(t) {
  if (BOILER.test(t)) return true;
  // Neredeyse tamamı sayı/sembol olan satırlar (menü, tablo, fiyat listesi).
  const letters = (t.match(/[\p{L}]/gu) || []).length;
  if (letters / t.length < 0.55) return true;
  // Menü şeritleri: kısa ve çoğu büyük harf, ya da çok sayıda ayraç.
  const upper = (t.match(/[\p{Lu}]/gu) || []).length;
  if (t.length < 300 && upper / Math.max(1, letters) > 0.6) return true;
  return (t.match(/\s[|·•]\s/g) || []).length >= 2;
}

/** Sayfadan haber gövdesini çıkarır: <article>, <main> ve tüm <p>'ler arasından en temiz bloğu seçer. */
function extractArticle(html) {
  const clean = String(html)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<figure[\s\S]*?<\/figure>/gi, ' ')
    .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
    .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
    .replace(/<aside[\s\S]*?<\/aside>/gi, ' ');

  const paragraphsOf = (scope) =>
    [...scope.matchAll(/<p(?:\s[^>]*)?>([\s\S]*?)<\/p>/gi)]
      .map((m) => stripInline(m[1]))
      .filter((t) => t.length > 60 && !isBoilerplate(t) && looksLikeProse(t));

  const cleanLength = (ps) => ps.join(' ').length;

  let best = [];
  const scopes = [];
  for (const re of [
    /<article[\s\S]*?<\/article>/gi,
    /<main[\s\S]*?<\/main>/gi,
    /<div[^>]+(?:article-body|articleBody|story-body|post-content|entry-content|content__body|article__body|doc__text)[^>]*>[\s\S]*?<\/div>/gi,
  ]) {
    for (const block of clean.match(re) || []) scopes.push(block);
  }
  for (const block of scopes) {
    const ps = paragraphsOf(block);
    if (cleanLength(ps) > cleanLength(best)) best = ps;
  }
  if (cleanLength(best) < 400) {
    const ps = paragraphsOf(clean);
    if (cleanLength(ps) > cleanLength(best)) best = ps;
  }

  // <p> yoksa: blok etiketlerini satır sonuna çevirip altbilgiyi ayıkla.
  if (cleanLength(best) < 400) {
    const lines = cleanLines(
      clean
        .replace(/<\/(p|div|section|li|h[1-6]|blockquote|tr)>/gi, '\n')
        .replace(/<br\s*\/?>/gi, '\n')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/gi, ' '),
    );
    // Birbirini tekrar eden menü satırlarını at.
    const seen = new Set();
    const uniq = lines.filter((l) => {
      const k = l.slice(0, 60).toLowerCase();
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
    if (uniq.join(' ').length > cleanLength(best)) best = uniq;
  }
  return best.join('\n\n');
}

/** Jina Reader üzerinden sayfayı markdown olarak çeker (bot korumalı siteler için). */
async function readViaJina(target) {
  try {
    const res = await fetch(JINA_READER + target, {
      headers: { accept: 'text/plain' },
      signal: AbortSignal.timeout(25000),
    });
    if (!res.ok) return { text: '', status: res.status };
    return { text: await res.text(), status: res.status };
  } catch (err) {
    return { text: '', status: 0, error: String(err && err.message ? err.message : err).slice(0, 120) };
  }
}

/** Paragraf gibi görünen (menü/başlık şeridi olmayan) satırlar. */
function looksLikeProse(t) {
  const words = t.trim().split(/\s+/).length;
  if (words < 8) return false;
  const letters = (t.match(/[\p{L}]/gu) || []).length;
  const caps = (t.match(/[\p{Lu}]/gu) || []).length;
  if (!letters || caps / letters > 0.35) return false;
  return /[.!?…:]["'”’)\]]?$/.test(t.trim()) || /[.?!]\s/.test(t);
}

/** Jina markdown çıktısından gövde paragraflarını çıkarır. */
function extractMarkdown(md) {
  const raw = String(md);
  const idx = raw.indexOf('Markdown Content:');
  const body = idx >= 0 ? raw.slice(idx + 17) : raw;
  const lines = body
    .split('\n')
    .map((l) =>
      l
        .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
        .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
        .replace(/^\s*[#>*+\-\d.]+\s+/, '')
        .replace(/\*\*/g, '')
        .replace(/\s+/g, ' ')
        .trim(),
    )
    .filter(
      (l) =>
        l.length > 60 &&
        !isBoilerplate(l) &&
        looksLikeProse(l) &&
        !/^(share|follow|advertisement|subscribe|sign in|log in|cookie|skip to)/i.test(l),
    );
  const seen = new Set();
  const uniq = lines.filter((l) => {
    const k = l.slice(0, 60).toLowerCase();
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  return uniq.join('\n\n');
}

async function handleRead(url, env, ctx) {
  const target = url.searchParams.get('url');
  const lang = (url.searchParams.get('lang') || 'auto').toLowerCase();
  if (!target || !/^https?:\/\//i.test(target)) return json({ error: 'bad_url' }, 400);

  const cacheKey = `read9:${await sha256(target)}`;
  const cached = await cacheRead(env, cacheKey, 604800000);
  if (cached) return new Response(cached, { headers: { 'content-type': 'application/json; charset=utf-8' } });

  let html = '';
  let failStatus = 0;
  try {
    const res = await fetch(target, {
      headers: {
        'user-agent': UA,
        accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'accept-language': 'en-US,en;q=0.9,tr;q=0.8',
        'cache-control': 'no-cache',
      },
      redirect: 'follow',
      signal: AbortSignal.timeout(15000),
    });
    if (res.ok) html = await res.text();
    else failStatus = res.status;
  } catch {
    failStatus = failStatus || 0;
  }

  let text = html ? extractJsonLd(html) : '';
  if (html && text.length < 600) text = extractArticle(html);

  // Sayfa doğrudan alınamadıysa (bot koruması) Jina Reader üzerinden tam metni dene.
  let viaJina = false;
  let jinaStatus = 0;
  if (!html) {
    const jina = await readViaJina(target);
    jinaStatus = jina.status;
    const fromJina = jina.text ? extractMarkdown(jina.text) : '';
    // Jina çıktısı menü kalabalığı içerebilir: ancak belirgin şekilde daha uzunsa kullan.
    if (fromJina.length > Math.max(text.length * 1.3, 1200)) {
      text = fromJina;
      viaJina = true;
    }
  }

  text = text.slice(0, READ_MAX);
  if (text.length < 350) {
    if (!html && !text)
      return json(
        { error: 'fetch_failed', status: failStatus, jinaStatus, message: 'Kaynak site metni paylaşmıyor (bot koruması).' },
        502,
      );
    const paywalled = PAYWALL.test(html) || /paywall/i.test(html);
    return json(
      {
        error: paywalled ? 'paywalled' : 'no_content',
        message: paywalled ? 'Bu haber abonelere açık; tam metin sayfada yer almıyor.' : 'Bu sayfada okunabilir gövde metni bulunamadı.',
      },
      422,
    );
  }

  // Paragrafları ~1200 karakterlik dilimlere böl, her dilimi çevir.
  const chunks = [];
  let cur = '';
  for (const p of text.split('\n\n')) {
    const tooBig = encodeURIComponent(cur + p).length > 4000;
    if (cur && tooBig) {
      chunks.push(cur);
      cur = '';
    }
    cur += (cur ? '\n\n' : '') + p;
  }
  if (cur) chunks.push(cur);

  // Parçalar üçerli gruplar hâlinde çevrilir ve D1 önbelleğine yazılır:
  // uzun gövde makul sürede gelir, sağlayıcı da toplu istekle yorulmaz.
  const parts = new Array(chunks.length).fill('');
  let failed = 0;
  for (let i = 0; i < chunks.length; i += 3) {
    const group = chunks.slice(i, i + 3);
    const outs = await Promise.all(
      group.map(async (c) => {
        const h = await sha256(c);
        const map = await translateEntries(env, [{ text: c, lang }], ctx);
        return (map.get(h) || '').trim();
      }),
    );
    outs.forEach((out, j) => {
      if (out) parts[i + j] = out;
      else failed += 1;
    });
    if (i + 3 < chunks.length) await sleep(120);
  }

  // İlk turda düşen parçaları bir kez daha dene (sağlayıcı ara sıra hız sınırı uyguluyor).
  if (failed > 0) {
    await sleep(800);
    for (let i = 0; i < chunks.length; i += 1) {
      if (parts[i]) continue;
      const c = chunks[i];
      const h = await sha256(c);
      const map = await translateEntries(env, [{ text: c, lang }], ctx);
      const out = (map.get(h) || '').trim();
      if (out) {
        parts[i] = out;
        failed -= 1;
      }
    }
  }

  const translated = parts.filter(Boolean).join('\n\n');
  const body = JSON.stringify({
    url: target,
    translated,
    original: text,
    chars: text.length,
    chunks: chunks.length,
    failed,
    viaJina,
    jinaStatus,
    engine: 'google',
  });
  if (translated) ctx.waitUntil(cacheWrite(env, cacheKey, body, ctx));
  return new Response(body, { headers: { 'content-type': 'application/json; charset=utf-8' } });
}

/* ---------------- radyo ---------------- */
// Ülke ülke dünya radyoları radio-browser.info dizininden canlı çekilir;
// yalnızca HTTPS, kırılmamış, HLS olmayan (tarayıcıda da çalan) yayınlar geçer.
const RADIO_API = 'https://de1.api.radio-browser.info/json/stations/search';
const RADIO_TTL = 21600000; // 6 saat

async function handleRadio(url, env, ctx) {
  const kind = (url.searchParams.get('kind') || 'featured').toLowerCase();

  if (kind === 'countries') return json({ countries: RADIO_COUNTRIES });

  if (kind === 'featured') {
    return json({
      countries: RADIO_COUNTRIES,
      stations: RADIO_FEATURED.map((s) => ({
        id: s.id,
        name: s.name,
        country: s.country,
        flag: s.flag,
        genre: s.genre,
        url: s.url,
        site: s.site || '',
        hls: Boolean(s.hls),
      })),
    });
  }

  if (kind === 'country') {
    const cc = (url.searchParams.get('country') || '').toUpperCase();
    if (!/^[A-Z]{2}$/.test(cc)) return json({ error: 'bad_country' }, 400);

    const cacheKey = `radio:v1:${cc}`;
    const cached = await cacheRead(env, cacheKey, RADIO_TTL);
    if (cached) {
      return new Response(cached, { headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=1800' } });
    }

    const meta = RADIO_COUNTRIES.find((c) => c.code === cc);
    let raw = [];
    try {
      const q = new URL(RADIO_API);
      q.searchParams.set('countrycode', cc);
      q.searchParams.set('limit', '80');
      q.searchParams.set('hidebroken', 'true');
      q.searchParams.set('order', 'clickcount');
      q.searchParams.set('reverse', 'true');
      const res = await fetch(q.toString(), {
        headers: { 'user-agent': UA, accept: 'application/json' },
        signal: AbortSignal.timeout(12000),
      });
      if (res.ok) raw = await res.json();
    } catch {
      raw = [];
    }

    const seen = new Set();
    const stations = [];
    for (const s of Array.isArray(raw) ? raw : []) {
      if (!s || !s.url_resolved) continue;
      const stream = String(s.url_resolved);
      if (!/^https:\/\//i.test(stream)) continue; // Android ve https sayfalar için şart
      if (s.hls) continue;
      if (s.lastcheckok === 0) continue;
      if (seen.has(stream)) continue;
      seen.add(stream);
      const name = String(s.name || '').replace(/\s+/g, ' ').trim().slice(0, 70);
      if (!name) continue;
      stations.push({
        id: String(s.stationuuid || stream).slice(0, 60),
        name,
        url: stream,
        genre: String(s.tags || '')
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean)
          .slice(0, 2)
          .join(' · '),
        bitrate: Number(s.bitrate) || 0,
        favicon: /^https:\/\//i.test(String(s.favicon || '')) ? s.favicon : '',
      });
      if (stations.length >= 40) break;
    }

    const body = JSON.stringify({
      country: cc,
      name: meta ? meta.name : cc,
      flag: meta ? meta.flag : '🌍',
      stations,
    });
    if (stations.length) ctx.waitUntil(cacheWrite(env, cacheKey, body, ctx));
    return new Response(body, {
      headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'public, max-age=1800' },
    });
  }

  return json({ error: 'bad_kind', hint: 'kind=featured|countries|country&country=TR' }, 400);
}

async function handleHealth(env, url) {
  const t0 = Date.now();
  const only = (url.searchParams.get('only') || '')
    .split(',')
    .map((x) => x.trim())
    .filter(Boolean);
  const target = only.length ? SOURCES.filter((s) => only.includes(s.id)) : SOURCES.slice(0, 6);
  const results = await Promise.all(
    target.map(async (s) => {
      const started = Date.now();
      try {
        const res = await fetch(s.url, {
          headers: { 'user-agent': UA, accept: 'application/rss+xml, application/xml, text/xml, */*' },
          signal: AbortSignal.timeout(12000),
        });
        const buf = res.ok ? await res.arrayBuffer() : new ArrayBuffer(0);
        const text = res.ok ? decodeBody(buf, res.headers.get('content-type')) : '';
        const count = res.ok ? parseFeed(text, s).length : 0;
        return { id: s.id, status: res.status, count, ms: Date.now() - started };
      } catch (err) {
        return { id: s.id, status: 0, count: 0, ms: Date.now() - started, error: String(err.message || err).slice(0, 120) };
      }
    }),
  );
  const probe = await trRequest('Breaking news from Europe', 'en');
  return json({
    ok: true,
    elapsedMs: Date.now() - t0,
    translationEnabled: true,
    translationProbe: probe,
    db: Boolean(env.DB),
    sources: results,
  });
}
