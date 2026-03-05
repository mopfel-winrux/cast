::  rss: RSS 2.0 + Atom feed parser
::
::  parses RSS XML and Atom XML into podcast metadata and episode list
::  supports YouTube Atom feeds (yt: and media: namespaces)
::  uses de-xml:html from zuse
::
/-  cast
|%
::  +parse-feed: parse RSS feed XML into podcast + episodes
::
::    takes feed-url and raw XML cord, returns podcast and episode list
::
++  parse-feed
  |=  [url=@t xml=@t]
  ^-  (unit [=podcast:cast eps=(list [episode-id:cast episode:cast])])
  %-  (slog leaf+"rss: sanitizing xml ({(a-co:co (met 3 xml))} bytes)" ~)
  =/  clean=@t  (sanitize-xml xml)
  %-  (slog leaf+"rss: sanitized ({(a-co:co (met 3 clean))} bytes), running de-xml" ~)
  =/  parsed=(unit manx)  (de-xml:html clean)
  ?~  parsed
    %-  (slog leaf+"rss: de-xml failed for {(trip url)}" ~)
    ~
  %-  (slog leaf+"rss: de-xml succeeded, finding channel" ~)
  =/  channel=(unit manx)  (find-tag 'channel' c.u.parsed)
  ?~  channel
    (parse-atom-feed url u.parsed)
  =/  pod=podcast:cast
    :*  feed-url=url
        title=(get-text 'title' c.u.channel)
        author=(fall (get-attr-text 'itunes:image' 'href' c.u.channel) (get-text 'itunes:author' c.u.channel))
        ::  NOTE: author gets itunes:author, image-url gets itunes:image href
        description=(get-text 'description' c.u.channel)
        image-url=(fall (get-itunes-image c.u.channel) (get-text-from-path ~['image' 'url'] c.u.channel))
        link=(get-text 'link' c.u.channel)
        last-fetched=*@da
    ==
  ::  fix: author should be itunes:author, not the image href
  =.  author.pod  (get-text 'itunes:author' c.u.channel)
  =/  items=(list manx)  (find-tags 'item' c.u.channel)
  =/  eps=(list [episode-id:cast episode:cast])
    %+  turn  items
    |=  item=manx
    ^-  [episode-id:cast episode:cast]
    =/  guid=@t  (get-text 'guid' c.item)
    =/  chaps=(list [start=@ud title=@t])
      (parse-chapters c.item)
    =/  ep=episode:cast
      :*  title=(get-text 'title' c.item)
          description=(get-text 'description' c.item)
          audio-url=(fall (get-enclosure-url c.item) '')
          pub-date=(fall (parse-rfc2822 (get-text 'pubDate' c.item)) *@da)
          duration=(fall (parse-duration (get-text 'itunes:duration' c.item)) 0)
          guid=guid
          image-url=(fall (get-itunes-image c.item) '')
          chapters=chaps
      ==
    =/  eid=episode-id:cast  (sham guid)
    [eid ep]
  `[pod eps]
::
::  +find-tag: find first child element with given tag name
::
++  find-tag
  |=  [tag=@t children=marl]
  ^-  (unit manx)
  ?~  children  ~
  ?:  (match-tag tag i.children)
    `i.children
  $(children t.children)
::
::  +find-tags: find all child elements with given tag name
::
++  find-tags
  |=  [tag=@t children=marl]
  ^-  (list manx)
  %+  murn  children
  |=  child=manx
  ^-  (unit manx)
  ?:  (match-tag tag child)
    `child
  ~
::
::  +match-tag: check if manx has the given tag name
::
::    handles both simple names and namespaced names (e.g. itunes:image)
::
++  match-tag
  |=  [tag=@t =manx]
  ^-  ?
  ?@  n.g.manx
    =(tag n.g.manx)
  ::  namespaced tag: n.g.manx is [ns name]
  =(tag (crip "{(trip -.n.g.manx)}:{(trip +.n.g.manx)}"))
::
::  +get-text: get text content of first child with tag name
::
++  get-text
  |=  [tag=@t children=marl]
  ^-  @t
  =/  node=(unit manx)  (find-tag tag children)
  ?~  node  ''
  (get-inner-text u.node)
::
::  +get-inner-text: extract text content from a manx node
::
++  get-inner-text
  |=  =manx
  ^-  @t
  %-  crip
  %-  zing
  %+  turn  c.manx
  |=  child=^manx
  ^-  tape
  ?.  ?=([%$ [[%$ *] ~]] g.child)
    ~
  v.i.a.g.child
::
::  +get-attr-text: get attribute value from first matching tag
::
++  get-attr-text
  |=  [tag=@t attr-name=@t children=marl]
  ^-  (unit @t)
  =/  node=(unit manx)  (find-tag tag children)
  ?~  node  ~
  (get-attr attr-name a.g.u.node)
::
::  +get-attr: get attribute value from mart (attribute list)
::
++  get-attr
  |=  [attr-name=@t attrs=mart]
  ^-  (unit @t)
  ?~  attrs  ~
  ?:  =(attr-name (mane-to-cord n.i.attrs))
    `(crip v.i.attrs)
  $(attrs t.attrs)
