// Cast Audio Player Controller

const Player = {
  audio: null,
  currentEpisode: null,
  currentPodcast: null,
  saveInterval: null,

  init() {
    this.audio = document.getElementById('audio-element');
    this.bar = document.getElementById('player-bar');
    this.playPauseBtn = document.getElementById('play-pause');
    this.seekBar = document.getElementById('seek-bar');
    this.currentTimeEl = document.getElementById('current-time');
    this.totalTimeEl = document.getElementById('total-time');
    this.speedSelect = document.getElementById('player-speed');

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

    this.audio.addEventListener('timeupdate', () => this.updateProgress());
    this.audio.addEventListener('ended', () => this.onEnded());
    this.audio.addEventListener('loadedmetadata', () => {
      this.totalTimeEl.textContent = this.formatTime(this.audio.duration);
    });
  },

  play(episode, podcast) {
    this.currentEpisode = episode;
    this.currentPodcast = podcast;

    this.audio.src = episode['audio-url'];

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

  async onEnded() {
    this.savePosition();
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
    this.savePosition();
  }
};
