# Cast UI Design

## Layout
Mobile-first responsive SPA. Persistent bottom player bar.

## Pages
1. **Home** — Grid of subscribed podcasts (artwork + title)
2. **Podcast Detail** — Episode list, podcast info, unsubscribe button
3. **Episode Detail** — Description, play/download buttons
4. **Queue** — Reorderable episode list
5. **Settings** — Playback speed, refresh interval, auto-download
6. **Add Podcast** — RSS URL input field

## Navigation
- Bottom tab bar: Home | Queue | Settings
- Podcast grid → tap → Podcast Detail → tap episode → play
- Persistent mini player bar above tab bar

## Player Bar
- Artwork thumbnail, episode title, podcast name
- Play/pause button, progress bar
- Tap to expand: seek bar, speed control, skip ±30s

## Responsive
- Mobile: single column, 2-col podcast grid
- Tablet: 3-col grid, wider player
- Desktop: sidebar nav, 4-col grid, expanded player
