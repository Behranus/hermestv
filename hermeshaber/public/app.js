const PAGE_SIZE = 24;

const state = {
  region: 'all',
  category: 'all',
  query: '',
  items: [],
  regions: [],
  categories: [],
  sources: [],
  shown: PAGE_SIZE,
  loading: false,
};

const el = {
  regions: document.getElementById('regions'),
  categories: document.getElementById('categories'),
  sources: document.getElementById('sources'),
  hero: document.getElementById('hero'),
  feedTitle: document.getElementById('feedTitle'),
  list: document.getElementById('list'),
  status: document.getElementById('statusbar'),
  empty: document.getElementById('empty'),
  search: document.getElementById('search'),
  searchWrap: document.getElementById('searchWrap'),
  searchToggle: document.getElementById('searchToggle'),
  refresh: document.getElementById('refresh'),
  overlay: document.getElementById('overlay'),
  reader: document.getElementById('reader'),
  loadMore: document.getElementById('loadMore'),
  radioToggle: document.getElementById('radioToggle'),
  radioPanel: document.getElementById('radioPanel'),
  radioTabs: document.getElementById('radioTabs'),
  radioBody: document.getElementById('radioBody'),
  closeRadio: document.getElementById('closeRadio'),
  player: document.getElementById('player'),
  playerToggle: document.getElementById('playerToggle'),
  playerIcon: document.getElementById('playerIcon'),
  playerName: document.getElementById('playerName'),
  playerSub: document.getElementById('playerSub'),
  playerClose: document.getElementById('playerClose'),
};

// Sunucudan gelen bölge/kategori listesi kullanılır; bunlar yalnızca ilk açılış yedeği.
const REGION_LABEL = {
  all: 'Tümü', europe: 'Avrupa', usa: 'ABD', canada: 'Kanada', latam: 'Latin Amerika',
  africa: 'Afrika', middleeast: 'Orta Doğu', turkey: 'Türkiye', china: 'Çin', russia: 'Rusya',
  southasia: 'Güney Asya', eastasia: 'Doğu Asya', seasia: 'Güneydoğu Asya', oceania: 'Okyanusya',
};
const REGION_ICON = {
  all: '🌐', europe: '🇪🇺', usa: '🇺🇸', canada: '🇨🇦', latam: '🌎', africa: '🌍', middleeast: '🕌',
  turkey: '🇹🇷', china: '🇨🇳', russia: '🇷🇺', southasia: '🇮🇳', eastasia: '🇯🇵', seasia: '🇸🇬', oceania: '🇦🇺',
};
const CATEGORY_LABEL = {
  all: 'Gündem', politics: 'Siyaset', business: 'Ekonomi', tech: 'Teknoloji', science: 'Bilim',
  health: 'Sağlık', climate: 'İklim', sport: 'Spor', culture: 'Kültür',
};
const CATEGORY_ICON = {
  all: '📰', politics: '🏛️', business: '📈', tech: '💻', science: '🔬', health: '🩺', climate: '🌱', sport: '⚽', culture: '🎭',
};

/* ---------------- yardımcılar ---------------- */

