// Cast Audio Player Controller

const Player = {
  audio: null,
  currentEpisode: null,
  currentPodcast: null,
  saveInterval: null,
  sleepTimeout: null,
  sleepEndTime: null,
  sleepCountdown: null,

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
      this.audio.playbackRate = parseFloat(this.speedSelect.value);
    });

    this.sleepSelect.addEventListener('change', () => this.setSleepTimer());

    this.audio.addEventListener('timeupdate', () => this.updateProgress());
    this.audio.addEventListener('ended', () => this.onEnded());
    this.audio.addEventListener('loadedmetadata', () => {
      this.totalTimeEl.textContent = this.formatTime(this.audio.duration);
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

    this.audio.play();
    this.show(episode, podcast);

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
  },

  togglePlay() {
    if (!this.audio.src) return;
    if (this.audio.paused) {
      this.audio.play();
      this.playPauseBtn.innerHTML = '&#9646;&#9646;';
    } else {
      this.audio.pause();
      this.playPauseBtn.innerHTML = '&#9654;';
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
  },

  savePosition() {
    if (!this.currentEpisode || !this.audio.currentTime) return;
    CastAPI.setPosition(this.currentEpisode.id, this.audio.currentTime).catch(console.error);
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

  formatTime(seconds) {
    if (!seconds || isNaN(seconds)) return '0:00';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (h > 0) return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    return `${m}:${s.toString().padStart(2, '0')}`;
  },

  setSpeed(speed) {
    this.audio.playbackRate = speed;
    this.speedSelect.value = speed;
  },

  destroy() {
    if (this.saveInterval) clearInterval(this.saveInterval);
    this.clearSleepTimer();
    this.savePosition();
  }
};

// Browser Cache API for offline episode storage
const CastDownload = {
  CACHE_NAME: 'cast-audio',
  downloading: new Set(),

  async init() {
    // Populate downloaded set from cache keys
    try {
      const cache = await caches.open(this.CACHE_NAME);
      const keys = await cache.keys();
      App.downloadedEpisodes = new Set(keys.map(r => r.url));
    } catch (e) { /* Cache API not available */ }
  },

  async download(url, onProgress) {
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
    try {
      const cache = await caches.open(this.CACHE_NAME);
      const match = await cache.match(url);
      return !!match;
    } catch (e) { return false; }
  },

  async getUrl(originalUrl) {
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
    try {
      const cache = await caches.open(this.CACHE_NAME);
      await cache.delete(url);
      App.downloadedEpisodes.delete(url);
    } catch (e) { /* ignore */ }
  }
};
