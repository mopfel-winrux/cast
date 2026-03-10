# Cast

A podcast player for Urbit. Subscribe to RSS feeds and YouTube channels, manage episodes, track playback progress, and listen — all from your ship.

## Features

- **Subscribe** to any podcast via RSS/Atom feed URL
- **YouTube feed support** — subscribe to YouTube channels via Atom feed
- **Playback tracking** — position, played/unplayed, history
- **Queue management** — reorder, add, remove episodes
- **Adjustable playback speed**
- **Auto-refresh** feeds on a configurable interval
- **OPML import** — bulk-subscribe from an export of another podcast app
- **Episode filtering** — archive episodes, mark all played/unplayed
- **S3 upload** — upload audio files via your ship's S3 credentials

## Installation

From your ship's dojo:

```
|install ~nattyv %cast
```

Then visit `http://your-ship-url/apps/cast` in your browser.

### From source

```bash
# Clone the repo
git clone https://github.com/your-org/cast.git
cd cast

# Copy desk files to your fakeship's mounted desk
cp -r desk/* zod/cast/

# In the dojo
|commit %cast
|install our %cast
```

## Development

### Directory layout

```
cast/
├── desk/              # Source of truth for the desk
│   ├── app/
│   │   ├── cast.hoon          # Core agent (API, state, RSS/Atom)
│   │   └── cast-fileserver.hoon  # Serves frontend files
│   ├── sur/cast.hoon           # Type definitions
│   ├── lib/rss.hoon            # RSS 2.0 + Atom feed parser
│   ├── mar/                    # Mark files (JSON conversion)
│   ├── www/                    # Static frontend (HTML/CSS/JS)
│   └── ...
├── zod/cast/          # Mounted desk (copy target)
└── README.md
```

### Build cycle

```bash
# 1. Edit files in desk/
# 2. Copy to mounted desk
cp -r desk/* zod/cast/
# 3. Commit in dojo
|commit %cast
# 4. Install (if agents changed)
|install our %cast
```

## Architecture

**Agents:**
- `%cast` — core logic. Handles subscriptions, RSS/Atom fetching (via Iris), state management, and exposes a JSON API at `/apps/cast/api`.
- `%cast-fileserver` — serves the static frontend from `/www/` in Clay.

**Feed parsing:**
- RSS 2.0 feeds (`<channel>/<item>`) parsed via standard XML elements
- Atom feeds (`<feed>/<entry>`) supported for YouTube and other Atom sources
- XML parsed with `de-xml:html` from zuse

**Frontend:**
- Vanilla HTML/CSS/JS served as static files
- Streams audio directly from source URLs via HTML5 `<audio>`
- Communicates with `%cast` agent via JSON pokes and scries

## YouTube feeds

Subscribe to a YouTube channel by using its Atom feed URL:

```
https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID
```

To find a channel's ID, visit the channel page and look in the URL or page source for the `channel_id` parameter.

Episodes will appear with video titles, thumbnails, and publication dates. The "audio URL" will be the YouTube watch link — playback uses whatever your browser supports.

## License

MIT
