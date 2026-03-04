// Cast - Main Application

const App = {
  podcasts: [],
  currentPodcast: null,
  episodeFilter: 'all',

  async init() {
    Player.init();
    this.bindEvents();
    this.setupRouter();
    await this.loadPodcasts();
    await this.loadSettings();
  },

  bindEvents() {
    document.getElementById('subscribe-btn').addEventListener('click', () => this.handleSubscribe());
    document.getElementById('feed-url').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') this.handleSubscribe();
    });
    document.getElementById('save-settings').addEventListener('click', () => this.handleSaveSettings());
    document.getElementById('refresh-all-btn').addEventListener('click', () => this.handleRefreshAll());
    document.getElementById('import-opml-btn').addEventListener('click', () => this.handleImportOpml());
    document.getElementById('upload-btn').addEventListener('click', () => this.handleUpload());
  },

  // Toast notifications
  toast(msg, type = 'info') {
    const container = document.getElementById('toast-container');
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.textContent = msg;
    container.appendChild(el);
    setTimeout(() => el.classList.add('show'), 10);
    setTimeout(() => {
      el.classList.remove('show');
      setTimeout(() => el.remove(), 300);
    }, 3000);
  },

  // Router
  setupRouter() {
    window.addEventListener('hashchange', () => this.route());
    this.route();
  },

  route() {
    const hash = window.location.hash || '#/';
    const parts = hash.slice(2).split('/');
    const page = parts[0] || '';

    document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));

    if (page === '' || page === 'home') {
      this.showPage('home');
    } else if (page === 'podcast' && parts[1]) {
      this.showPodcastDetail(parts[1]);
    } else if (page === 'queue') {
      this.showPage('queue');
      this.loadQueue();
    } else if (page === 'settings') {
      this.showPage('settings');
    } else if (page === 'add') {
      this.showPage('add');
    } else {
      this.showPage('home');
    }
  },

  showPage(name) {
    document.getElementById(`page-${name}`).classList.add('active');
    const navLink = document.querySelector(`.nav-link[data-page="${name}"]`);
    if (navLink) navLink.classList.add('active');
  },

  // Podcast list
  async loadPodcasts() {
    try {
      const data = await CastAPI.getPodcasts();
      this.podcasts = data.podcasts || [];
      this.renderPodcasts();
    } catch (e) {
      console.error('Failed to load podcasts:', e);
      this.toast('Failed to load podcasts', 'error');
    }
  },

  renderPodcasts() {
    const grid = document.getElementById('podcast-grid');
    const empty = document.getElementById('empty-state');

    if (this.podcasts.length === 0) {
      grid.innerHTML = '';
      empty.style.display = 'block';
      return;
    }

    empty.style.display = 'none';
    grid.innerHTML = this.podcasts.map(p => `
      <div class="podcast-card" onclick="App.navigateToPodcast('${p.id}')">
        <img src="${this.escHtml(p['image-url'] || '')}" alt="${this.escHtml(p.title)}"
             onerror="this.style.background='var(--bg-card)'; this.src=''">
        <div class="title">${this.escHtml(p.title)}</div>
        <div class="author">${this.escHtml(p.author || '')}</div>
      </div>
    `).join('');
  },

  navigateToPodcast(id) {
    window.location.hash = `#/podcast/${id}`;
  },

  // Refresh all feeds
  async handleRefreshAll() {
    const btn = document.getElementById('refresh-all-btn');
    btn.textContent = 'Refreshing...';
    btn.disabled = true;
    try {
      await CastAPI.refreshAll();
      this.toast('Refreshing all feeds...');
      setTimeout(async () => {
        await this.loadPodcasts();
        btn.textContent = 'Refresh';
        btn.disabled = false;
        this.toast('Feeds refreshed', 'success');
      }, 5000);
    } catch (e) {
      console.error(e);
      btn.textContent = 'Refresh';
      btn.disabled = false;
      this.toast('Failed to refresh feeds', 'error');
    }
  },

  // Podcast detail
  async showPodcastDetail(id) {
    this.showPage('podcast');
    this.episodeFilter = 'all';
    const detail = document.getElementById('podcast-detail');
    const list = document.getElementById('episode-list');
    detail.innerHTML = '<p class="loading">Loading...</p>';
    list.innerHTML = '';

    try {
      const data = await CastAPI.getPodcast(id);
      this.currentPodcast = data;
      const episodes = data.episodes || [];
      episodes.sort((a, b) => (b['pub-date'] || 0) - (a['pub-date'] || 0));

      detail.innerHTML = `
        <div class="podcast-header">
          <img src="${this.escHtml(data['image-url'] || '')}" alt=""
               onerror="this.style.background='var(--bg-card)'; this.src=''">
          <div class="info">
            <h2>${this.escHtml(data.title)}</h2>
            <div class="author">${this.escHtml(data.author || '')}</div>
            <div class="description">${this.escHtml(data.description || '')}</div>
            <div class="podcast-actions">
              <button class="btn btn-small" onclick="App.handleRefreshPodcast('${id}')">Refresh</button>
              <button class="unsub-btn" onclick="App.handleUnsubscribe('${id}')">Unsubscribe</button>
            </div>
          </div>
        </div>
        <div class="episode-filters">
          <button class="filter-btn active" onclick="App.filterEpisodes('all', this)">All (${episodes.length})</button>
          <button class="filter-btn" onclick="App.filterEpisodes('unplayed', this)">Unplayed (${episodes.filter(e => !e.played).length})</button>
          <button class="filter-btn" onclick="App.filterEpisodes('in-progress', this)">In Progress (${episodes.filter(e => e.position > 0 && !e.played).length})</button>
        </div>
      `;

      this.renderEpisodes(episodes, id);
    } catch (e) {
      detail.innerHTML = '<p>Failed to load podcast.</p>';
      console.error(e);
    }
  },

  filterEpisodes(filter, btn) {
    this.episodeFilter = filter;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
    if (this.currentPodcast) {
      const episodes = (this.currentPodcast.episodes || []).slice();
      episodes.sort((a, b) => (b['pub-date'] || 0) - (a['pub-date'] || 0));
      this.renderEpisodes(episodes, this.currentPodcast.id);
    }
  },

  renderEpisodes(episodes, podcastId) {
    const list = document.getElementById('episode-list');
    let filtered = episodes;
    if (this.episodeFilter === 'unplayed') {
      filtered = episodes.filter(e => !e.played);
    } else if (this.episodeFilter === 'in-progress') {
      filtered = episodes.filter(e => e.position > 0 && !e.played);
    }

    if (filtered.length === 0) {
      list.innerHTML = '<p class="empty-state">No episodes match this filter.</p>';
      return;
    }

    list.innerHTML = filtered.map(ep => `
      <div class="episode-item ${ep.played ? 'played' : ''}" data-eid="${ep.id}">
        <div class="play-icon" onclick="App.playEpisode('${ep.id}')">&#9654;</div>
        <div class="ep-info" onclick="App.playEpisode('${ep.id}')">
          <div class="ep-title">${this.escHtml(ep.title)}</div>
          <div class="ep-meta">
            ${this.formatDate(ep['pub-date'])}
            ${ep.duration ? ' \u00b7 ' + Player.formatTime(ep.duration) : ''}
            ${ep.position > 0 && !ep.played ? ' \u00b7 ' + Player.formatTime(ep.position) + ' played' : ''}
          </div>
        </div>
        <div class="episode-actions">
          <button onclick="App.enqueueEpisode('${podcastId}', '${ep.id}')" title="Add to queue">+Q</button>
          <button onclick="App.togglePlayed('${ep.id}', ${!ep.played})" title="Toggle played">
            ${ep.played ? '\u21a9' : '\u2713'}
          </button>
        </div>
      </div>
    `).join('');
  },

  async handleRefreshPodcast(id) {
    try {
      await CastAPI.refresh(id);
      this.toast('Refreshing feed...');
      setTimeout(() => this.showPodcastDetail(id), 3000);
    } catch (e) {
      this.toast('Failed to refresh', 'error');
    }
  },

  playEpisode(episodeId) {
    if (!this.currentPodcast) return;
    const ep = (this.currentPodcast.episodes || []).find(e => e.id === episodeId);
    if (!ep) return;
    Player.play(ep, this.currentPodcast);
  },

  async enqueueEpisode(podcastId, episodeId) {
    try {
      await CastAPI.enqueue(podcastId, episodeId);
      this.toast('Added to queue', 'success');
    } catch (e) {
      console.error(e);
      this.toast('Failed to add to queue', 'error');
    }
  },

  async togglePlayed(episodeId, played) {
    try {
      await CastAPI.setPlayed(episodeId, played);
      if (this.currentPodcast) {
        this.showPodcastDetail(this.currentPodcast.id);
      }
    } catch (e) { console.error(e); }
  },

  // Queue
  async loadQueue() {
    try {
      const data = await CastAPI.getQueue();
      const list = document.getElementById('queue-list');
      const empty = document.getElementById('queue-empty');
      const queue = data.queue || [];

      if (queue.length === 0) {
        list.innerHTML = '';
        empty.style.display = 'block';
        return;
      }

      empty.style.display = 'none';
      list.innerHTML = queue.map((item, i) => `
        <div class="episode-item">
          <div class="play-icon" onclick="App.playQueueItem(${i})">&#9654;</div>
          <div class="ep-info" onclick="App.playQueueItem(${i})">
            <div class="ep-title">${this.escHtml(item.title || 'Unknown episode')}</div>
            <div class="ep-meta">
              ${this.escHtml(item['podcast-title'] || '')}
              ${item.duration ? ' \u00b7 ' + Player.formatTime(item.duration) : ''}
            </div>
          </div>
          <div class="episode-actions">
            <button onclick="App.dequeueEpisode('${item['podcast-id']}', '${item['episode-id']}')">Remove</button>
          </div>
        </div>
      `).join('');
      this._queueData = queue;
    } catch (e) { console.error(e); }
  },

  async playQueueItem(index) {
    if (!this._queueData || !this._queueData[index]) return;
    const item = this._queueData[index];
    const ep = {
      id: item['episode-id'],
      title: item.title || '',
      'audio-url': item['audio-url'] || '',
      'image-url': item['image-url'] || '',
      position: 0
    };
    const pod = {
      id: item['podcast-id'],
      title: item['podcast-title'] || '',
      'image-url': item['podcast-image'] || ''
    };
    Player.play(ep, pod);
  },

  async dequeueEpisode(podcastId, episodeId) {
    try {
      await CastAPI.dequeue(podcastId, episodeId);
      this.loadQueue();
    } catch (e) { console.error(e); }
  },

  // Settings
  async loadSettings() {
    try {
      const data = await CastAPI.getSettings();
      document.getElementById('setting-speed').value = data['playback-speed'] || 100;
      document.getElementById('setting-refresh').value = Math.round((data['refresh-interval'] || 3600) / 3600);
      document.getElementById('setting-autodownload').checked = data['auto-download'] || false;
      const speed = (data['playback-speed'] || 100) / 100;
      Player.setSpeed(speed);
    } catch (e) { console.error(e); }
  },

  async handleSaveSettings() {
    const speed = parseInt(document.getElementById('setting-speed').value);
    const refresh = parseInt(document.getElementById('setting-refresh').value) * 3600;
    const autoDownload = document.getElementById('setting-autodownload').checked;

    try {
      await CastAPI.setSettings({
        playbackSpeed: speed,
        autoDownload: autoDownload,
        refreshInterval: refresh
      });
      this.toast('Settings saved', 'success');
    } catch (e) {
      console.error(e);
      this.toast('Failed to save settings', 'error');
    }
  },

  // Subscribe
  async handleSubscribe() {
    const input = document.getElementById('feed-url');
    const url = input.value.trim();
    if (!url) return;

    const btn = document.getElementById('subscribe-btn');
    btn.textContent = 'Subscribing...';
    btn.disabled = true;

    try {
      await CastAPI.subscribe(url);
      input.value = '';
      this.toast('Subscribing... fetching feed');
      setTimeout(async () => {
        await this.loadPodcasts();
        window.location.hash = '#/';
        btn.textContent = 'Subscribe';
        btn.disabled = false;
        this.toast('Subscribed!', 'success');
      }, 3000);
    } catch (e) {
      console.error(e);
      this.toast('Failed to subscribe', 'error');
      btn.textContent = 'Subscribe';
      btn.disabled = false;
    }
  },

  // OPML Import
  async handleImportOpml() {
    const fileInput = document.getElementById('opml-file');
    if (!fileInput.files.length) {
      this.toast('Select an OPML file first', 'error');
      return;
    }

    const file = fileInput.files[0];
    const text = await file.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(text, 'text/xml');
    const outlines = doc.querySelectorAll('outline[xmlUrl]');
    const urls = Array.from(outlines).map(o => o.getAttribute('xmlUrl')).filter(Boolean);

    if (urls.length === 0) {
      this.toast('No feed URLs found in OPML file', 'error');
      return;
    }

    const btn = document.getElementById('import-opml-btn');
    btn.textContent = 'Importing...';
    btn.disabled = true;

    try {
      await CastAPI.importOpml(urls);
      this.toast(`Importing ${urls.length} feeds...`);
      fileInput.value = '';
      setTimeout(async () => {
        await this.loadPodcasts();
        window.location.hash = '#/';
        btn.textContent = 'Import';
        btn.disabled = false;
        this.toast('OPML import complete!', 'success');
      }, 5000);
    } catch (e) {
      console.error(e);
      this.toast('Failed to import OPML', 'error');
      btn.textContent = 'Import';
      btn.disabled = false;
    }
  },

  // S3 Upload
  UPLOADS_POD_ID: '0v0',

  async handleUpload() {
    const titleInput = document.getElementById('upload-title');
    const fileInput = document.getElementById('upload-file');
    const progress = document.getElementById('upload-progress');
    const title = titleInput.value.trim();

    if (!fileInput.files.length) {
      this.toast('Select an audio file', 'error');
      return;
    }
    if (!title) {
      this.toast('Enter a title', 'error');
      return;
    }

    const file = fileInput.files[0];
    const filename = `${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, '_')}`;
    const btn = document.getElementById('upload-btn');
    btn.textContent = 'Uploading...';
    btn.disabled = true;
    progress.textContent = 'Uploading to S3...';

    try {
      const audioUrl = await S3Upload.upload(file, filename);
      progress.textContent = 'Saving episode...';
      await CastAPI.addEpisode(this.UPLOADS_POD_ID, title, audioUrl);
      titleInput.value = '';
      fileInput.value = '';
      progress.textContent = '';
      this.toast('Uploaded!', 'success');
      await this.loadPodcasts();
    } catch (e) {
      console.error(e);
      progress.textContent = '';
      this.toast(`Upload failed: ${e.message}`, 'error');
    }

    btn.textContent = 'Upload';
    btn.disabled = false;
  },

  async handleUnsubscribe(podcastId) {
    if (!confirm('Unsubscribe from this podcast?')) return;
    try {
      await CastAPI.unsubscribe(podcastId);
      await this.loadPodcasts();
      window.location.hash = '#/';
      this.toast('Unsubscribed', 'success');
    } catch (e) { console.error(e); }
  },

  // Helpers
  escHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },

  formatDate(timestamp) {
    if (!timestamp) return '';
    try {
      const d = new Date(timestamp * 1000);
      return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    } catch (e) { return ''; }
  }
};

document.addEventListener('DOMContentLoaded', () => App.init());
