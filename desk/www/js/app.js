// Cast - Main Application

const App = {
  podcasts: [],
  currentPodcast: null,
  episodeFilter: 'all',
  showArchived: false,
  episodeSearch: '',
  episodeSortAsc: false,
  pollTimer: null,
  downloadedEpisodes: new Set(),

  async init() {
    Player.init();
    await CastDownload.init();
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
    document.getElementById('export-opml-btn').addEventListener('click', () => this.handleExportOpml());
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

  // Polling
  startPolling(fn, interval) {
    this.stopPolling();
    this.pollTimer = setInterval(fn, interval);
  },

  stopPolling() {
    if (this.pollTimer) { clearInterval(this.pollTimer); this.pollTimer = null; }
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
    this.stopPolling();

    if (page === '' || page === 'home') {
      this.showPage('home');
      this.startPolling(() => this.pollHome(), 30000);
    } else if (page === 'podcast' && parts[1]) {
      this.showPodcastDetail(parts[1]);
    } else if (page === 'episode' && parts[1] && parts[2]) {
      this.showEpisodeDetail(parts[1], parts[2]);
    } else if (page === 'queue') {
      this.showPage('queue');
      this.loadQueue();
    } else if (page === 'history') {
      this.showPage('history');
      this.loadHistory();
    } else if (page === 'settings') {
      this.showPage('settings');
      this.loadSettingsPage();
    } else if (page === 'add') {
      this.showPage('add');
    } else if (page === 'discover') {
      this.showPage('discover');
      Discover.render();
    } else {
      this.showPage('home');
    }
  },

  showPage(name) {
    document.getElementById(`page-${name}`).classList.add('active');
    const navLink = document.querySelector(`.nav-link[data-page="${name}"]`);
    if (navLink) navLink.classList.add('active');
  },

  // Home page polling
  async pollHome() {
    try {
      const data = await CastAPI.getPodcasts();
      const newPods = data.podcasts || [];
      // Check if badge counts changed
      const changed = newPods.length !== this.podcasts.length || newPods.some((p, i) => {
        const old = this.podcasts.find(op => op.id === p.id);
        return !old || old['unplayed-count'] !== p['unplayed-count'];
      });
      if (changed) {
        this.podcasts = newPods;
        this.renderPodcasts();
        // Auto-download new episodes if enabled
        if (localStorage.getItem('cast-auto-download') === 'true') {
          this.autoDownloadNew(newPods);
        }
      }
    } catch (e) { /* silent poll failure */ }
  },

  async autoDownloadNew(podcasts) {
    for (const pod of podcasts) {
      try {
        const data = await CastAPI.getPodcast(pod.id);
        const episodes = (data.episodes || [])
          .filter(e => !e.archived && !e.played)
          .sort((a, b) => (b['pub-date'] || 0) - (a['pub-date'] || 0))
          .slice(0, 3);
        for (const ep of episodes) {
          if (ep['audio-url'] && !this.downloadedEpisodes.has(ep['audio-url'])) {
            CastDownload.download(ep['audio-url']).catch(console.error);
          }
        }
      } catch (e) { /* ignore */ }
    }
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
    grid.innerHTML = this.podcasts.map(p => {
      const unplayed = p['unplayed-count'] || 0;
      const img = p['image-url'] || '/apps/cast/upload-icon.svg';
      return `
        <div class="podcast-card" onclick="App.navigateToPodcast('${p.id}')">
          <div class="card-img-wrap">
            <img src="${this.escHtml(img)}" alt="${this.escHtml(p.title)}"
                 onerror="this.style.background='var(--bg-card)'; this.src=''">
            ${unplayed > 0 ? `<span class="badge">${unplayed}</span>` : ''}
          </div>
          <div class="title">${this.escHtml(p.title)}</div>
          <div class="author">${this.escHtml(p.author || '')}</div>
        </div>
      `;
    }).join('');
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
    this.showArchived = false;
    this.episodeSearch = '';
    const detail = document.getElementById('podcast-detail');
    const list = document.getElementById('episode-list');
    detail.innerHTML = '<p class="loading">Loading...</p>';
    list.innerHTML = '';

    // Start polling for this podcast
    this.startPolling(async () => {
      try {
        const data = await CastAPI.getPodcast(id);
        const oldCount = (this.currentPodcast?.episodes || []).length;
        if ((data.episodes || []).length !== oldCount) {
          this.currentPodcast = data;
          const episodes = (data.episodes || []).slice();
          this.sortEpisodes(episodes);
          this.renderEpisodes(episodes, id);
        }
      } catch (e) { /* silent */ }
    }, 30000);

    try {
      const data = await CastAPI.getPodcast(id);
      this.currentPodcast = data;
      const episodes = data.episodes || [];
      this.sortEpisodes(episodes);
      const visible = episodes.filter(e => !e.archived);

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
              <div class="hamburger-menu">
                <button class="hamburger-btn" onclick="App.toggleHamburger(event)">&#8942;</button>
                <div class="hamburger-dropdown">
                  <button onclick="App.markAllPlayed('${id}')">Mark all as played</button>
                  <button onclick="App.markAllUnplayed('${id}')">Mark all as unplayed</button>
                  <button onclick="App.archiveAll('${id}')">Archive all</button>
                  <button onclick="App.unarchiveAll('${id}')">Unarchive all</button>
                  <label class="hamburger-checkbox">
                    <input type="checkbox" onchange="App.toggleShowArchived()" id="show-archived-toggle">
                    Show archived
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div class="episode-search-wrap">
          <input type="text" class="episode-search" placeholder="Search episodes..." oninput="App.handleEpisodeSearch(this.value)">
        </div>
        <div class="episode-filters">
          <button class="filter-btn active" onclick="App.filterEpisodes('all', this)">All (${visible.length})</button>
          <button class="filter-btn" onclick="App.filterEpisodes('unplayed', this)">Unplayed (${visible.filter(e => !e.played).length})</button>
          <button class="filter-btn" onclick="App.filterEpisodes('in-progress', this)">In Progress (${visible.filter(e => e.position > 0 && !e.played).length})</button>
          <button class="filter-btn" onclick="App.filterEpisodes('downloaded', this)">Downloaded</button>
          ${episodes.filter(e => e.archived).length > 0 ? `<button class="filter-btn" onclick="App.filterEpisodes('archived', this)">Archived (${episodes.filter(e => e.archived).length})</button>` : ''}
          <button class="sort-btn" onclick="App.toggleSort()">${this.episodeSortAsc ? 'Oldest' : 'Newest'}</button>
        </div>
      `;

      this.renderEpisodes(episodes, id);
    } catch (e) {
      detail.innerHTML = '<p>Failed to load podcast.</p>';
      console.error(e);
    }
  },

  // Episode search (debounced)
  _searchTimeout: null,
  handleEpisodeSearch(value) {
    clearTimeout(this._searchTimeout);
    this._searchTimeout = setTimeout(() => {
      this.episodeSearch = value.trim().toLowerCase();
      if (this.currentPodcast) {
        const episodes = (this.currentPodcast.episodes || []).slice();
        this.sortEpisodes(episodes);
        this.renderEpisodes(episodes, this.currentPodcast.id);
      }
    }, 200);
  },

  // Episode detail / show notes
  async showEpisodeDetail(podcastId, episodeId) {
    this.showPage('episode');
    const detail = document.getElementById('episode-detail');
    const backBtn = document.getElementById('episode-back-btn');
    backBtn.onclick = () => { window.location.hash = `#/podcast/${podcastId}`; };
    detail.innerHTML = '<p class="loading">Loading...</p>';

    try {
      const data = await CastAPI.getPodcast(podcastId);
      const ep = (data.episodes || []).find(e => e.id === episodeId);
      if (!ep) {
        detail.innerHTML = '<p>Episode not found.</p>';
        return;
      }
      this.currentPodcast = data;
      const es = { played: ep.played, position: ep.position || 0 };
      const img = ep['image-url'] || data['image-url'] || '';
      const isDl = this.downloadedEpisodes.has(ep['audio-url']);

      detail.innerHTML = `
        <div class="episode-detail-header">
          <img src="${this.escHtml(img)}" alt=""
               onerror="this.style.background='var(--bg-card)'; this.src=''">
          <div class="episode-detail-info">
            <div class="episode-detail-podcast">${this.escHtml(data.title)}</div>
            <h2>${this.escHtml(ep.title)}</h2>
            <div class="episode-detail-meta">
              ${this.formatDate(ep['pub-date'])}
              ${ep.duration ? ' &middot; ' + Player.formatTime(ep.duration) : ''}
              ${es.position > 0 && !es.played ? ' &middot; ' + Player.formatTime(es.position) + ' played' : ''}
              ${es.played ? ' &middot; Played' : ''}
            </div>
            <div class="episode-detail-actions">
              <button class="btn btn-small" onclick="App.playEpisode('${ep.id}')">&#9654; Play</button>
              <button class="btn btn-small btn-outline" onclick="App.enqueueEpisode('${podcastId}', '${ep.id}')">+Q Queue</button>
              <button class="btn btn-small btn-outline" onclick="App.togglePlayed('${ep.id}', ${!es.played})">
                ${es.played ? 'Mark unplayed' : 'Mark played'}
              </button>
              <button class="btn btn-small btn-outline" onclick="App.downloadEpisode('${ep['audio-url']}')" ${isDl ? 'disabled' : ''}>
                ${isDl ? 'Downloaded' : '\u2913 Download'}
              </button>
            </div>
          </div>
        </div>
        <div class="show-notes">
          <h3>Show Notes</h3>
          <div class="show-notes-content">${ep.description || '<p class="empty-state">No show notes available.</p>'}</div>
        </div>
      `;
    } catch (e) {
      detail.innerHTML = '<p>Failed to load episode.</p>';
      console.error(e);
    }
  },

  filterEpisodes(filter, btn) {
    this.episodeFilter = filter;
    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
    if (this.currentPodcast) {
      const episodes = (this.currentPodcast.episodes || []).slice();
      this.sortEpisodes(episodes);
      this.renderEpisodes(episodes, this.currentPodcast.id);
    }
  },

  renderEpisodes(episodes, podcastId) {
    const list = document.getElementById('episode-list');
    let filtered = episodes;

    // Apply search filter
    if (this.episodeSearch) {
      filtered = filtered.filter(e => e.title.toLowerCase().includes(this.episodeSearch));
    }

    if (this.episodeFilter === 'archived') {
      filtered = filtered.filter(e => e.archived);
    } else if (this.episodeFilter === 'downloaded') {
      filtered = filtered.filter(e => this.downloadedEpisodes.has(e['audio-url']));
    } else {
      // hide archived unless toggled
      if (!this.showArchived) {
        filtered = filtered.filter(e => !e.archived);
      }
      if (this.episodeFilter === 'unplayed') {
        filtered = filtered.filter(e => !e.played);
      } else if (this.episodeFilter === 'in-progress') {
        filtered = filtered.filter(e => e.position > 0 && !e.played);
      }
    }

    if (filtered.length === 0) {
      list.innerHTML = '<p class="empty-state">No episodes match this filter.</p>';
      return;
    }

    list.innerHTML = filtered.map(ep => {
      const isDl = this.downloadedEpisodes.has(ep['audio-url']);
      return `
        <div class="episode-item ${ep.played ? 'played' : ''} ${ep.archived ? 'archived' : ''}" data-eid="${ep.id}">
          <div class="play-icon" onclick="App.playEpisode('${ep.id}')">&#9654;</div>
          <div class="ep-info" onclick="window.location.hash='#/episode/${podcastId}/${ep.id}'">
            <div class="ep-title">${this.escHtml(ep.title)}</div>
            <div class="ep-meta">
              ${this.formatDate(ep['pub-date'])}
              ${ep.duration ? ' \u00b7 ' + Player.formatTime(ep.duration) : ''}
              ${ep.position > 0 && !ep.played ? ' \u00b7 ' + Player.formatTime(ep.position) + ' played' : ''}
              ${isDl ? ' \u00b7 \u2913' : ''}
            </div>
          </div>
          <div class="episode-actions">
            <button onclick="App.downloadEpisode('${ep['audio-url']}')" title="Download" ${isDl ? 'disabled' : ''}>${isDl ? '\u2713' : '\u2913'}</button>
            <button onclick="App.enqueueEpisode('${podcastId}', '${ep.id}')" title="Add to queue">+Q</button>
            <button onclick="App.togglePlayed('${ep.id}', ${!ep.played})" title="Toggle played">
              ${ep.played ? '\u21a9' : '\u2713'}
            </button>
            <button onclick="App.toggleArchived('${ep.id}', ${!ep.archived})" title="${ep.archived ? 'Unarchive' : 'Archive'}">
              ${ep.archived ? '\u21a9A' : 'A'}
            </button>
          </div>
        </div>
      `;
    }).join('');
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

  toggleHamburger(event) {
    event.stopPropagation();
    const dropdown = event.currentTarget.nextElementSibling;
    const isOpen = dropdown.classList.contains('open');
    // close any open dropdowns
    document.querySelectorAll('.hamburger-dropdown.open').forEach(d => d.classList.remove('open'));
    if (!isOpen) {
      dropdown.classList.add('open');
      // close on outside click
      const close = () => { dropdown.classList.remove('open'); document.removeEventListener('click', close); };
      setTimeout(() => document.addEventListener('click', close), 0);
    }
  },

  async markAllPlayed(podcastId) {
    document.querySelectorAll('.hamburger-dropdown.open').forEach(d => d.classList.remove('open'));
    try {
      await CastAPI.markAllPlayed(podcastId);
      this.toast('Marked all as played', 'success');
      this.showPodcastDetail(podcastId);
    } catch (e) {
      console.error(e);
      this.toast('Failed to mark all played', 'error');
    }
  },

  async markAllUnplayed(podcastId) {
    document.querySelectorAll('.hamburger-dropdown.open').forEach(d => d.classList.remove('open'));
    try {
      await CastAPI.markAllUnplayed(podcastId);
      this.toast('Marked all as unplayed', 'success');
      this.showPodcastDetail(podcastId);
    } catch (e) {
      console.error(e);
      this.toast('Failed to mark all unplayed', 'error');
    }
  },

  async archiveAll(podcastId) {
    document.querySelectorAll('.hamburger-dropdown.open').forEach(d => d.classList.remove('open'));
    try {
      await CastAPI.archiveAll(podcastId);
      this.toast('Archived all episodes', 'success');
      this.showPodcastDetail(podcastId);
    } catch (e) {
      console.error(e);
      this.toast('Failed to archive all', 'error');
    }
  },

  async unarchiveAll(podcastId) {
    document.querySelectorAll('.hamburger-dropdown.open').forEach(d => d.classList.remove('open'));
    try {
      await CastAPI.unarchiveAll(podcastId);
      this.toast('Unarchived all episodes', 'success');
      this.showPodcastDetail(podcastId);
    } catch (e) {
      console.error(e);
      this.toast('Failed to unarchive all', 'error');
    }
  },

  toggleShowArchived() {
    this.showArchived = !this.showArchived;
    if (this.currentPodcast) {
      const episodes = (this.currentPodcast.episodes || []).slice();
      this.sortEpisodes(episodes);
      this.renderEpisodes(episodes, this.currentPodcast.id);
    }
  },

  async toggleArchived(episodeId, archived) {
    try {
      await CastAPI.setArchived(episodeId, archived);
      this.toast(archived ? 'Archived' : 'Unarchived', 'success');
      if (this.currentPodcast) {
        this.showPodcastDetail(this.currentPodcast.id);
      }
    } catch (e) {
      console.error(e);
      this.toast('Failed to update archive status', 'error');
    }
  },

  // Download
  async downloadEpisode(audioUrl) {
    if (!audioUrl || this.downloadedEpisodes.has(audioUrl)) return;
    this.toast('Downloading...');
    try {
      await CastDownload.download(audioUrl);
      this.toast('Downloaded!', 'success');
      // Re-render current view to update download indicators
      if (this.currentPodcast) {
        const episodes = (this.currentPodcast.episodes || []).slice();
        this.sortEpisodes(episodes);
        this.renderEpisodes(episodes, this.currentPodcast.id);
      }
    } catch (e) {
      console.error(e);
      this.toast('Download failed', 'error');
    }
  },

  // History
  async loadHistory() {
    const list = document.getElementById('history-list');
    list.innerHTML = '<p class="loading">Loading...</p>';

    try {
      const data = await CastAPI.getHistory();
      const history = data.history || [];

      if (history.length === 0) {
        list.innerHTML = '<p class="empty-state">No listening history yet.</p>';
        return;
      }

      // Group by date
      const groups = {};
      history.forEach(item => {
        const d = new Date(item.timestamp * 1000);
        const key = d.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });
        if (!groups[key]) groups[key] = [];
        groups[key].push(item);
      });

      list.innerHTML = Object.entries(groups).map(([date, items]) => `
        <div class="history-group">
          <h3 class="history-date">${date}</h3>
          ${items.map(item => `
            <div class="episode-item" onclick="window.location.hash='#/podcast/${item['podcast-id']}'">
              <img class="history-img" src="${this.escHtml(item['image-url'] || '')}" alt=""
                   onerror="this.style.background='var(--bg-card)'; this.src=''">
              <div class="ep-info">
                <div class="ep-title">${this.escHtml(item['episode-title'] || 'Unknown episode')}</div>
                <div class="ep-meta">${this.escHtml(item['podcast-title'] || '')} &middot; ${new Date(item.timestamp * 1000).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}</div>
              </div>
            </div>
          `).join('')}
        </div>
      `).join('');
    } catch (e) {
      console.error(e);
      list.innerHTML = '<p class="empty-state">Failed to load history.</p>';
    }
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

  loadSettingsPage() {
    // Load toggles from localStorage
    document.getElementById('setting-autoplay-next').checked = localStorage.getItem('cast-autoplay-next') === 'true';
    document.getElementById('setting-auto-download').checked = localStorage.getItem('cast-auto-download') === 'true';
  },

  async handleSaveSettings() {
    const speed = parseInt(document.getElementById('setting-speed').value);
    const refresh = parseInt(document.getElementById('setting-refresh').value) * 3600;
    const autoDownload = document.getElementById('setting-autodownload').checked;

    // Save localStorage settings
    localStorage.setItem('cast-autoplay-next', document.getElementById('setting-autoplay-next').checked);
    localStorage.setItem('cast-auto-download', document.getElementById('setting-auto-download').checked);

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

  // OPML Export
  async handleExportOpml() {
    try {
      const xml = await CastAPI.getExportOpml();
      const blob = new Blob([xml], { type: 'text/xml' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'cast-subscriptions.opml';
      a.click();
      URL.revokeObjectURL(url);
      this.toast('Exported!', 'success');
    } catch (e) {
      console.error(e);
      this.toast('Failed to export', 'error');
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
    const prevCount = this.podcasts.length;

    try {
      await CastAPI.subscribe(url);
      input.value = '';
      this.toast('Fetching and parsing feed...');
      // poll until new podcast appears or timeout
      const start = Date.now();
      const poll = async () => {
        try {
          const data = await CastAPI.getPodcasts();
          if ((data.podcasts || []).length > prevCount) {
            this.podcasts = data.podcasts;
            this.renderPodcasts();
            window.location.hash = '#/';
            btn.textContent = 'Subscribe';
            btn.disabled = false;
            this.toast('Subscribed!', 'success');
            return;
          }
        } catch (e) { /* ignore poll errors */ }
        if (Date.now() - start > 120000) {
          await this.loadPodcasts();
          btn.textContent = 'Subscribe';
          btn.disabled = false;
          this.toast('Feed is still loading, check back shortly');
          return;
        }
        setTimeout(poll, 1500);
      };
      setTimeout(poll, 1500);
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
    const prevCount = this.podcasts.length;

    try {
      await CastAPI.importOpml(urls);
      this.toast(`Importing ${urls.length} feeds...`);
      fileInput.value = '';
      // poll until all feeds arrive or timeout
      const start = Date.now();
      const target = prevCount + urls.length;
      const poll = async () => {
        try {
          const data = await CastAPI.getPodcasts();
          const cur = (data.podcasts || []).length;
          btn.textContent = `Importing... (${cur - prevCount}/${urls.length})`;
          if (cur >= target) {
            this.podcasts = data.podcasts;
            this.renderPodcasts();
            window.location.hash = '#/';
            btn.textContent = 'Import';
            btn.disabled = false;
            this.toast('OPML import complete!', 'success');
            return;
          }
        } catch (e) { /* ignore poll errors */ }
        if (Date.now() - start > 180000) {
          await this.loadPodcasts();
          btn.textContent = 'Import';
          btn.disabled = false;
          this.toast('Some feeds are still loading, check back shortly');
          return;
        }
        setTimeout(poll, 2000);
      };
      setTimeout(poll, 2000);
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

  sortEpisodes(episodes) {
    const dir = this.episodeSortAsc ? -1 : 1;
    episodes.sort((a, b) => dir * ((b['pub-date'] || 0) - (a['pub-date'] || 0)));
    return episodes;
  },

  toggleSort() {
    this.episodeSortAsc = !this.episodeSortAsc;
    if (this.currentPodcast) {
      const episodes = (this.currentPodcast.episodes || []).slice();
      this.sortEpisodes(episodes);
      this.renderEpisodes(episodes, this.currentPodcast.id);
      // Update button text
      const btn = document.querySelector('.sort-btn');
      if (btn) btn.textContent = this.episodeSortAsc ? 'Oldest' : 'Newest';
    }
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
