# Milestone: 2026-03-04

## Summary

Cast has reached a mature MVP state. All core podcast player features are implemented and working. This session focused on RSS parsing robustness, PWA support, UI polish, and performance optimization.

## What Was Done This Session

### RSS/XML Parsing Fixes
- **Non-ASCII byte stripping**: `de-xml:html` only handles bytes 32-126. Added `sanitize-xml` to strip bytes >127, carriage returns, and convert tabs to spaces.
- **Processing instruction stripping**: `<?xml-stylesheet?>` broke `de-xml:html`'s `decl` parser. Added `strip-pis` helper.
- **Hyphenated tag names**: `de-xml:html` doesn't support hyphens in tag names (`itunes:new-feed-url` parsed as `itunes:new`). Added `fix-tag-hyphens` state machine that replaces hyphens with underscores in tag/attribute names while preserving content in text, attribute values, and CDATA.
- **Trailing whitespace before `>`**: `<foo bar="x" >` broke `de-xml:html`. Fixed in `fix-tag-hyphens` by stripping spaces before `>` in tags.
- **HTTP redirect following**: Iris doesn't follow 301/302/307/308 redirects. Added redirect handling that extracts the `Location` header and issues a new request.

### OPML Import Results (16 feeds tested)
- 13 feeds subscribed successfully (including 2 via redirect following)
- 2 dead URLs (404)
- 1 server timeout (504)

### S3 Upload
- Rewrote from Authorization header approach to presigned URL approach (matching Tlon app pattern)
- Uses AWS Signature V4 with Web Crypto API
- Confirmed working

### PWA Support
- Created `manifest.json` with app metadata, PNG icons (192x192, 512x512), and SVG icon
- Created `sw.js` service worker with stale-while-revalidate caching for app shell
- Added iOS meta tags (apple-mobile-web-app-capable, status-bar-style)
- Added safe area insets for notch phones
- **Fixed unauthenticated access for PWA files**: The browser fetches manifest.json, sw.js, and icons without cookies. Modified `cast-fileserver.hoon` to whitelist these 5 paths from the auth check. All PWA files now return 200 without auth.

### UI Improvements
- **Sort toggle**: "Newest" / "Oldest" button on episode list, sorts by pub-date
- **Upload icon**: SVG microphone icon for the Uploads podcast tile (fallback for empty image-url)
- **Dark/Light theme**: Two CSS files (`app.css` dark, `app-light.css` light), toggle in Settings, persists via localStorage
- **Unplayed badge fix**: Was showing 0 for all podcasts due to Hoon nested closure issue with `estate` map access. Fixed by pre-computing a `played-set` outside the inner gate.

### Performance
- **Feed hash caching**: Hash raw XML body with `sham`, store in `feed-hashes` map per podcast. Skip all parsing/sanitization on refresh if hash unchanged. Required state migration (state-0 → state-1).

## Current Feature Set

### Complete
- Subscribe/unsubscribe/refresh feeds
- RSS 2.0 + Atom feed parsing (YouTube channels work)
- Episode playback with position tracking (saves every 15s)
- Playback speed (0.5x - 3x)
- Sleep timer
- Queue management
- Episode filters (all, unplayed, in-progress, downloaded, archived)
- Episode search (debounced)
- Bulk operations (mark all played/unplayed, archive/unarchive all)
- OPML import/export
- S3 audio upload with presigned URLs
- Listening history (grouped by date)
- Auto-refresh feeds on timer
- Browser cache for offline playback
- Auto-play next episode
- Dark/Light theme
- Responsive mobile layout
- Discover page (44 curated podcasts)
- Feed hash caching (skip re-parsing unchanged feeds)
- Unplayed episode badges on podcast cards

## Architecture

- **State version**: `state-1` (with `feed-hashes`)
- **Agents**: `%cast` (core + API), `%cast-fileserver` (static files)
- **Kelvin**: `[%zuse 409]`
- **Tests**: 15 passing (10 RSS parser + 5 XML edge cases)

## Possible Next Steps

### High Priority
1. **~~Investigate PWA on Android~~** — FIXED. Root cause was `cast-fileserver` requiring auth for all files. Browser fetches PWA files (manifest, SW, icons) without cookies. Added whitelist for PWA paths. Verify install prompt now works on Android.
2. **Queue drag-to-reorder** — CSS classes exist but JS drag handlers aren't implemented. Users can only add/remove from queue, not reorder.
3. **Episode download tracking** — Browser Cache API state can get out of sync with the UI's `downloadedEpisodes` set (e.g., after clearing browser data).

### Medium Priority
4. **Atom feed support for non-YouTube feeds** — The Atom parser (`parse-atom-feed`) was designed for YouTube but could handle any Atom feed. Needs testing with generic Atom feeds.
5. **HTTP caching headers on fileserver** — `cast-fileserver` doesn't set Cache-Control headers. Adding them would improve load performance.
6. **Podcast search/discovery** — The discover page is hardcoded. Could add a search-by-URL or integrate a podcast directory API.
7. **Per-podcast settings** — Custom refresh interval, auto-download, notification preferences per feed.
8. **Mark older episodes as played** — "Mark all before date as played" or "Mark all older than X as played" bulk action.

### Low Priority / Nice-to-Have
9. **Playback resume across devices** — Position is stored on the ship but the frontend doesn't poll for external position changes.
10. **Episode notes/bookmarks** — Let users annotate episodes with timestamped notes.
11. **Sharing** — Share episodes or podcast links with other ships.
12. **Chapters support** — Parse podcast chapter markers from RSS (if present) and display in player.
13. **Variable playback speed per podcast** — Some podcasts are better at 1x, others at 2x.
14. **Feed error reporting in UI** — Show which feeds failed to fetch/parse in the UI, not just dojo logs.
15. **Keyboard shortcuts** — Space for play/pause, arrow keys for seek, etc.
16. **Playlist support** — Named playlists beyond the single queue.