const escapeHtml = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function timeAgo(ts) {
  const d = Math.max(0, Date.now() - ts);
  const m = Math.round(d / 60000);
  if (m < 1) return 'şimdi';
  if (m < 60) return `${m} dk önce`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} saat önce`;
  const g = Math.round(h / 24);
  if (g < 30) return `${g} gün önce`;
  return new Date(ts).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' });
}

function fullDate(ts) {
  return new Date(ts).toLocaleString('tr-TR', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });
}

/* ---------------- çizim ---------------- */

function regionList() {
  return state.regions.length
    ? state.regions
    : Object.keys(REGION_LABEL).map((id) => ({ id, label: REGION_LABEL[id], icon: REGION_ICON[id] }));
}

function categoryList() {
  return state.categories.length
    ? state.categories
    : Object.keys(CATEGORY_LABEL).map((id) => ({ id, label: CATEGORY_LABEL[id], icon: CATEGORY_ICON[id] }));
}

function renderRegions() {
  el.regions.innerHTML = '';
  for (const r of regionList()) {
    const b = document.createElement('button');
    b.className = 'tab' + (r.id === state.region ? ' active' : '');
    b.innerHTML = `<span class="ic">${r.icon || REGION_ICON[r.id] || ''}</span>${escapeHtml(r.label)}`;
    b.onclick = () => {
      if (state.region === r.id) return;
      state.region = r.id;
      state.shown = PAGE_SIZE;
      load();
    };
    el.regions.appendChild(b);
  }
}

function renderCategories() {
  el.categories.innerHTML = '';
  for (const c of categoryList()) {
    const b = document.createElement('button');
    b.className = 'tab cat' + (c.id === state.category ? ' active' : '');
    b.innerHTML = `<span class="ic">${c.icon || CATEGORY_ICON[c.id] || ''}</span>${escapeHtml(c.label)}`;
    b.onclick = () => {
      if (state.category === c.id) return;
      state.category = c.id;
      state.shown = PAGE_SIZE;
      load();
    };
    el.categories.appendChild(b);
  }
}

function visible() {
  const q = state.query.trim().toLowerCase();
  return state.items.filter((it) => {
    if (state.region !== 'all' && it.region !== state.region) return false;
    if (!q) return true;
    return `${it.titleTr} ${it.title} ${it.summaryTr} ${it.summary} ${it.sourceName} ${it.country}`.toLowerCase().includes(q);
  });
}

function renderHero(item) {
  if (!item) {
    el.hero.hidden = true;
    return;
  }
  el.hero.hidden = false;
  el.hero.innerHTML = `
    ${item.image ? `<span class="hero-img" style="background-image:url('${escapeHtml(item.image)}')"></span>` : '<span class="hero-img"></span>'}
    <div class="hero-body">
      <div class="src-row"><span class="flag">${item.flag || ''}</span>${escapeHtml(item.sourceName)}</div>
      <h1>${escapeHtml(item.titleTr || item.title)}</h1>
      <p class="hero-sum">${escapeHtml(item.summaryTr || item.summary || item.title)}</p>
      <div class="time">${timeAgo(item.publishedAt)} · ${escapeHtml(item.country || '')}</div>
    </div>`;
  el.hero.onclick = () => openReader(item);
}

function rowHtml(it) {
  const title = it.titleTr || it.title;
  const sum = it.summaryTr || it.summary || '';
  const cat = it.category && it.category !== 'world' ? `<span class="cat">${escapeHtml(CATEGORY_LABEL[it.category] || it.category)}</span>` : '';
  return `
    <span class="content">
      <span class="src-row"><span class="flag">${it.flag || ''}</span><span class="src">${escapeHtml(it.sourceName)}</span>${cat}</span>
      <h3>${escapeHtml(title)}</h3>
      ${sum ? `<p class="sum">${escapeHtml(sum)}</p>` : ''}
      <span class="time">${timeAgo(it.publishedAt)} · ${escapeHtml(it.country || '')}</span>
    </span>
    ${it.image ? `<span class="thumb" style="background-image:url('${escapeHtml(it.image)}')"></span>` : ''}`;
}

function renderList() {
  const items = visible();
  const hero = !state.query.trim() && items.length ? items.find((it) => it.image) || items[0] : null;
  renderHero(hero);

  const rest = hero ? items.filter((it) => it !== hero) : items;
  const page = rest.slice(0, state.shown);

  el.list.innerHTML = '';
  const frag = document.createDocumentFragment();
  for (const it of page) {
    const row = document.createElement('button');
    row.className = 'row' + (it.image ? '' : ' no-img');
    row.innerHTML = rowHtml(it);
    row.onclick = () => openReader(it);
    frag.appendChild(row);
  }
  el.list.appendChild(frag);

  el.loadMore.hidden = rest.length <= state.shown;
  el.empty.hidden = Boolean(items.length);
  if (!items.length && !state.loading) {
    const hint = state.query
      ? 'Arama kriterine uyan haber yok.'
      : state.category !== 'all'
        ? 'Bu bölgede bu kategoride henüz haber yok; “Tümü” bölgesini deneyin.'
        : 'Bu bölge için kaynak yanıtı alınamadı. Yenile’yi deneyin.';
    el.empty.innerHTML = `<h3>Haber bulunamadı</h3><p>${hint}</p>`;
  }
  el.feedTitle.textContent = state.query.trim()
    ? `“${state.query.trim()}” için sonuçlar`
    : state.category === 'all'
      ? 'Son haberler'
      : `${CATEGORY_LABEL[state.category] || state.category} haberleri`;
}

function skeletons(n = 6) {
  el.hero.hidden = true;
  el.list.innerHTML = Array.from(
    { length: n },
    () => '<div class="sk"><span class="sk-thumb"></span><span class="sk-lines"><span class="sk-line"></span><span class="sk-line"></span><span class="sk-line"></span></span></div>',
  ).join('');
}

function updateStatus() {
  const items = visible();
  const tr = items.filter((it) => (it.titleTr && it.titleTr !== it.title) || (it.summaryTr && it.summaryTr !== it.summary)).length;
  const live = state.sources.filter((s) => s.count > 0).length;
  el.status.innerHTML = `
    <span><span class="dot"></span>${items.length} haber · Türkçe ${tr}</span>
    <span>${live} kaynak</span>
    <span>güncelleme ${new Date().toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}</span>`;
}

function renderSources() {
  const names = state.sources.filter((s) => s.count > 0).map((s) => s.name);
  el.sources.textContent = names.length ? names.join(' · ') : '';
  el.sources.hidden = !names.length;
}

/* ---------------- veri ---------------- */

async function fetchRegion(region, refresh, category) {
  const url = `/api/feed?region=${encodeURIComponent(region)}&category=${encodeURIComponent(category || 'all')}${refresh ? '&refresh=1' : ''}`;
  const res = await fetch(url);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

async function load(opts = {}) {
  state.loading = true;
  el.refresh.classList.add('spin');
  if (!state.items.length) skeletons();
  try {
    // Sunucu "Tümü" isteğinde bölgeler arasında dengeli örnekleme yapıyor: tek istek yeter.
    const data = await fetchRegion(state.region, opts.refresh, state.category);
    const items = (data.items || []).filter((it) => it.title);
    items.sort((a, b) => b.publishedAt - a.publishedAt);
    state.items = items;
    state.regions = data.regions || [];
    state.categories = data.categories || [];
    state.sources = data.sources || [];
    renderRegions();
    renderCategories();
    renderSources();
    renderList();
    updateStatus();
  } catch (err) {
    el.list.innerHTML = '';
    el.empty.hidden = false;
    el.empty.innerHTML = `<h3>Bağlantı sorunu</h3><p>${escapeHtml(err.message)}</p>`;
    el.status.innerHTML = `<span class="warn">Haberler yüklenemedi</span>`;
  } finally {
    state.loading = false;
    el.refresh.classList.remove('spin');
  }
}

/* ---------------- okuyucu ---------------- */

function closeReader() {
  el.overlay.hidden = true;
  document.body.style.overflow = '';
}

async function openReader(it) {
  const translated = it.titleTr && it.titleTr !== it.title;
  const lead = it.summaryTr || it.summary || '';
  el.overlay.hidden = false;
  el.overlay.scrollTop = 0;
  document.body.style.overflow = 'hidden';

  el.reader.innerHTML = `
    <div class="reader-top">
      <button class="back" id="closeReader">
        <svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" /></svg>
        Akış
      </button>
      ${it.link ? `<a class="ext" href="${escapeHtml(it.link)}" target="_blank" rel="noopener noreferrer">Orijinal ↗</a>` : ''}
    </div>
    ${it.image ? `<div class="reader-hero" style="background-image:url('${escapeHtml(it.image)}')"></div>` : ''}
    <div class="reader-body">
      <div class="kicker"><span>${it.flag || ''}</span><span class="src">${escapeHtml(it.sourceName)}</span><span>·</span><span>${escapeHtml(it.country || '')}</span></div>
      <h1>${escapeHtml(it.titleTr || it.title)}</h1>
      ${translated ? `<p class="orig-title">${escapeHtml(it.title)}</p>` : ''}
      <div class="meta">${fullDate(it.publishedAt)} · ${timeAgo(it.publishedAt)}</div>
      ${lead ? `<p class="lead">${escapeHtml(lead)}</p>` : ''}
      <div id="articleWrap"></div>
      <p class="note" id="readNote"><span class="spinner"></span>Haber metni getiriliyor…</p>
    </div>`;

  document.getElementById('closeReader').onclick = closeReader;

  const wrap = document.getElementById('articleWrap');
  const note = document.getElementById('readNote');

  if (!it.link) {
    note.className = 'note warn';
    note.textContent = 'Bu haber için bağlantı bulunamadı.';
    return;
  }

  let data;
  try {
    const res = await fetch(`/api/read?url=${encodeURIComponent(it.link)}&lang=${encodeURIComponent(it.lang || 'auto')}`);
    data = await res.json();
    if (!res.ok) throw new Error(data.message || data.error || `HTTP ${res.status}`);
  } catch (err) {
    note.className = 'note warn';
    note.textContent = `Metin alınamadı: ${err.message}`;
    if (it.link) {
      note.innerHTML += ` <a href="${escapeHtml(it.link)}" target="_blank" rel="noopener noreferrer" style="color:var(--gold)">Haberi kaynağında aç ↗</a>`;
    }
    return;
  }

  const body = (data.translated || '').trim();
  const original = (data.original || '').trim();

  if (body) {
    wrap.innerHTML = `<div class="body-title">Türkçe metin</div><div class="body">${escapeHtml(body)}</div>`;
    note.className = 'note';
    note.textContent = 'Metin otomatik çevrildi; özgün metnin yerini tutmaz.';
  } else if (original) {
    wrap.innerHTML = `<div class="body-title">Orijinal metin</div><div class="body">${escapeHtml(original)}</div>`;
    note.className = 'note warn';
    note.textContent = 'Çeviri bu istekte tamamlanamadı, metin özgün dilinde gösteriliyor.';
  } else {
    note.className = 'note warn';
    note.textContent = 'Bu haberde okunabilir gövde metni bulunamadı.';
  }
}

/* ---------------- radyo ---------------- */

const radio = {
  audio: null,
  featured: [],
  countries: [],
  country: null,
  stations: [],
  current: null,
  loading: false,
  error: '',
};

const PLAY_ICON = '<path d="M8 5v14l11-7z" fill="currentColor" />';
const PAUSE_ICON = '<path d="M7 5h4v14H7zM13 5h4v14h-4z" fill="currentColor" />';

function initRadio() {
  const audio = new Audio();
  audio.preload = 'none';
  audio.addEventListener('playing', () => setPlaying(true));
  audio.addEventListener('pause', () => setPlaying(false));
  audio.addEventListener('error', () => {
    if (!radio.current) return;
    setPlaying(false);
    radio.error = 'Bu yayın açılamadı. Başka bir istasyon deneyin.';
    renderRadioBody();
  });
  radio.audio = audio;
}

function setPlaying(on) {
  el.player.classList.toggle('paused', !on);
  el.playerIcon.innerHTML = on ? PAUSE_ICON : PLAY_ICON;
}

function playStation(st) {
  if (!st || !st.url) return;
  radio.error = '';
  radio.current = st;
  el.player.hidden = false;
  el.playerName.textContent = st.name;
  el.playerSub.textContent = [st.flag, st.country, st.genre].filter(Boolean).join(' · ');
  setPlaying(true);
  radio.audio.src = st.url;
  radio.audio.play().catch(() => {
    setPlaying(false);
    radio.error = 'Tarayıcı yayını başlatamadı; tekrar dokunun.';
  });
  renderRadioBody();
}

function stopRadio() {
  radio.current = null;
  radio.audio.pause();
  radio.audio.removeAttribute('src');
  radio.audio.load();
  el.player.hidden = true;
  setPlaying(false);
  if (!el.radioPanel.hidden) renderRadioBody();
}

function radioTabs() {
  const tabs = [{ id: 'featured', label: '⭐ Öne çıkanlar' }, { id: 'countries', label: '🌍 Ülkeler' }];
  el.radioTabs.innerHTML = '';
  for (const t of tabs) {
    const b = document.createElement('button');
    b.className = 'tab' + ((radio.country ? false : radio.tab === t.id) ? ' active' : '');
    b.textContent = t.label;
    b.onclick = () => {
      radio.country = null;
      radio.tab = t.id;
      renderRadio();
    };
    el.radioTabs.appendChild(b);
  }
  if (radio.country) {
    const meta = radio.countries.find((c) => c.code === radio.country);
    const b = document.createElement('button');
    b.className = 'tab active';
    b.textContent = `${meta ? meta.flag : '🌍'} ${meta ? meta.name : radio.country}`;
    b.onclick = () => {
      radio.country = null;
      renderRadio();
    };
    el.radioTabs.appendChild(b);
  }
}

function stationHtml(st) {
  const playing = radio.current && radio.current.url === st.url;
  return `<button class="station${playing ? ' playing' : ''}" data-url="${escapeHtml(st.url)}">
      <span class="fav">${st.favicon ? `<img src="${escapeHtml(st.favicon)}" alt="" loading="lazy" onerror="this.remove()" />` : (st.flag || '📻')}</span>
      <span class="info">
        <strong>${escapeHtml(st.name)}</strong>
        <span>${escapeHtml([st.country, st.genre, st.bitrate ? `${st.bitrate} kbps` : ''].filter(Boolean).join(' · '))}</span>
      </span>
      <span class="play"><svg viewBox="0 0 24 24">${playing ? PAUSE_ICON : PLAY_ICON}</svg></span>
    </button>`;
}

function renderRadioBody() {
  if (radio.country) {
    if (radio.loading) {
      el.radioBody.innerHTML = '<p class="radio-note">İstasyonlar getiriliyor…</p>';
      return;
    }
    if (!radio.stations.length) {
      el.radioBody.innerHTML = '<p class="radio-note">Bu ülke için uygun yayın bulunamadı. Başka bir ülke deneyin.</p>';
      return;
    }
    el.radioBody.innerHTML =
      (radio.error ? `<p class="radio-note" style="color:var(--gold)">${escapeHtml(radio.error)}</p>` : '') +
      radio.stations.map(stationHtml).join('') +
      '<p class="radio-note">Yayınlar radio-browser.info dizininden geliyor; bazı istasyonlar yayın saatlerine göre yayında olmayabilir.</p>';
  } else if (radio.tab === 'countries') {
    el.radioBody.innerHTML = `<div class="country-grid">${radio.countries
      .map((c) => `<button class="country" data-cc="${c.code}"><span class="flag">${c.flag}</span>${escapeHtml(c.name)}<span class="code">${c.code}</span></button>`)
      .join('')}</div>`;
  } else {
    const list = radio.featured.filter((s) => !s.hls);
    el.radioBody.innerHTML =
      (radio.error ? `<p class="radio-note" style="color:var(--gold)">${escapeHtml(radio.error)}</p>` : '') +
      list.map(stationHtml).join('') +
      '<p class="radio-note">Kamu yayıncıları ve güvenilir istasyonlar. Ülkeler sekmesinden dünyanın her yerinden radyo dinleyebilirsiniz.</p>';
  }

  el.radioBody.querySelectorAll('.station').forEach((node) => {
    node.onclick = () => {
      const url = node.getAttribute('data-url');
      if (radio.current && radio.current.url === url) {
        if (radio.audio.paused) radio.audio.play().catch(() => {});
        else radio.audio.pause();
        return;
      }
      const st =
        radio.stations.find((s) => s.url === url) ||
        radio.featured.find((s) => s.url === url) ||
        { name: node.querySelector('strong')?.textContent || 'Radyo', url };
      playStation(st);
    };
  });

  el.radioBody.querySelectorAll('.country').forEach((node) => {
    node.onclick = () => loadCountry(node.getAttribute('data-cc'));
  });
}

function renderRadio() {
  radioTabs();
  renderRadioBody();
}

async function loadCountry(cc) {
  radio.country = cc;
  radio.loading = true;
  radio.error = '';
  radio.stations = [];
  renderRadio();
  try {
    const res = await fetch(`/api/radio?kind=country&country=${encodeURIComponent(cc)}`);
    const data = await res.json();
    const meta = radio.countries.find((c) => c.code === cc) || {};
    radio.stations = (data.stations || []).map((s) => ({ ...s, country: meta.name || data.name, flag: meta.flag || data.flag }));
  } catch (err) {
    radio.error = `İstasyonlar alınamadı: ${err.message}`;
  } finally {
    radio.loading = false;
    renderRadio();
  }
}

async function openRadioPanel() {
  el.radioPanel.hidden = false;
  document.body.style.overflow = 'hidden';
  if (!radio.featured.length) {
    renderRadioBody();
    try {
      const res = await fetch('/api/radio?kind=featured');
      const data = await res.json();
      radio.featured = (data.stations || []).map((s) => ({ ...s }));
      radio.countries = data.countries || [];
    } catch (err) {
      radio.error = `Radyo listesi alınamadı: ${err.message}`;
    }
  }
  renderRadio();
}

function closeRadioPanel() {
  el.radioPanel.hidden = true;
  if (el.overlay.hidden) document.body.style.overflow = '';
}

/* ---------------- olaylar ---------------- */

el.overlay.addEventListener('click', (e) => {
  if (e.target === el.overlay) closeReader();
});
el.radioPanel.addEventListener('click', (e) => {
  if (e.target === el.radioPanel) closeRadioPanel();
});
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (!el.overlay.hidden) closeReader();
    else if (!el.radioPanel.hidden) closeRadioPanel();
  }
});

el.refresh.onclick = () => load({ refresh: true });
el.loadMore.onclick = () => {
  state.shown += PAGE_SIZE;
  renderList();
};

el.radioToggle.onclick = openRadioPanel;
el.closeRadio.onclick = closeRadioPanel;
el.playerClose.onclick = stopRadio;
el.playerToggle.onclick = () => {
  if (!radio.current) return;
  if (radio.audio.paused) radio.audio.play().catch(() => {});
  else radio.audio.pause();
};

el.searchToggle.onclick = () => {
  const open = el.searchWrap.hidden;
  el.searchWrap.hidden = !open;
  if (open) el.search.autofocus = true, el.search.focus();
  else {
    el.search.value = '';
    state.query = '';
    state.shown = PAGE_SIZE;
    renderList();
  }
};

let searchTimer;
el.search.addEventListener('input', (e) => {
  clearTimeout(searchTimer);
  const v = e.target.value;
  searchTimer = setTimeout(() => {
    state.query = v;
    state.shown = PAGE_SIZE;
    renderList();
  }, 120);
});

initRadio();
renderRegions();
renderCategories();
load();
