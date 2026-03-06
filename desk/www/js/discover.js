// Cast - Discover: PodcastIndex-powered search + trending

const PodcastIndex = {
  baseUrl: 'https://api.podcastindex.org/api/1.0',
  key: null,
  secret: null,
  _catCache: null,

  async init() {
    if (this.key && this.secret) return;
    try {
      const resp = await fetch('/apps/cast/api/pi-credentials');
      const data = await resp.json();
      this.key = data.key;
      this.secret = data.secret;
    } catch (e) {
      console.error('Failed to load PI credentials', e);
    }
  },

  async authHeaders() {
    const ts = Math.floor(Date.now() / 1000);
    const data = this.key + this.secret + ts;
    const enc = new TextEncoder().encode(data);
    const buf = await crypto.subtle.digest('SHA-1', enc);
    const arr = Array.from(new Uint8Array(buf));
    const hex = arr.map(b => b.toString(16).padStart(2, '0')).join('');
    return {
      'X-Auth-Key': this.key,
      'X-Auth-Date': String(ts),
      'Authorization': hex,
      'User-Agent': 'Cast/1.0'
    };
  },

  async search(query) {
    const headers = await this.authHeaders();
    const url = `${this.baseUrl}/search/byterm?q=${encodeURIComponent(query)}&max=20`;
    const resp = await fetch(url, { headers });
    const data = await resp.json();
    return data.feeds || [];
  },

  async trending(cat) {
    const headers = await this.authHeaders();
    let url = `${this.baseUrl}/podcasts/trending?max=20&lang=en`;
    if (cat) url += `&cat=${encodeURIComponent(cat)}`;
    const resp = await fetch(url, { headers });
    const data = await resp.json();
    return data.feeds || [];
  },

  async categories() {
    if (this._catCache) return this._catCache;
    const headers = await this.authHeaders();
    const url = `${this.baseUrl}/categories/list`;
    const resp = await fetch(url, { headers });
    const data = await resp.json();
    this._catCache = (data.feeds || []).map(c => ({ id: c.id, name: c.name }));
    return this._catCache;
  }
};

const Discover = {
  categories: [],
  currentCat: '',
  results: [],
  mode: 'trending',
  loading: false,
  _inited: false,
  _searchTimeout: null,

  async init() {
    if (!this._inited) {
      await PodcastIndex.init();
      this.categories = await PodcastIndex.categories();
      this._inited = true;
    }
    this.render();
    if (this.results.length === 0) {
      await this.loadTrending('');
    }
  },

  render() {
    const container = document.getElementById('discover-grid');
    const catContainer = document.getElementById('discover-categories');
    const searchInput = document.getElementById('discover-search');
    const loadingEl = document.getElementById('discover-loading');
    const emptyEl = document.getElementById('discover-empty');

    // Categories
    const cats = [{ id: '', name: 'All' }, ...this.categories];
    catContainer.innerHTML = cats.map(c =>
      `<button class="filter-btn ${c.id === this.currentCat || (c.id === '' && this.currentCat === '') ? 'active' : ''}"
              onclick="Discover.selectCategory('${c.id}', '${App.escHtml(c.name)}')">${App.escHtml(c.name)}</button>`
    ).join('');

    // Loading / empty
    loadingEl.style.display = this.loading ? '' : 'none';
    emptyEl.style.display = (!this.loading && this.results.length === 0) ? '' : 'none';

    // Grid
    if (!this.loading) {
      container.innerHTML = this.renderGrid(this.results);
    }

    // Search event (bind once)
    if (!searchInput.dataset.bound) {
      searchInput.dataset.bound = '1';
      searchInput.addEventListener('input', (e) => {
        clearTimeout(this._searchTimeout);
        const q = e.target.value.trim();
        if (q.length === 0) {
          this.mode = 'trending';
          this.loadTrending(this.currentCat);
          return;
        }
        this._searchTimeout = setTimeout(() => this.doSearch(q), 400);
      });
    }
  },

  renderGrid(feeds) {
    const subscribedUrls = new Set((App.podcasts || []).map(p => p['feed-url']));
    return feeds.map(f => {
      const feedUrl = f.url || f.feedUrl || '';
      const isSubscribed = subscribedUrls.has(feedUrl);
      const img = f.image || f.artwork || '';
      const desc = (f.description || '').replace(/<[^>]*>/g, '').slice(0, 120);
      return `
        <div class="podcast-card discover-card">
          <img src="${App.escHtml(img)}" alt="${App.escHtml(f.title || '')}"
               onerror="this.style.background='var(--bg-card)'; this.src=''">
          <div class="title">${App.escHtml(f.title || '')}</div>
          <div class="author">${App.escHtml(f.author || '')}</div>
          ${desc ? `<div class="discover-desc">${App.escHtml(desc)}</div>` : ''}
          <button class="btn btn-small discover-sub-btn ${isSubscribed ? 'subscribed' : ''}"
                  onclick="Discover.subscribe('${App.escHtml(feedUrl)}')" ${isSubscribed ? 'disabled' : ''}>
            ${isSubscribed ? 'Subscribed' : 'Subscribe'}
          </button>
        </div>
      `;
    }).join('');
  },

  async loadTrending(catName) {
    this.mode = 'trending';
    this.loading = true;
    this.render();
    try {
      this.results = await PodcastIndex.trending(catName === 'All' ? '' : catName);
    } catch (e) {
      console.error('Trending failed', e);
      this.results = [];
    }
    this.loading = false;
    this.render();
  },

  async doSearch(query) {
    this.mode = 'search';
    this.loading = true;
    this.render();
    try {
      this.results = await PodcastIndex.search(query);
    } catch (e) {
      console.error('Search failed', e);
      this.results = [];
    }
    this.loading = false;
    this.render();
  },

  selectCategory(id, name) {
    this.currentCat = id;
    const searchInput = document.getElementById('discover-search');
    if (searchInput) searchInput.value = '';
    this.loadTrending(name);
  },

  async subscribe(feedUrl) {
    try {
      await CastAPI.subscribe(feedUrl);
      App.toast('Subscribing...');
      setTimeout(async () => {
        await App.loadPodcasts();
        this.render();
      }, 3000);
    } catch (e) {
      console.error(e);
      App.toast('Failed to subscribe', 'error');
    }
  }
};
