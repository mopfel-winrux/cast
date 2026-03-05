# Cast Milestone — 2026-03-05

## Phase 3 Complete: Advanced Features + Reactive Updates

### What shipped

**Reactive UI updates** — The frontend now auto-refreshes the current view after any poke succeeds. A `cast-state-changed` CustomEvent fires from `CastAPI.poke()`, triggering `refreshCurrentView()` with 500ms debounce and 2s dedup to prevent double-renders. Smart polling replaces fixed delays for subscribe/refresh/refresh-all flows (polls until data changes rather than waiting a fixed timeout).

**Download tracking fix** — `visibilitychange` listener re-scans Cache API keys when the tab becomes visible, rebuilding the `downloadedEpisodes` set. Cache API usage is guarded with `cacheAvailable` flag; download buttons are hidden when unavailable.

**Cross-device playback resume** — Enhanced `/player` scry returns position, episode title, podcast title, and image URL. On init, the frontend fetches `/api/player` and shows a resume banner on the home page if an episode was playing. While paused, polls `/api/player` every 30s and updates local position if another device changed it.

**Episode notes & bookmarks** — Per-episode notes stored in `(map episode-id @t)`, bookmarks in `(map episode-id (list [position=@ud label=@t]))`. Episode detail page shows a "My Notes" textarea with 1s auto-save debounce and a bookmarks list (click to seek, X to delete). Player bar has a bookmark button that captures the current position.

**Chapters support** — RSS parser extracts Podlove Simple Chapters (`psc:chapters`/`psc:chapter` elements). `parse-chapter-time` handles HH:MM:SS, HH:MM:SS.mmm, MM:SS, and plain seconds. Player shows a collapsible chapter list, highlights the current chapter, click to seek. Current chapter title appears as subtitle in the player bar.

**Listening statistics** — `savePosition()` logs 15s of listen time per interval. `onEnded()` logs a completion. Stats page shows total hours, episodes completed, and a per-podcast CSS bar chart (no external libraries). New `/stats` scry endpoint returns aggregated data sorted by listen time desc.

### State changes

Migrated from `state-2` to `state-3`. Key additions:

| Field | Type | Purpose |
|-------|------|---------|
| `notes` | `(map episode-id @t)` | Per-episode user notes |
| `bookmarks` | `(map episode-id (list [position=@ud label=@t]))` | Timestamped bookmarks |
| `listen-time` | `(map podcast-id @ud)` | Cumulative seconds listened |
| `completed-count` | `(map podcast-id @ud)` | Episodes finished |

Episode type gained `chapters=(list [start=@ud title=@t])`. Old states use `episode-0` (7-field) type, with `upgrade-episodes` converting to 8-field `episode` on migration.

5 new actions: `%set-note`, `%add-bookmark`, `%remove-bookmark`, `%log-listen`, `%log-complete`.

### Codebase stats

| File | Lines |
|------|-------|
| `sur/cast.hoon` | 180 |
| `app/cast.hoon` | 1,251 |
| `lib/rss.hoon` | 542 |
| `mar/cast-action.hoon` | 138 |
| `www/js/app.js` | 1,322 |
| `www/js/api.js` | 166 |
| `www/js/player.js` | 644 |
| `www/css/app.css` | 1,221 |
| `www/index.html` | 185 |
| **Total** | **~5,650** |

### API surface

14 scry endpoints, 23 poke actions, SSE subscription for live updates.

New endpoints:
- `GET /stats` — listening stats with per-podcast breakdown
- `GET /player` — enhanced with position, titles, image
- `GET /podcast/{id}` — enhanced with notes, bookmarks, chapters per episode

---

## Feature completion status

### Done

| Feature | Tier | Notes |
|---------|------|-------|
| Subscribe/unsubscribe via RSS URL | 0 | |
| List podcasts + episodes | 0 | Grid with artwork |
| Stream audio playback | 0 | HTML5 audio |
| Position tracking + resume | 1 | Saves every 15s |
| Playback queue | 1 | Reorder support |
| Playback speed (global + per-podcast) | 1 | 0.5x–3x |
| Auto-refresh feeds on timer | 1 | Behn-based |
| Podcast artwork | 1 | |
| Episode download (browser cache) | 2 | Cache API |
| Search/filter within podcast | 2 | Title search |
| OPML import/export | 2 | File upload + URL list |
| Mark played/unplayed (single + bulk) | 2 | |
| Archive/unarchive episodes | 2 | |
| Sort episodes (newest/oldest) | 2 | |
| Feed error display | 2 | Per-feed error map |
| S3 audio upload | 2 | Presigned URL, AWS Sig V4 |
| Atom/YouTube feed support | 2 | |
| RSS redirect following (301/302/307/308) | 2 | |
| Feed hash caching | 2 | Skip re-parse if unchanged |
| Non-ASCII / XML sanitization | 2 | |
| PWA (manifest + service worker + icons) | 2 | iOS tested, Android needs verification |
| Dark/light theme | 2 | CSS file swap |
| Episode notes | 3 | Auto-save textarea |
| Episode bookmarks | 3 | Position + label, seek on click |
| Chapters (Podlove Simple Chapters) | 3 | Parse + UI + seek |
| Listening statistics | 3 | Time + completions + bar chart |
| Cross-device playback resume | 3 | Poll-based sync |
| Reactive UI updates | 3 | Event-driven + smart polling |
| Download tracking re-sync | 3 | visibilitychange listener |
| Sleep timer | 2 | 15/30/45/60/90 min |
| Podcast reordering | 2 | Drag or manual |
| History page | 2 | Timestamped playback log |

### Remaining

| Feature | Tier | Effort | Notes |
|---------|------|--------|-------|
| HTTP caching headers on fileserver | 2 | Small | Add Cache-Control / ETag to cast-ui responses |
| Podcast search/discovery | 3 | Medium | Real search API (iTunes Search API or similar) |
| Per-podcast auto-download / notification prefs | 3 | Medium | Per-podcast settings map |
| Sharing (episodes/podcasts to other ships) | 3 | Large | Poke remote ships, receive shared items |
| Cross-ship subscription sync | 3 | Large | Mirror subscription list between ships |
| New episode notifications | 3 | Medium | Hark integration for push notifications |
| Playlist support | 3 | Medium | Named playlists beyond the single queue |
| Queue drag-to-reorder (touch) | 2 | Small | Touch events for mobile reorder |

### Next steps

The highest-value remaining items:
1. **HTTP caching headers** — quick win, reduces bandwidth on repeat loads
2. **Podcast discovery** — iTunes Search API integration for finding podcasts by name
3. **New episode notifications** — Hark integration so users know when feeds update
4. **Queue touch reorder** — improves mobile UX significantly
5. **Cross-ship sharing** — the uniquely Urbit-native feature (share episodes/podcasts with other ships)