::
::  +mane-to-cord: convert mane (tag/attr name) to cord
::
++  mane-to-cord
  |=  =mane
  ^-  @t
  ?@  mane  mane
  (crip "{(trip -.mane)}:{(trip +.mane)}")
::
::  +get-itunes-image: get itunes:image href attribute
::
++  get-itunes-image
  |=  children=marl
  ^-  (unit @t)
  (get-attr-text 'itunes:image' 'href' children)
::
::  +get-enclosure-url: get url attribute from enclosure tag
::
++  get-enclosure-url
  |=  children=marl
  ^-  (unit @t)
  (get-attr-text 'enclosure' 'url' children)
::
::  +get-text-from-path: navigate nested tags to get text
::
::    e.g. ~['image' 'url'] gets <image><url>text</url></image>
::
++  get-text-from-path
  |=  [tags=(list @t) children=marl]
  ^-  @t
  ?~  tags  ''
  ?~  t.tags
    (get-text i.tags children)
  =/  node=(unit manx)  (find-tag i.tags children)
  ?~  node  ''
  $(tags t.tags, children c.u.node)
::
::  +digits: parse one or more decimal digits, allowing leading zeros
::
::    dim:ag rejects leading zeros (e.g. "03" fails).
::    this parser accepts them, needed for zero-padded date fields.
::
++  digits
  %+  cook
    |=  a=(list @)
    %+  roll  a
    |=([i=@ a=@] (add (mul a 10) i))
  (plus sid:ab)
::
::  +parse-rfc2822: parse RFC 2822 date string to @da
::
::    format: "Mon, 01 Jan 2024 00:00:00 GMT"
::    or: "01 Jan 2024 00:00:00 GMT"
::    simplified: extracts day, month, year, hour, min, sec
::
++  parse-rfc2822
  |=  dat=@t
  ^-  (unit @da)
  =/  t=tape  (trip dat)
  ::  skip day-of-week if present (e.g. "Mon, ")
  =/  t=tape
    =/  comma  (find "," t)
    ?~  comma  t
    (slag +(+(u.comma)) t)
  ::  trim leading whitespace
  =.  t
    |-
    ?~  t  t
    ?:  =(' ' i.t)
      $(t t.t)
    t
  ::  parse: DD Mon YYYY HH:MM:SS
  =/  parsed
    %+  rust  t
    ;~  sfix
      ;~  plug
        digits
        ;~(pfix ace mon-to-num)
        ;~(pfix ace digits)
        ;~(pfix ace digits)
        ;~(pfix col digits)
        ;~(pfix col digits)
      ==
      (star next)
    ==
  ?~  parsed  ~
  =/  [dy=@ud mn=@ud yr=@ud hr=@ud mi=@ud sc=@ud]
    u.parsed
  `(year [[%.y yr] mn [dy hr mi sc ~]])
::
::  +mon-to-num: parse 3-letter month name to number
::
++  mon-to-num
  ;~  pose
    (cold 1 (jest 'Jan'))
    (cold 2 (jest 'Feb'))
    (cold 3 (jest 'Mar'))
    (cold 4 (jest 'Apr'))
    (cold 5 (jest 'May'))
    (cold 6 (jest 'Jun'))
    (cold 7 (jest 'Jul'))
    (cold 8 (jest 'Aug'))
    (cold 9 (jest 'Sep'))
    (cold 10 (jest 'Oct'))
    (cold 11 (jest 'Nov'))
    (cold 12 (jest 'Dec'))
  ==
::
::  +parse-duration: parse iTunes duration to seconds
::
::    handles: "3600" (seconds), "1:00:00" (h:m:s), "45:30" (m:s)
::
++  parse-duration
  |=  dur=@t
  ^-  (unit @ud)
  ?:  =('' dur)  ~
  =/  t=tape  (trip dur)
  =/  colons=(list @ud)
    %+  murn  (gulf 0 (dec (lent t)))
    |=  i=@ud
    ^-  (unit @ud)
    ?:  =(':' (snag i t))
      `i
    ~
  ?~  colons
    ::  plain seconds
    (rush dur digits)
  ?~  t.colons
    ::  mm:ss
    =/  parsed  (rust t ;~(plug digits ;~(pfix col digits)))
    ?~  parsed  ~
    =/  [m=@ud s=@ud]  u.parsed
    `(add (mul m 60) s)
  ::  hh:mm:ss
  =/  parsed  (rust t ;~(plug digits ;~(pfix col digits) ;~(pfix col digits)))
  ?~  parsed  ~
  =/  [h=@ud m=@ud s=@ud]  u.parsed
  `:(add (mul h 3.600) (mul m 60) s)
