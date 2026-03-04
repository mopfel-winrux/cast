::  rss: RSS 2.0 feed parser
::
::  parses RSS XML into podcast metadata and episode list
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
  =/  parsed=(unit manx)  (de-xml:html xml)
  ?~  parsed  ~
  =/  channel=(unit manx)  (find-tag 'channel' c.u.parsed)
  ?~  channel  ~
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
    =/  ep=episode:cast
      :*  title=(get-text 'title' c.item)
          description=(get-text 'description' c.item)
          audio-url=(fall (get-enclosure-url c.item) '')
          pub-date=(fall (parse-rfc2822 (get-text 'pubDate' c.item)) *@da)
          duration=(fall (parse-duration (get-text 'itunes:duration' c.item)) 0)
          guid=guid
          image-url=(fall (get-itunes-image c.item) '')
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
        dim:ag
        ;~(pfix ace mon-to-num)
        ;~(pfix ace dim:ag)
        ;~(pfix ace dim:ag)
        ;~(pfix col dim:ag)
        ;~(pfix col dim:ag)
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
    (rush dur dim:ag)
  ?~  t.colons
    ::  mm:ss
    =/  parsed  (rust t ;~(plug dim:ag ;~(pfix col dim:ag)))
    ?~  parsed  ~
    =/  [m=@ud s=@ud]  u.parsed
    `(add (mul m 60) s)
  ::  hh:mm:ss
  =/  parsed  (rust t ;~(plug dim:ag ;~(pfix col dim:ag) ;~(pfix col dim:ag)))
  ?~  parsed  ~
  =/  [h=@ud m=@ud s=@ud]  u.parsed
  `:(add (mul h 3.600) (mul m 60) s)
--
