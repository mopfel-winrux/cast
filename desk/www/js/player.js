// Cast Audio Player Controller

const Player = {
  audio: null,
  currentEpisode: null,
  currentPodcast: null,
  saveInterval: null,
  sleepTimeout: null,
  sleepEndTime: null,
  sleepCountdown: null,
  podcastSpeeds: {},
  resumePollTimer: null,

  init() {
    this.audio = document.getElementById('audio-element');
    this.bar = document.getElementById('player-bar');
    this.playPauseBtn = document.getElementById('play-pause');
    this.seekBar = document.getElementById('seek-bar');
    this.currentTimeEl = document.getElementById('current-time');
    this.totalTimeEl = document.getElementById('total-time');
    this.speedSelect = document.getElementById('player-speed');
    this.sleepSelect = document.getElementById('sleep-timer');

    // Event listeners
    this.playPauseBtn.addEventListener('click', () => this.togglePlay());
    document.getElementById('skip-back').addEventListener('click', () => this.skip(-15));
    document.getElementById('skip-forward').addEventListener('click', () => this.skip(30));

    this.seekBar.addEventListener('input', () => {
      if (this.audio.duration) {
        this.audio.currentTime = (this.seekBar.value / 100) * this.audio.duration;
      }
    });

    this.speedSelect.addEventListener('change', () => {
      const speed = parseFloat(this.speedSelect.value);
      this.audio.playbackRate = speed;
      if (this.currentPodcast && this.currentPodcast.id) {
        const speedInt = Math.round(speed * 100);
        this.podcastSpeeds[this.currentPodcast.id] = speedInt;
        CastAPI.setPodcastSpeed(this.currentPodcast.id, speedInt).catch(console.error);
      }
    });

    this.sleepSelect.addEventListener('change', () => this.setSleepTimer());

    this.audio.addEventListener('timeupdate', () => {
      this.updateProgress();
      this.updateChapterHighlight();
    });
    this.audio.addEventListener('ended', () => this.onEnded());
    this.audio.addEventListener('loadedmetadata', () => {
      this.totalTimeEl.textContent = this.formatTime(this.audio.duration);
    });

    // Bookmark button in player bar
    const bookmarkBtn = document.getElementById('player-bookmark');
    if (bookmarkBtn) {
      bookmarkBtn.addEventListener('click', () => this.quickBookmark());
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      const tag = (e.target.tagName || '').toLowerCase();
      if (tag === 'input' || tag === 'select' || tag === 'textarea') return;
      switch (e.key) {
        case ' ':
          e.preventDefault();
          this.togglePlay();
          break;
        case 'ArrowLeft':
          this.skip(-15);
          break;
        case 'ArrowRight':
          this.skip(30);
          break;
        case 'm':
          if (this.audio.src) this.audio.muted = !this.audio.muted;
          break;
      }
    });

    // Download tracking: re-scan cache on tab visibility change
    document.addEventListener('visibilitychange', async () => {
      if (document.visibilityState === 'visible') {
        try {
          await CastDownload.init();
          if (typeof App !== 'undefined') App.refreshCurrentView();
        } catch (e) { /* ignore */ }
      }
    });

    // MediaSession API
    this.setupMediaSession();

    // Load per-podcast speeds from backend
    this.loadPodcastSpeeds();

    // Cross-device resume: check for current episode on init
    this.checkResume();

    // Start resume polling (only when paused)
    this.startResumePoll();
  },

  async loadPodcastSpeeds() {
    try {
      const data = await CastAPI.getPodcastSpeeds();
      this.podcastSpeeds = data.speeds || {};
    } catch (e) { /* ignore */ }
  },

  setupMediaSession() {
    if (!('mediaSession' in navigator)) return;
    navigator.mediaSession.setActionHandler('play', () => {
      this.audio.play();
      this.playPauseBtn.innerHTML = '&#9646;&#9646;';
      navigator.mediaSession.playbackState = 'playing';
    });
    navigator.mediaSession.setActionHandler('pause', () => {
      this.audio.pause();
      this.playPauseBtn.innerHTML = '&#9654;';
      navigator.mediaSession.playbackState = 'paused';
    });
    navigator.mediaSession.setActionHandler('seekbackward', () => this.skip(-15));
    navigator.mediaSession.setActionHandler('seekforward', () => this.skip(30));
    navigator.mediaSession.setActionHandler('nexttrack', async () => {
      try {
        const data = await CastAPI.getQueue();
        const queue = data.queue || [];
        if (queue.length > 0) {
          const next = queue[0];
          const ep = {
            id: next['episode-id'], title: next.title || '',
            'audio-url': next['audio-url'] || '', 'image-url': next['image-url'] || '', position: 0
          };
          const pod = {
            id: next['podcast-id'], title: next['podcast-title'] || '',
            'image-url': next['podcast-image'] || ''
          };
          this.play(ep, pod);
        }
      } catch (e) { console.error('nexttrack failed:', e); }
    });
  },

  updateMediaSession() {
    if (!('mediaSession' in navigator) || !this.currentEpisode) return;
    const ep = this.currentEpisode;
    const pod = this.currentPodcast;
    const artwork = [];
    const imgUrl = ep['image-url'] || (pod ? pod['image-url'] : '');
    if (imgUrl) artwork.push({ src: imgUrl, sizes: '512x512', type: 'image/png' });
    navigator.mediaSession.metadata = new MediaMetadata({
      title: ep.title || '',
      artist: pod ? pod.title : '',
      artwork: artwork
    });
  },

  isYouTubeUrl(url) {
    return url && (url.includes('youtube.com/watch') || url.includes('youtu.be/'));
  },

  getYouTubeId(url) {
    if (!url) return null;
    const match = url.match(/[?&]v=([^&]+)/) || url.match(/youtu\.be\/([^?&]+)/);
    return match ? match[1] : null;
  },

  showYouTubeEmbed(videoId) {
    let container = document.getElementById('youtube-embed');
    if (!container) {
      container = document.createElement('div');
      container.id = 'youtube-embed';
      document.getElementById('content').appendChild(container);
    }
    container.innerHTML = `<div class="yt-embed-wrap">
      <button class="yt-close" onclick="Player.hideYouTubeEmbed()">&times;</button>
      <iframe src="https://www.youtube.com/embed/${videoId}?autoplay=1"
        frameborder="0" allow="autoplay; encrypted-media" allowfullscreen></iframe>
    </div>`;
    container.classList.add('active');
  },

  hideYouTubeEmbed() {
    const container = document.getElementById('youtube-embed');
    if (container) {
      container.classList.remove('active');
      container.innerHTML = '';
    }
  },

  async play(episode, podcast) {
    this.currentEpisode = episode;
    this.currentPodcast = podcast;

    // YouTube URLs — embed the video
    if (this.isYouTubeUrl(episode['audio-url'])) {
      this.audio.pause();
      this.audio.src = '';
      const videoId = this.getYouTubeId(episode['audio-url']);
      if (videoId) {
        this.showYouTubeEmbed(videoId);
      }
      this.show(episode, podcast);
      if (podcast && episode) {
        CastAPI.setCurrent(podcast.id, episode.id).catch(console.error);
        CastAPI.setPlayed(episode.id, true).catch(console.error);
      }
      return;
    }

    // Non-YouTube: hide any embed
    this.hideYouTubeEmbed();

    // Check browser cache first
    const audioUrl = await CastDownload.getUrl(episode['audio-url']);
    this.audio.src = audioUrl;

    // Resume from saved position after audio loads
    if (episode.position && episode.position > 0) {
      const resumePos = episode.position;
      const onLoaded = () => {
        this.audio.currentTime = resumePos;
        this.audio.removeEventListener('loadedmetadata', onLoaded);
      };
      this.audio.addEventListener('loadedmetadata', onLoaded);
    }

    // Restore per-podcast speed or fallback to global
    if (podcast && podcast.id && this.podcastSpeeds[podcast.id]) {
      const speed = this.podcastSpeeds[podcast.id] / 100;
      this.audio.playbackRate = speed;
      this.speedSelect.value = speed;
    } else {
      this.audio.playbackRate = parseFloat(this.speedSelect.value);
    }

    this.audio.play();
    this.show(episode, podcast);
    this.updateMediaSession();
    this.renderChapters(episode.chapters || []);

    // Save position periodically
    if (this.saveInterval) clearInterval(this.saveInterval);
    this.saveInterval = setInterval(() => this.savePosition(), 15000);

    // Tell backend
    if (podcast && episode) {
      CastAPI.setCurrent(podcast.id, episode.id).catch(console.error);
    }
  },

  show(episode, podcast) {
    this.bar.classList.remove('hidden');
    document.getElementById('player-title').textContent = episode.title;
    document.getElementById('player-podcast').textContent = podcast ? podcast.title : '';
    const art = document.getElementById('player-art');
    const imgUrl = episode['image-url'] || (podcast ? podcast['image-url'] : '');
    if (imgUrl) {
      art.src = imgUrl;
      art.style.display = 'block';
    } else {
      art.style.display = 'none';
    }
    this.playPauseBtn.innerHTML = '&#9646;&#9646;';

    // Show current chapter subtitle
    const chapterEl = document.getElementById('player-chapter');
    if (chapterEl) chapterEl.textContent = '';
  },

  togglePlay() {
    if (!this.audio.src) return;
    if (this.audio.paused) {
      this.audio.play();
      this.playPauseBtn.innerHTML = '&#9646;&#9646;';
      if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'playing';
    } else {
      this.audio.pause();
      this.playPauseBtn.innerHTML = '&#9654;';
      if ('mediaSession' in navigator) navigator.mediaSession.playbackState = 'paused';
      this.clearSleepTimer();
    }
  },

  skip(seconds) {
    if (!this.audio.src) return;
    this.audio.currentTime = Math.max(0, this.audio.currentTime + seconds);
  },

  updateProgress() {
    if (!this.audio.duration) return;
    const pct = (this.audio.currentTime / this.audio.duration) * 100;
    this.seekBar.value = pct;
    this.currentTimeEl.textContent = this.formatTime(this.audio.currentTime);
    this.totalTimeEl.textContent = this.formatTime(this.audio.duration);
    if ('mediaSession' in navigator) {
      try {
        navigator.mediaSession.setPositionState({
          duration: this.audio.duration,
          playbackRate: this.audio.playbackRate,
          position: this.audio.currentTime
        });
      } catch (e) { /* ignore */ }
    }
  },

  savePosition() {
    if (!this.currentEpisode || !this.audio.currentTime) return;
    CastAPI.setPosition(this.currentEpisode.id, this.audio.currentTime).catch(console.error);
    // Log listen time
    if (this.currentPodcast && this.currentPodcast.id) {
      CastAPI.logListen(this.currentPodcast.id, 15).catch(console.error);
    }
  },

  // Sleep timer
  setSleepTimer() {
    this.clearSleepTimer();
    const minutes = parseInt(this.sleepSelect.value);
    if (!minutes) return;

    this.sleepEndTime = Date.now() + minutes * 60 * 1000;
    this.sleepTimeout = setTimeout(() => {
      this.audio.pause();
      this.playPauseBtn.innerHTML = '&#9654;';
      this.clearSleepTimer();
      App.toast('Sleep timer ended');
    }, minutes * 60 * 1000);

    this.sleepCountdown = setInterval(() => {
      const remaining = Math.max(0, this.sleepEndTime - Date.now());
      const mins = Math.ceil(remaining / 60000);
      if (mins <= 0) {
        this.clearSleepTimer();
      }
    }, 60000);
  },

  clearSleepTimer() {
    if (this.sleepTimeout) { clearTimeout(this.sleepTimeout); this.sleepTimeout = null; }
    if (this.sleepCountdown) { clearInterval(this.sleepCountdown); this.sleepCountdown = null; }
    this.sleepEndTime = null;
    if (this.sleepSelect) this.sleepSelect.value = '0';
  },

  async onEnded() {
    this.savePosition();
    this.clearSleepTimer();
    if (this.currentEpisode) {
      CastAPI.setPlayed(this.currentEpisode.id, true).catch(console.error);
    }
    // Log completion
    if (this.currentPodcast && this.currentPodcast.id) {
      CastAPI.logComplete(this.currentPodcast.id).catch(console.error);
    }
    // Dequeue the finished episode, then advance to next
    try {
      if (this.currentPodcast && this.currentEpisode) {
        await CastAPI.dequeue(this.currentPodcast.id, this.currentEpisode.id).catch(console.error);
      }
      const data = await CastAPI.getQueue();
      const queue = data.queue || [];
      if (queue.length > 0) {
        const next = queue[0];
        const ep = {
          id: next['episode-id'],
          title: next.title || '',
          'audio-url': next['audio-url'] || '',
          'image-url': next['image-url'] || '',
          position: 0
        };
        const pod = {
          id: next['podcast-id'],
          title: next['podcast-title'] || '',
          'image-url': next['podcast-image'] || ''
        };
        this.play(ep, pod);
        return;
      }
    } catch (e) { console.error('Queue advance failed:', e); }

    // Auto-play next episode from same podcast
    if (localStorage.getItem('cast-autoplay-next') === 'true' && this.currentPodcast && this.currentEpisode) {
      try {
        const data = await CastAPI.getPodcast(this.currentPodcast.id);
        const episodes = (data.episodes || [])
          .filter(e => !e.archived)
          .sort((a, b) => (a['pub-date'] || 0) - (b['pub-date'] || 0));
        const curIdx = episodes.findIndex(e => e.id === this.currentEpisode.id);
        if (curIdx >= 0 && curIdx < episodes.length - 1) {
          const next = episodes[curIdx + 1];
          if (!next.played) {
            this.play(next, this.currentPodcast);
            return;
          }
        }
      } catch (e) { console.error('Auto-play next failed:', e); }
    }

    this.playPauseBtn.innerHTML = '&#9654;';
  },

  // Chapters
  renderChapters(chapters) {
    const container = document.getElementById('chapter-list');
    if (!container) return;
    if (!chapters || chapters.length === 0) {
      container.innerHTML = '';
      container.style.display = 'none';
      return;
    }
    container.style.display = 'block';
    container.innerHTML = `
      <div class="chapter-header" onclick="this.parentElement.classList.toggle('collapsed')">
        Chapters (${chapters.length})
      </div>
      <div class="chapter-items">
        ${chapters.map((ch, i) => `
          <div class="chapter-item" data-ci="${i}" data-start="${ch.start}" onclick="Player.seekToChapter(${ch.start})">
            <span class="chapter-time">${this.formatTime(ch.start)}</span>
            <span class="chapter-title">${this.escHtml(ch.title)}</span>
          </div>
        `).join('')}
      </div>
    `;
  },

  seekToChapter(seconds) {
    if (this.audio.src) {
      this.audio.currentTime = seconds;
    }
  },

  updateChapterHighlight() {
    const container = document.getElementById('chapter-list');
    if (!container || !this.currentEpisode) return;
    const chapters = this.currentEpisode.chapters || [];
    if (chapters.length === 0) return;
    const ct = this.audio.currentTime;
    let activeIdx = -1;
    for (let i = chapters.length - 1; i >= 0; i--) {
      if (ct >= chapters[i].start) { activeIdx = i; break; }
    }
    container.querySelectorAll('.chapter-item').forEach((el, i) => {
      el.classList.toggle('active', i === activeIdx);
    });
    // Update player bar chapter subtitle
    const chapterEl = document.getElementById('player-chapter');
    if (chapterEl && activeIdx >= 0) {
      chapterEl.textContent = chapters[activeIdx].title;
    } else if (chapterEl) {
      chapterEl.textContent = '';
    }
  },

  // Quick bookmark from player bar
  async quickBookmark() {
    if (!this.currentEpisode || !this.audio.currentTime) return;
    const pos = Math.floor(this.audio.currentTime);
    try {
      await CastAPI.addBookmark(this.currentEpisode.id, pos, 'Bookmark');
      App.toast('Bookmark added at ' + this.formatTime(pos), 'success');
    } catch (e) {
      App.toast('Failed to add bookmark', 'error');
    }
  },

  // Cross-device resume
  async checkResume() {
    try {
      const data = await CastAPI.getPlayer();
      if (!data.current) return;
      // If we're not currently playing anything, show resume banner
      if (!this.currentEpisode) {
        this.showResumeBanner(data.current);
      }
    } catch (e) { /* ignore */ }
  },

  showResumeBanner(current) {
    const existing = document.getElementById('resume-banner');
    if (existing) existing.remove();
    if (!current['episode-title']) return;
    const pos = current.position || 0;
    const banner = document.createElement('div');
    banner.id = 'resume-banner';
    banner.className = 'resume-banner';
    banner.innerHTML = `
      <span>Resume: ${this.escHtml(current['episode-title'])}${pos > 0 ? ' \u2014 ' + this.formatTime(pos) : ''}</span>
      <button class="btn btn-small" onclick="Player.resumeFromBanner()">Play</button>
      <button class="resume-dismiss" onclick="this.parentElement.remove()">&times;</button>
    `;
    banner._data = current;
    const home = document.getElementById('page-home');
    if (home) home.prepend(banner);
  },

  async resumeFromBanner() {
    const banner = document.getElementById('resume-banner');
    if (!banner || !banner._data) return;
    const cur = banner._data;
    const ep = {
      id: cur['episode-id'],
      title: cur['episode-title'] || '',
      'audio-url': '',
      'image-url': cur['image-url'] || '',
      position: cur.position || 0
    };
    const pod = {
      id: cur['podcast-id'],
      title: cur['podcast-title'] || '',
      'image-url': cur['image-url'] || ''
    };
    // Fetch full episode data to get audio-url
    try {
      const data = await CastAPI.getPodcast(cur['podcast-id']);
      const fullEp = (data.episodes || []).find(e => e.id === cur['episode-id']);
      if (fullEp) {
        ep['audio-url'] = fullEp['audio-url'];
        ep['image-url'] = fullEp['image-url'] || ep['image-url'];
        ep.chapters = fullEp.chapters || [];
      }
    } catch (e) { /* use what we have */ }
    banner.remove();
    this.play(ep, pod);
  },

  startResumePoll() {
    if (this.resumePollTimer) clearInterval(this.resumePollTimer);
    this.resumePollTimer = setInterval(async () => {
      // Only poll when paused and we have a current episode
      if (!this.currentEpisode || !this.audio.paused) return;
      try {
        const data = await CastAPI.getPlayer();
        if (!data.current) return;
        if (data.current['episode-id'] === this.currentEpisode.id) {
          const serverPos = data.current.position || 0;
          const localPos = Math.floor(this.audio.currentTime || 0);
          if (Math.abs(serverPos - localPos) > 5) {
            this.audio.currentTime = serverPos;
            App.toast('Position updated from another device');
          }
        }
      } catch (e) { /* ignore */ }
    }, 30000);
  },

  formatTime(seconds) {
    if (!seconds || isNaN(seconds)) return '0:00';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    return `${m}:${s.toString().padStart(2, '0')}`;
  },

  escHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  },

  setSpeed(speed) {
    this.audio.playbackRate = speed;
    this.speedSelect.value = speed;
  },

  destroy() {
    if (this.saveInterval) clearInterval(this.saveInterval);
    if (this.resumePollTimer) clearInterval(this.resumePollTimer);
    this.clearSleepTimer();
    this.savePosition();
  }
};

