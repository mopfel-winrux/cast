# Cast Architecture

## System Design

Two Gall agents on the `%cast` desk:

### %cast (Core Agent)
- Manages podcast subscriptions, episodes, playback state, queue
- Fetches RSS feeds via Iris HTTP client
- Parses feeds with `lib/rss.hoon`
- Serves JSON API at `/apps/cast/api` via Eyre
- Auto-refreshes feeds on Behn timer
- Optionally downloads episode audio to local state cache

### %cast-ui (Fileserver Agent)
- Serves static frontend files from Clay `/site/` path
- Binds to `/apps/cast` on Eyre
- Detects MIME types for HTML, CSS, JS, images
- Routes `/apps/cast/api/*` requests to %cast agent

## Data Flow

```
Browser ←→ Eyre ←→ %cast-ui (static files)
                 ←→ %cast (JSON API)
                       ↕
                     Iris (RSS feeds, audio downloads)
                     Behn (periodic refresh timer)
```

## API Communication
- **Scry**: `GET /apps/cast/api/podcasts` → JSON
- **Poke**: `POST /apps/cast/api` with `{"action": "subscribe", ...}` → %cast-action mark
- **SSE**: EventSource at `/apps/cast/api/updates` for real-time push

## State
All state in %cast agent:
- `podcasts` — map of subscribed podcast metadata
- `episodes` — map of podcast-id to episode maps
- `estate` — per-episode user state (position, played, downloaded)
- `queue` — ordered playback queue
- `settings` — user preferences
- `cache` — downloaded episode audio as octs
- `current` — now-playing episode
