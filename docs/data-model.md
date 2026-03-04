# Cast Data Model

## Core Types (sur/cast.hoon)

### Identifiers
- `podcast-id` — `@uv` hash of feed URL
- `episode-id` — `@uv` hash of guid

### podcast
Podcast channel metadata from RSS feed:
- `feed-url=@t` — RSS feed URL
- `title=@t`, `author=@t`, `description=@t`
- `image-url=@t` — artwork URL
- `link=@t` — podcast website
- `last-fetched=@da`

### episode
Single episode from RSS item:
- `title=@t`, `description=@t`
- `audio-url=@t` — remote stream URL
- `pub-date=@da`, `duration=@ud` (seconds)
- `guid=@t` — RSS guid
- `image-url=@t` — episode-specific artwork

### episode-state
Per-episode user state:
- `played=?` — fully played
- `position=@ud` — playback position (seconds)
- `downloaded=?` — cached locally

### queue
`(list [=podcast-id =episode-id])` — ordered playback queue

### settings
- `playback-speed=@ud` — 100 = 1.0x
- `auto-download=?`
- `refresh-interval=@dr`

## Agent State (state-0)
- `podcasts=(map podcast-id podcast)`
- `episodes=(map podcast-id (map episode-id episode))`
- `estate=(map episode-id episode-state)`
- `queue`
- `settings`
- `cache=(map episode-id octs)` — downloaded audio
- `current=(unit [=podcast-id =episode-id])` — now-playing

## Actions (cast-action)
Tagged union: `%subscribe`, `%unsubscribe`, `%refresh`, `%set-position`,
`%set-played`, `%enqueue`, `%dequeue`, `%set-current`, `%download`,
`%set-settings`, `%import-opml`

## Updates (cast-update)
Tagged union: `%podcast-added`, `%podcast-removed`, `%episodes-updated`,
`%position-updated`, `%queue-updated`, `%settings-updated`, `%current-updated`