// Browser Cache API for offline episode storage
const CastDownload = {
  CACHE_NAME: 'cast-audio',
  downloading: new Set(),
  cacheAvailable: ('caches' in window),

  async init() {
    if (!this.cacheAvailable) return;
    try {
      const cache = await caches.open(this.CACHE_NAME);
      const keys = await cache.keys();
      App.downloadedEpisodes = new Set(keys.map(r => r.url));
    } catch (e) {
      this.cacheAvailable = false;
    }
  },

  async download(url, onProgress) {
    if (!this.cacheAvailable) throw new Error('Cache API not available');
    if (this.downloading.has(url)) return;
    this.downloading.add(url);
    try {
      const resp = await fetch(url);
      if (!resp.ok) throw new Error('Download failed');
      const cache = await caches.open(this.CACHE_NAME);
      await cache.put(url, resp);
      App.downloadedEpisodes.add(url);
    } finally {
      this.downloading.delete(url);
    }
  },

  async isDownloaded(url) {
    if (!this.cacheAvailable) return false;
    try {
      const cache = await caches.open(this.CACHE_NAME);
      const match = await cache.match(url);
      return !!match;
    } catch (e) { return false; }
  },

  async getUrl(originalUrl) {
    if (!this.cacheAvailable) return originalUrl;
    try {
      const cache = await caches.open(this.CACHE_NAME);
      const match = await cache.match(originalUrl);
      if (match) {
        const blob = await match.blob();
        return URL.createObjectURL(blob);
      }
    } catch (e) { /* fall through */ }
    return originalUrl;
  },

  async remove(url) {
    if (!this.cacheAvailable) return;
    try {
      const cache = await caches.open(this.CACHE_NAME);
      await cache.delete(url);
      App.downloadedEpisodes.delete(url);
      // Re-render current view after remove
      if (typeof App !== 'undefined') App.refreshCurrentView();
    } catch (e) { /* ignore */ }
  }
};