::
::  +parse-atom-feed: parse Atom XML feed (e.g. YouTube) into podcast + episodes
::
::    maps Atom <feed>/<entry> structure to Cast podcast/episode types
::
++  parse-atom-feed
  |=  [url=@t feed=manx]
  ^-  (unit [=podcast:cast eps=(list [episode-id:cast episode:cast])])
  =/  kids=marl  c.feed
  =/  pod=podcast:cast
    :*  feed-url=url
        title=(get-text 'title' kids)
        author=(get-text-from-path ~['author' 'name'] kids)
        description=''
        image-url=''
        link=(fall (get-link-href 'alternate' kids) '')
        last-fetched=*@da
    ==
  =/  entries=(list manx)  (find-tags 'entry' kids)
  =/  eps=(list [episode-id:cast episode:cast])
    %+  turn  entries
    |=  entry=manx
    ^-  [episode-id:cast episode:cast]
    =/  guid=@t  (get-text 'yt:videoId' c.entry)
    =/  ep=episode:cast
      :*  title=(get-text 'title' c.entry)
          description=(get-text-from-path ~['media:group' 'media:description'] c.entry)
          audio-url=(fall (get-link-href 'alternate' c.entry) '')
          pub-date=(fall (parse-iso8601 (get-text 'published' c.entry)) *@da)
          duration=0
          guid=guid
          image-url=(fall (get-attr-text 'media:thumbnail' 'url' (find-media-group c.entry)) '')
          chapters=~
      ==
    =/  eid=episode-id:cast  (sham guid)
    [eid ep]
  ::  use first episode thumbnail as podcast image if none set
  =/  pod-img=@t
    ?~  eps  ''
    image-url:+.i.eps
  =.  image-url.pod  pod-img
  `[pod eps]
::
::  +find-media-group: get children of media:group element
::
++  find-media-group
  |=  children=marl
  ^-  marl
  =/  mg=(unit manx)  (find-tag 'media:group' children)
  ?~  mg  ~
  c.u.mg
::
::  +get-link-href: get href attribute from <link> with matching rel
::
::    Atom <link> elements are self-closing with rel and href attributes.
::    finds first <link rel=rel-val> and returns its href.
::
++  get-link-href
  |=  [rel-val=@t children=marl]
  ^-  (unit @t)
  ?~  children  ~
  ?.  (match-tag 'link' i.children)
    $(children t.children)
  =/  rel=(unit @t)  (get-attr 'rel' a.g.i.children)
  ?~  rel  $(children t.children)
  ?.  =(rel-val u.rel)
    $(children t.children)
  (get-attr 'href' a.g.i.children)
::
::  +parse-iso8601: parse ISO 8601 date string to @da
::
::    format: "2026-03-04T18:00:48+00:00"
::    parses YYYY-MM-DDTHH:MM:SS, ignores timezone suffix (treats as UTC)
::
++  parse-iso8601
  |=  dat=@t
  ^-  (unit @da)
  ?:  =('' dat)  ~
  =/  t=tape  (trip dat)
  =/  parsed
    %+  rust  t
    ;~  sfix
      ;~  plug
        digits                       ::  year
        ;~(pfix hep digits)          ::  month
        ;~(pfix hep digits)          ::  day
        ;~(pfix (jest 'T') digits)   ::  hour
        ;~(pfix col digits)          ::  minute
        ;~(pfix col digits)          ::  second
      ==
      (star next)                    ::  ignore timezone
    ==
  ?~  parsed  ~
  =/  [yr=@ud mn=@ud dy=@ud hr=@ud mi=@ud sc=@ud]
    u.parsed
  `(year [[%.y yr] mn [dy hr mi sc ~]])
