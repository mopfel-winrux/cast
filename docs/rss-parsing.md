# RSS Parsing Strategy

## Approach
Use `de-xml:html` from zuse to parse RSS XML into manx tree, then extract structured data.

## RSS 2.0 Structure
```xml
<rss><channel>
  <title>...</title>
  <description>...</description>
  <link>...</link>
  <itunes:image href="..."/>
  <itunes:author>...</itunes:author>
  <item>
    <title>...</title>
    <description>...</description>
    <enclosure url="..." type="audio/mpeg" length="..."/>
    <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
    <itunes:duration>3600</itunes:duration>
    <guid>...</guid>
    <itunes:image href="..."/>
  </item>
</channel></rss>
```

## Implementation (lib/rss.hoon)
1. `de-xml:html` parses XML cord into `(unit manx)`
2. Walk manx tree to find `<channel>` element
3. Extract channel metadata (title, description, link, image, author)
4. Find all `<item>` children
5. For each item: extract title, description, enclosure url, pubDate, duration, guid
6. Parse pubDate (RFC 2822) into `@da`
7. Parse duration (seconds or HH:MM:SS) into `@ud`
8. Return `[podcast (list episode)]`

## Date Parsing
RFC 2822: `"Mon, 01 Jan 2024 00:00:00 GMT"`
- Parse with custom rule or simplified parser
- Map month names to numbers
- Convert to `@da`

## Duration Parsing
- Seconds: `"3600"` → 3.600
- HH:MM:SS: `"1:00:00"` → 3.600
- MM:SS: `"45:30"` → 2.730
