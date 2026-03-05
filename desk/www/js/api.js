// Cast API client
// Communicates with the %cast agent via JSON HTTP API

const CastAPI = {
  base: '/apps/cast/api',

  // GET request to scry endpoint
  async get(path) {
    const res = await fetch(`${this.base}/${path}`, {
      credentials: 'include'
    });
    if (!res.ok) throw new Error(`API error: ${res.status}`);
    return res.json();
  },

  // POST action to agent — emits cast-state-changed on success
  async poke(action) {
    const res = await fetch(this.base, {
      method: 'POST',
      credentials: 'include',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(action)
    });
    if (!res.ok) throw new Error(`Poke error: ${res.status}`);
    const data = await res.json();
    window.dispatchEvent(new CustomEvent('cast-state-changed'));
    return data;
  },

  // Podcast operations
  getPodcasts() { return this.get('podcasts'); },
  getPodcast(id) { return this.get(`podcast/${id}`); },
  getEpisodes(podcastId) { return this.get(`episodes/${podcastId}`); },
  getQueue() { return this.get('queue'); },
  getPlayer() { return this.get('player'); },
  getSettings() { return this.get('settings'); },
  getHistory() { return this.get('history'); },
  getStats() { return this.get('stats'); },

  async getExportOpml() {
    const res = await fetch(`${this.base}/export-opml`, { credentials: 'include' });
    if (!res.ok) throw new Error(`API error: ${res.status}`);
    return res.text();
  },

  subscribe(url) {
    return this.poke({ action: 'subscribe', url });
  },

  unsubscribe(podcastId) {
    return this.poke({ action: 'unsubscribe', 'podcast-id': podcastId });
  },

  refresh(podcastId) {
    return this.poke({ action: 'refresh', 'podcast-id': podcastId });
  },

  refreshAll() {
    return this.poke({ action: 'refresh-all' });
  },

  setPosition(episodeId, position) {
    return this.poke({ action: 'set-position', 'episode-id': episodeId, position: Math.floor(position) });
  },

  setPlayed(episodeId, played) {
    return this.poke({ action: 'set-played', 'episode-id': episodeId, played });
  },

  enqueue(podcastId, episodeId) {
    return this.poke({ action: 'enqueue', 'podcast-id': podcastId, 'episode-id': episodeId });
  },

  dequeue(podcastId, episodeId) {
    return this.poke({ action: 'dequeue', 'podcast-id': podcastId, 'episode-id': episodeId });
  },

  setCurrent(podcastId, episodeId) {
    return this.poke({ action: 'set-current', 'podcast-id': podcastId, 'episode-id': episodeId });
  },

  clearCurrent() {
    return this.poke({ action: 'clear-current' });
  },

  setSettings(settings) {
    return this.poke({
      action: 'set-settings',
      'playback-speed': settings.playbackSpeed,
      'auto-download': settings.autoDownload,
      'refresh-interval': settings.refreshInterval
    });
  },

  importOpml(urls) {
    return this.poke({ action: 'import-opml', urls });
  },

  getS3Config() { return this.get('s3-config'); },

  addEpisode(podcastId, title, audioUrl) {
    return this.poke({ action: 'add-episode', 'podcast-id': podcastId, title, 'audio-url': audioUrl });
  },

  setArchived(episodeId, archived) {
    return this.poke({ action: 'set-archived', 'episode-id': episodeId, archived });
  },

  markAllPlayed(podcastId) {
    return this.poke({ action: 'mark-all-played', 'podcast-id': podcastId });
  },

  markAllUnplayed(podcastId) {
    return this.poke({ action: 'mark-all-unplayed', 'podcast-id': podcastId });
  },

  archiveAll(podcastId) {
    return this.poke({ action: 'archive-all', 'podcast-id': podcastId });
  },

  unarchiveAll(podcastId) {
    return this.poke({ action: 'unarchive-all', 'podcast-id': podcastId });
  },

  reorderQueue(order) {
    return this.poke({ action: 'reorder-queue', order });
  },

  getFeedErrors() { return this.get('feed-errors'); },

  markBeforePlayed(podcastId, date) {
    return this.poke({ action: 'mark-before-played', 'podcast-id': podcastId, date });
  },

  getPodcastSpeeds() { return this.get('podcast-speeds'); },

  setPodcastSpeed(podcastId, speed) {
    return this.poke({ action: 'set-podcast-speed', 'podcast-id': podcastId, speed });
  },

  reorderPodcasts(order) {
    return this.poke({ action: 'reorder-podcasts', order });
  },

  // Notes & bookmarks
  setNote(episodeId, note) {
    return this.poke({ action: 'set-note', 'episode-id': episodeId, note });
  },

  addBookmark(episodeId, position, label) {
    return this.poke({ action: 'add-bookmark', 'episode-id': episodeId, position: Math.floor(position), label });
  },

  removeBookmark(episodeId, position) {
    return this.poke({ action: 'remove-bookmark', 'episode-id': episodeId, position: Math.floor(position) });
  },

  // Stats
  logListen(podcastId, seconds) {
    return this.poke({ action: 'log-listen', 'podcast-id': podcastId, seconds });
  },

  logComplete(podcastId) {
    return this.poke({ action: 'log-complete', 'podcast-id': podcastId });
  }
};