::
::  +sanitize-xml: strip non-ASCII bytes for de-xml:html compatibility
::
::    de-xml:html uses +prn which only matches bytes 32-126.
::    non-ASCII UTF-8 bytes (>127) and \r (13) cause parse failure.
::    strips these bytes so the XML structure remains parseable.
::
++  sanitize-xml
  |=  xml=@t
  ^-  @t
  =/  in=tape  (trip xml)
  ::  step 1: strip non-xml-safe bytes
  =/  clean=tape
    %+  murn  in
    |=  c=@
    ^-  (unit @)
    ?:  (gth c 127)  ~       ::  strip non-ASCII
    ?:  =(`@`13 c)   ~       ::  strip \r
    ?:  =(`@`9 c)    `' '    ::  tab -> space
    `c
  ::  step 2: strip processing instructions (<?...?>)
  =/  no-pis=tape  (strip-pis clean)
  ::  step 3: replace hyphens in tag names with underscores
  ::  de-xml:html's +name only accepts [_a-zA-Z][_.a-zA-Z0-9]*
  ::  so tags like <itunes:new-feed-url> break the parser.
  ::  also strips trailing whitespace before > in tags, since
  ::  de-xml:html's +attr consumes the space then fails on >.
  (crip (fix-tag-hyphens no-pis))
::
++  strip-pis
  |=  in=tape
  ^-  tape
  ?~  in  ~
  ?.  =('<' i.in)
    [i.in $(in t.in)]
  ?~  t.in  [i.in ~]
  ?.  =('?' i.t.in)
    [i.in $(in t.in)]
  ::  found <? — skip until ?>
  $(in (skip-to-pi-end t.t.in))
::
++  skip-to-pi-end
  |=  in=tape
  ^-  tape
  ?~  in  ~
  ?.  =('?' i.in)  $(in t.in)
  ?~  t.in  ~
  ?.  =('>' i.t.in)  $(in t.in)
  t.t.in
