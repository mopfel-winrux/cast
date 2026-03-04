# Cast JSON API

## Base URL
`/apps/cast/api`

## Scry Endpoints (GET)

### GET /apps/cast/api/podcasts
All subscribed podcasts.
```json
{"podcasts": [{"id": "0v...", "title": "...", "author": "...", "image-url": "...", ...}]}
```

### GET /apps/cast/api/podcast/{id}
Single podcast with episodes.
```json
{"podcast": {...}, "episodes": [{...}]}
```

### GET /apps/cast/api/episodes/{podcast-id}
Episodes for a podcast.
```json
{"episodes": [{"id": "0v...", "title": "...", "audio-url": "...", ...}]}
```

### GET /apps/cast/api/queue
Current playback queue.
```json
{"queue": [{"podcast-id": "0v...", "episode-id": "0v..."}]}
```

### GET /apps/cast/api/player
Current playback state.
```json
{"current": {"podcast-id": "0v...", "episode-id": "0v..."}, "position": 120}
```

### GET /apps/cast/api/settings
User settings.
```json
{"playback-speed": 100, "auto-download": false, "refresh-interval": 3600}
```

## Poke Actions (POST /apps/cast/api)

### Subscribe
```json
{"action": "subscribe", "url": "https://example.com/feed.xml"}
```

### Unsubscribe
```json
{"action": "unsubscribe", "podcast-id": "0v..."}
```

### Refresh
```json
{"action": "refresh", "podcast-id": "0v..."}
```
Omit podcast-id to refresh all.

### Set Position
```json
{"action": "set-position", "episode-id": "0v...", "position": 120}
```

### Set Played
```json
{"action": "set-played", "episode-id": "0v...", "played": true}
```

### Enqueue
```json
{"action": "enqueue", "podcast-id": "0v...", "episode-id": "0v..."}
```

### Dequeue
```json
{"action": "dequeue", "podcast-id": "0v...", "episode-id": "0v..."}
```

### Set Current
```json
{"action": "set-current", "podcast-id": "0v...", "episode-id": "0v..."}
```

### Set Settings
```json
{"action": "set-settings", "playback-speed": 150, "auto-download": true, "refresh-interval": 7200}
```

## SSE Updates (EventSource /apps/cast/api/updates)
Real-time push for state changes. Each event is a JSON object with `type` field.