::
::  +fix-tag-hyphens: replace - with _ in XML tag names
::
::    walks through the tape tracking state to only modify
::    hyphens inside tag names and attribute names, not in
::    text content, attribute values, or CDATA sections.
::
++  fix-tag-hyphens
  |=  in=tape
  ^-  tape
  ::  state: 0=text 1=cdata 2=tag-name 3=tag-body 4=dquote 5=squote 6=comment
  =/  s=@ud  0
  |-
  ?~  in  ~
  ?:  =(0 s)  ::  text
    ?.  =('<' i.in)
      [i.in $(in t.in)]
    ::  check for CDATA start: <![
    ?:  ?&  ?=(^ t.in)      =('!' i.t.in)
            ?=(^ t.t.in)    =('[' i.t.t.in)
        ==
      [i.in $(in t.in, s 1)]
    ::  check for comment start: <!-
    ?:  ?&  ?=(^ t.in)      =('!' i.t.in)
            ?=(^ t.t.in)    =('-' i.t.t.in)
        ==
      [i.in $(in t.in, s 6)]
    ::  other <! (DOCTYPE etc): pass through in text mode
    ?:  ?&  ?=(^ t.in)  =('!' i.t.in)  ==
      [i.in $(in t.in)]
    [i.in $(in t.in, s 2)]
  ?:  =(1 s)  ::  cdata — pass through until ]]>
    ?:  ?&  =(']' i.in)
            ?=(^ t.in)  =(']' i.t.in)
            ?=(^ t.t.in)  =('>' i.t.t.in)
        ==
      [']' [']' ['>' $(in t.t.t.in, s 0)]]]
    [i.in $(in t.in)]
  ?:  =(2 s)  ::  tag-name — replace - with _
    ?:  =('>' i.in)  [i.in $(in t.in, s 0)]
    ?:  =(' ' i.in)  [i.in $(in t.in, s 3)]
    ?:  =('-' i.in)  ['_' $(in t.in)]
    [i.in $(in t.in)]
  ?:  =(3 s)  ::  tag-body (attributes)
    ?:  =('>' i.in)    [i.in $(in t.in, s 0)]
    ?:  =('"' i.in)    [i.in $(in t.in, s 4)]
    ?:  =('\'' i.in)   [i.in $(in t.in, s 5)]
    ?:  =('-' i.in)    ['_' $(in t.in)]
    ::  strip whitespace before > to avoid de-xml:html attr parse issue
    ?:  =(' ' i.in)
      =/  rest=tape  t.in
      |-  ^-  tape
      ?~  rest  [' ' ~]
      ?:  =(' ' i.rest)  $(rest t.rest)  ::  skip consecutive spaces
      ?:  =('>' i.rest)  ['>' ^$(in t.rest, s 0)]  ::  drop spaces before >
      [' ' ^$(in rest, s 3)]  ::  not before >, keep one space
    [i.in $(in t.in)]
  ?:  =(4 s)  ::  double-quoted attr value
    ?:  =('"' i.in)    [i.in $(in t.in, s 3)]
    [i.in $(in t.in)]
  ?:  =(5 s)  ::  single-quoted attr value
    ?:  =('\'' i.in)   [i.in $(in t.in, s 3)]
    [i.in $(in t.in)]
  ?:  =(6 s)  ::  comment — pass through until -->
    ?:  ?&  =('-' i.in)
            ?=(^ t.in)  =('-' i.t.in)
            ?=(^ t.t.in)  =('>' i.t.t.in)
        ==
      ['-' ['-' ['>' $(in t.t.t.in, s 0)]]]
    [i.in $(in t.in)]
  [i.in $(in t.in)]
::
::  +parse-chapters: extract Podlove Simple Chapters from item children
::
::    looks for <psc:chapters> containing <psc:chapter start="HH:MM:SS" title="...">
::    also handles the underscore-munged variant psc_chapters / psc_chapter
::    from fix-tag-hyphens (colons are preserved, hyphens become underscores)
::
++  parse-chapters
  |=  children=marl
  ^-  (list [start=@ud title=@t])
  =/  chap-node=(unit manx)
    =/  n=(unit manx)  (find-tag 'psc:chapters' children)
    ?^  n  n
    (find-tag 'psc_chapters' children)
  ?~  chap-node  ~
  =/  items=marl
    =/  a=marl  (find-tags 'psc:chapter' c.u.chap-node)
    ?^  a  a
    (find-tags 'psc_chapter' c.u.chap-node)
  %+  murn  items
  |=  ch=manx
  ^-  (unit [start=@ud title=@t])
  =/  start-attr=(unit @t)  (get-attr 'start' a.g.ch)
  ?~  start-attr  ~
  =/  title-attr=(unit @t)  (get-attr 'title' a.g.ch)
  ?~  title-attr  ~
  =/  start-secs=(unit @ud)  (parse-chapter-time u.start-attr)
  ?~  start-secs  ~
  `[u.start-secs u.title-attr]
::
::  +parse-chapter-time: parse "HH:MM:SS" or "HH:MM:SS.mmm" to seconds
::
++  parse-chapter-time
  |=  t=@t
  ^-  (unit @ud)
  ?:  =('' t)  ~
  =/  tape=tape  (trip t)
  ::  strip milliseconds if present (everything after '.')
  =/  dot  (find "." tape)
  =?  tape  ?=(^ dot)  (scag u.dot tape)
  ::  try HH:MM:SS
  =/  parsed  (rust tape ;~(plug digits ;~(pfix col digits) ;~(pfix col digits)))
  ?^  parsed
    =/  [h=@ud m=@ud s=@ud]  u.parsed
    `:(add (mul h 3.600) (mul m 60) s)
  ::  try MM:SS
  =/  parsed2  (rust tape ;~(plug digits ;~(pfix col digits)))
  ?^  parsed2
    =/  [m=@ud s=@ud]  u.parsed2
    `(add (mul m 60) s)
  ::  try plain seconds
  (rush t digits)
--
