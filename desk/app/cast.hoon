::  cast: podcast player for urbit
::
::  manages podcast subscriptions, episodes, playback state,
::  and serves a JSON API via eyre.
::
/-  cast, cast-state, storage
/+  dbug, verb, server, default-agent, rss
|%
+$  card  card:agent:gall
--
::
%-  agent:dbug
=|  state-4:cast
=*  state  -
=*  archived  archived.state
%+  verb  |
^-  agent:gall
|_  =bowl:gall
+*  this   .
    def    ~(. (default-agent this %|) bowl)
::
++  on-agent  on-agent:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  =vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state:cast-state vase)
  |^
  :-  ~
  ?-  -.old
      %4  this(state old)
      %3
    %=  this
      state  :*  %4
        podcasts.old  episodes.old  estate.old
        queue.old  settings.old  cache.old
        current.old  archived.old  history.old
        feed-hashes.old  feed-errors.old
        podcast-speeds.old  podcast-order.old
        notes.old  bookmarks.old
        listen-time.old  completed-count.old
        [default-pi-key:cast-state default-pi-secret:cast-state]
      ==
    ==
  ::
      %2
    %=  this
      state  :*  %4
        podcasts.old  (upgrade-episodes episodes.old)  estate.old
        queue.old  settings.old  cache.old
        current.old  archived.old  history.old
        feed-hashes.old  feed-errors.old
        podcast-speeds.old  podcast-order.old
        *(map episode-id:cast @t)
        *(map episode-id:cast (list [position=@ud label=@t]))
        *(map podcast-id:cast @ud)
        *(map podcast-id:cast @ud)
        [default-pi-key:cast-state default-pi-secret:cast-state]
      ==
    ==
  ::
      %1
    %=  this
      state  :*  %4
        podcasts.old  (upgrade-episodes episodes.old)  estate.old
        queue.old  settings.old  cache.old
        current.old  archived.old  history.old
        feed-hashes.old
        *(map @t @t)
        *(map podcast-id:cast @ud)
        *(list podcast-id:cast)
        *(map episode-id:cast @t)
        *(map episode-id:cast (list [position=@ud label=@t]))
        *(map podcast-id:cast @ud)
        *(map podcast-id:cast @ud)
        [default-pi-key:cast-state default-pi-secret:cast-state]
      ==
    ==
  ::
      %0
    %=  this
      state  :*  %4
        podcasts.old  (upgrade-episodes episodes.old)  estate.old
        queue.old  settings.old  cache.old
        current.old  archived.old  history.old
        *(map podcast-id:cast @uvH)
        *(map @t @t)
        *(map podcast-id:cast @ud)
        *(list podcast-id:cast)
        *(map episode-id:cast @t)
        *(map episode-id:cast (list [position=@ud label=@t]))
        *(map podcast-id:cast @ud)
        *(map podcast-id:cast @ud)
        [default-pi-key:cast-state default-pi-secret:cast-state]
      ==
    ==
  ==
  ::  convert episode-0 maps to episode maps (add empty chapters)
  ++  upgrade-episodes
    |=  old-eps=(map podcast-id:cast (map episode-id:cast episode-0:cast))
    ^-  (map podcast-id:cast (map episode-id:cast episode:cast))
    %-  ~(run by old-eps)
    |=  inner=(map episode-id:cast episode-0:cast)
    ^-  (map episode-id:cast episode:cast)
    %-  ~(run by inner)
    |=  ep=episode-0:cast
    ^-  episode:cast
    :*  title.ep  description.ep  audio-url.ep
        pub-date.ep  duration.ep  guid.ep  image-url.ep
        ~
    ==
  --
::
++  on-init
  ^-  (quip card _this)
  =/  default-settings=settings:cast
    [playback-speed=100 auto-download=%.n refresh-interval=~h1]
  :_  this(settings default-settings)
  :~  ::  bind to eyre
      :*  %pass  /eyre/connect
          %arvo  %e  %connect
          [`/apps/cast/api dap.bowl]
      ==
      ::  set initial refresh timer
      [%pass /timer/refresh %arvo %b [%wait (add now.bowl ~h1)]]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark
    (on-poke:def mark vase)
  ::
      %cast-action
    =/  act=action:cast  !<(action:cast vase)
    (handle-action act)
  ::
      %handle-http-request
    (handle-http !<([@ta inbound-request:eyre] vase))
  ==
  ::
  ++  handle-action
    |=  act=action:cast
    ^-  (quip card _this)
    ?>  =(src our):bowl
    ?-  -.act
    ::
        %subscribe
      =/  pid=podcast-id:cast  (sham url.act)
      ?:  (~(has by podcasts) pid)
        %-  (slog leaf+"cast: already subscribed to {(trip url.act)}" ~)
        `this
      %-  (slog leaf+"cast: fetching feed {(trip url.act)}" ~)
      :_  this
      :~  :*  %pass  /fetch/subscribe/(scot %uv pid)/(scot %t url.act)
              %arvo  %i
              %request
              [%'GET' url.act ~ ~]
              *outbound-config:iris
          ==
      ==
    ::
        %unsubscribe
      =/  pid  podcast-id.act
      ?.  (~(has by podcasts) pid)
        `this
      ::  collect episode IDs for this podcast to clean archived set
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  eids=(set episode-id:cast)  ~(key by eps)
      =/  upd=update:cast  [%podcast-removed pid]
      :_  %=  this
            podcasts  (~(del by podcasts) pid)
            episodes  (~(del by episodes) pid)
            archived  (~(dif in archived) eids)
            podcast-order  (skip podcast-order |=(p=podcast-id:cast =(p pid)))
          ==
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %refresh
      =/  pid  podcast-id.act
      =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
      ?~  pod  `this
      :_  this
      :~  :*  %pass  /fetch/refresh/(scot %uv pid)
              %arvo  %i
              %request
              [%'GET' feed-url.u.pod ~ ~]
              *outbound-config:iris
          ==
      ==
    ::
        %refresh-all
      =/  pods=(list [podcast-id:cast podcast:cast])  ~(tap by podcasts)
      :_  this
      %+  turn  pods
      |=  [pid=podcast-id:cast pod=podcast:cast]
      ^-  card
      :*  %pass  /fetch/refresh/(scot %uv pid)
          %arvo  %i
          %request
          [%'GET' feed-url.pod ~ ~]
          *outbound-config:iris
      ==
    ::
        %set-position
      =/  eid  episode-id.act
      =/  pos  position.act
      =/  es=episode-state:cast
        (fall (~(get by estate) eid) *episode-state:cast)
      =.  position.es  pos
      =/  upd=update:cast  [%position-updated eid pos]
      :_  this(estate (~(put by estate) eid es))
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %set-played
      =/  eid  episode-id.act
      =/  es=episode-state:cast
        (fall (~(get by estate) eid) *episode-state:cast)
      =.  played.es  played.act
      =?  last-played.es  played.act  now.bowl
      =/  upd=update:cast  [%played-updated eid played.act]
      :_  this(estate (~(put by estate) eid es))
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %enqueue
      =/  entry=[podcast-id:cast episode-id:cast]
        [podcast-id.act episode-id.act]
      =.  queue  (snoc queue entry)
      =/  upd=update:cast  [%queue-updated queue]
      :_  this
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %dequeue
      =.  queue
        %+  skip  queue
        |=  [pid=podcast-id:cast eid=episode-id:cast]
        ?&  =(pid podcast-id.act)
            =(eid episode-id.act)
        ==
      =/  upd=update:cast  [%queue-updated queue]
      :_  this
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %set-current
      =/  cur=[podcast-id:cast episode-id:cast]
        [podcast-id.act episode-id.act]
      =/  hist-entry=[timestamp=@da =podcast-id:cast =episode-id:cast]
        [now.bowl podcast-id.act episode-id.act]
      =/  new-hist=(list [timestamp=@da =podcast-id:cast =episode-id:cast])
        [hist-entry history]
      =.  history  (scag 100 new-hist)
      =/  upd=update:cast  [%current-updated `cur]
      :_  this(current `cur)
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %clear-current
      =/  upd=update:cast  [%current-updated ~]
      :_  this(current ~)
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %download
      =/  pid  podcast-id.act
      =/  eid  episode-id.act
      =/  eps=(unit (map episode-id:cast episode:cast))
        (~(get by episodes) pid)
      ?~  eps  `this
      =/  ep=(unit episode:cast)  (~(get by u.eps) eid)
      ?~  ep  `this
      %-  (slog leaf+"cast: downloading {(trip title.u.ep)}" ~)
      :_  this
      :~  :*  %pass  /fetch/download/(scot %uv pid)/(scot %uv eid)
              %arvo  %i
              %request
              [%'GET' audio-url.u.ep ~ ~]
              *outbound-config:iris
          ==
      ==
    ::
        %set-settings
      =/  upd=update:cast  [%settings-updated settings.act]
      :_  this(settings settings.act)
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %add-episode
      =/  pid  podcast-id.act
      ::  create the podcast entry if it doesn't exist (for uploads)
      =?  podcasts  !(~(has by podcasts) pid)
        (~(put by podcasts) pid ['uploads' 'Uploads' '' 'Uploaded audio files' '' '' now.bowl])
      =/  eid=episode-id:cast  (sham audio-url.act)
      =/  ep=episode:cast
        [title.act '' audio-url.act now.bowl 0 audio-url.act '' ~]
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =.  episodes  (~(put by episodes) pid (~(put by eps) eid ep))
      =/  upd=update:cast  [%podcast-added pid (~(got by podcasts) pid) ~[[eid ep]]]
      :_  this
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %import-opml
      =/  feed-urls=(list @t)  urls.act
      %-  (slog leaf+"cast: importing {(a-co:co (lent feed-urls))} feeds from OPML" ~)
      :_  this
      %+  murn  feed-urls
      |=  url=@t
      ^-  (unit card)
      =/  pid=podcast-id:cast  (sham url)
      ?:  (~(has by podcasts) pid)  ~
      %-  some
      :*  %pass  /fetch/subscribe/(scot %uv pid)/(scot %t url)
          %arvo  %i
          %request
          [%'GET' url ~ ~]
          *outbound-config:iris
      ==
    ::
        %set-archived
      =/  eid  episode-id.act
      =/  new-archived=(set episode-id:cast)
        ?:  archived.act
          (~(put in archived) eid)
        (~(del in archived) eid)
      =/  upd=update:cast  [%archived-updated eid archived.act]
      :_  this(archived new-archived)
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %mark-all-played
      =/  pid  podcast-id.act
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  eids=(list episode-id:cast)  ~(tap in ~(key by eps))
      =/  new-estate=(map episode-id:cast episode-state:cast)  estate
      |-
      ?~  eids
        =/  upd=update:cast  [%bulk-played-updated pid %.y]
        :_  this(estate new-estate)
        :~  [%give %fact ~[/updates] cast-update+!>(upd)]
        ==
      =/  es=episode-state:cast
        (fall (~(get by new-estate) i.eids) *episode-state:cast)
      =.  played.es  %.y
      %=  $
        new-estate  (~(put by new-estate) i.eids es)
        eids        t.eids
      ==
    ::
        %mark-all-unplayed
      =/  pid  podcast-id.act
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  eids=(list episode-id:cast)  ~(tap in ~(key by eps))
      =/  new-estate=(map episode-id:cast episode-state:cast)  estate
      |-
      ?~  eids
        =/  upd=update:cast  [%bulk-played-updated pid %.n]
        :_  this(estate new-estate)
        :~  [%give %fact ~[/updates] cast-update+!>(upd)]
        ==
      =/  es=episode-state:cast
        (fall (~(get by new-estate) i.eids) *episode-state:cast)
      =.  played.es  %.n
      %=  $
        new-estate  (~(put by new-estate) i.eids es)
        eids        t.eids
      ==
    ::
        %archive-all
      =/  pid  podcast-id.act
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  eids=(set episode-id:cast)  ~(key by eps)
      :_  this(archived (~(uni in archived) eids))
      ~
    ::
        %unarchive-all
      =/  pid  podcast-id.act
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  eids=(set episode-id:cast)  ~(key by eps)
      :_  this(archived (~(dif in archived) eids))
      ~
    ::
        %reorder-queue
      =.  queue  order.act
      =/  upd=update:cast  [%queue-updated queue]
      :_  this
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ::
        %mark-before-played
      =/  pid  podcast-id.act
      =/  cutoff=@da  before.act
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
      =/  ep-list=(list [eid=episode-id:cast ep=episode:cast])  ~(tap by eps)
      =/  new-estate=(map episode-id:cast episode-state:cast)  estate
      |-
      ?~  ep-list
        =/  upd=update:cast  [%bulk-played-updated pid %.y]
        :_  this(estate new-estate)
        :~  [%give %fact ~[/updates] cast-update+!>(upd)]
        ==
      ?.  (lth pub-date.ep.i.ep-list cutoff)
        $(ep-list t.ep-list)
      =/  es=episode-state:cast
        (fall (~(get by new-estate) eid.i.ep-list) *episode-state:cast)
      =.  played.es  %.y
      %=  $
        new-estate  (~(put by new-estate) eid.i.ep-list es)
        ep-list     t.ep-list
      ==
    ::
        %set-podcast-speed
      =/  pid  podcast-id.act
      =.  podcast-speeds  (~(put by podcast-speeds) pid speed.act)
      `this
    ::
        %reorder-podcasts
      =.  podcast-order  order.act
      `this
    ::
        %set-note
      =/  eid  episode-id.act
      =.  notes
        ?:  =('' note.act)
          (~(del by notes) eid)
        (~(put by notes) eid note.act)
      `this
    ::
        %add-bookmark
      =/  eid  episode-id.act
      =/  existing=(list [position=@ud label=@t])
        (fall (~(get by bookmarks) eid) ~)
      =.  bookmarks
        (~(put by bookmarks) eid (snoc existing [position.act label.act]))
      `this
    ::
        %remove-bookmark
      =/  eid  episode-id.act
      =/  existing=(list [position=@ud label=@t])
        (fall (~(get by bookmarks) eid) ~)
      =.  bookmarks
        %+  ~(put by bookmarks)  eid
        (skip existing |=([p=@ud l=@t] =(p position.act)))
      `this
    ::
        %log-listen
      =/  pid  podcast-id.act
      =.  listen-time
        (~(put by listen-time) pid (add seconds.act (fall (~(get by listen-time) pid) 0)))
      `this
    ::
        %log-complete
      =/  pid  podcast-id.act
      =.  completed-count
        (~(put by completed-count) pid (add 1 (fall (~(get by completed-count) pid) 0)))
      `this
    ::
        %set-pi-credentials
      `this(pi-creds creds.act)
    ==
  ::
  ::  HTTP request handling
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    ?.  authenticated.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (login-redirect:gen:server request.req)
    =/  rl=request-line:server
      (parse-request-line:server url.request.req)
    ::  remove /apps/cast/api prefix from site path
    =/  site=(list @t)  site.rl
    =/  site=(list @t)
      ?.  ?=([%apps %cast %api *] site)
        site
      t.t.t.site
    ::  re-attach extension to last segment for API routes
    ::  (parse-request-line strips file extension, but @uv IDs contain dots)
    =/  site=(list @t)
      ?~  ext.rl  site
      ?~  site    site
      %+  snoc
        (scag (dec (lent site)) `(list @t)`site)
      (crip "{(trip (rear site))}.{(trip u.ext.rl)}")
    ?+  method.request.req
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[405 ~] ~]
    ::
        %'GET'
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      (handle-scry site)
    ::
        %'POST'
      (handle-poke eyre-id req)
    ==
  ::
  ++  handle-scry
    |=  site=(list @t)
    ^-  simple-payload:http
    ?+  site
      not-found:gen:server
    ::
        [%podcasts ~]
      =/  all-pods=(list [podcast-id:cast podcast:cast])  ~(tap by podcasts)
      ::  sort by podcast-order if set, unordered ones go at end
      =/  ordered-pods=(list [podcast-id:cast podcast:cast])
        ?~  podcast-order  all-pods
        =/  pod-map=(map podcast-id:cast podcast:cast)  podcasts
        =/  in-order=(list [podcast-id:cast podcast:cast])
          %+  murn  podcast-order
          |=  pid=podcast-id:cast
          =/  pod=(unit podcast:cast)  (~(get by pod-map) pid)
          ?~  pod  ~
          `[pid u.pod]
        =/  order-set=(set podcast-id:cast)
          (~(gas in *(set podcast-id:cast)) podcast-order)
        =/  rest=(list [podcast-id:cast podcast:cast])
          (skip all-pods |=([pid=podcast-id:cast *] (~(has in order-set) pid)))
        (welp in-order rest)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'podcasts'
          :-  %a
          %+  turn  ordered-pods
          |=  [pid=podcast-id:cast pod=podcast:cast]
          =/  eps=(map episode-id:cast episode:cast)
            (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
          =/  ep-list=(list [episode-id:cast episode:cast])  ~(tap by eps)
          =/  visible=(list [episode-id:cast episode:cast])
            (skip ep-list |=([eid=episode-id:cast *] (~(has in archived) eid)))
          =/  played-set=(set episode-id:cast)
            %-  ~(gas in *(set episode-id:cast))
            %+  murn  ~(tap by estate)
            |=  [eid=episode-id:cast es=episode-state:cast]
            ?.(played.es ~ `eid)
          =/  unplayed=@ud
            %+  roll  visible
            |=  [[eid=episode-id:cast ep=episode:cast] count=@ud]
            ?.  (~(has in played-set) eid)  +(count)
            count
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv pid)]
              ['title' s+title.pod]
              ['author' s+author.pod]
              ['description' s+description.pod]
              ['image-url' s+image-url.pod]
              ['link' s+link.pod]
              ['feed-url' s+feed-url.pod]
              ['episode-count' (numb:enjs:format (lent visible))]
              ['unplayed-count' (numb:enjs:format unplayed)]
          ==
      ==
    ::
        [%podcast @ ~]
      =/  pid=(unit podcast-id:cast)  (slaw %uv i.t.site)
      ?~  pid  not-found:gen:server
      =/  pod=(unit podcast:cast)  (~(get by podcasts) u.pid)
      ?~  pod  not-found:gen:server
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) u.pid) *(map episode-id:cast episode:cast))
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['id' s+(scot %uv u.pid)]
          ['title' s+title.u.pod]
          ['author' s+author.u.pod]
          ['description' s+description.u.pod]
          ['image-url' s+image-url.u.pod]
          ['link' s+link.u.pod]
          ['feed-url' s+feed-url.u.pod]
          :-  'episodes'
          :-  %a
          %+  turn  ~(tap by eps)
          |=  [eid=episode-id:cast ep=episode:cast]
          =/  es=episode-state:cast
            (fall (~(get by estate) eid) *episode-state:cast)
          =/  ep-note=@t  (fall (~(get by notes) eid) '')
          =/  ep-bookmarks=(list [position=@ud label=@t])
            (fall (~(get by bookmarks) eid) ~)
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv eid)]
              ['title' s+title.ep]
              ['description' s+description.ep]
              ['audio-url' s+audio-url.ep]
              ['pub-date' ?:(=(0 pub-date.ep) (numb:enjs:format 0) (sect:enjs:format pub-date.ep))]
              ['duration' (numb:enjs:format duration.ep)]
              ['guid' s+guid.ep]
              ['image-url' s+image-url.ep]
              ['played' b+played.es]
              ['position' (numb:enjs:format position.es)]
              ['downloaded' b+downloaded.es]
              ['archived' b+(~(has in archived) eid)]
              ['note' s+ep-note]
              :-  'bookmarks'
              :-  %a
              %+  turn  ep-bookmarks
              |=  [p=@ud l=@t]
              %-  pairs:enjs:format
              :~  ['position' (numb:enjs:format p)]
                  ['label' s+l]
              ==
              :-  'chapters'
              :-  %a
              %+  turn  chapters.ep
              |=  [s=@ud t=@t]
              %-  pairs:enjs:format
              :~  ['start' (numb:enjs:format s)]
                  ['title' s+t]
              ==
          ==
      ==
    ::
        [%episodes @ ~]
      =/  pid=(unit podcast-id:cast)  (slaw %uv i.t.site)
      ?~  pid  not-found:gen:server
      =/  eps=(map episode-id:cast episode:cast)
        (fall (~(get by episodes) u.pid) *(map episode-id:cast episode:cast))
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'episodes'
          :-  %a
          %+  turn  ~(tap by eps)
          |=  [eid=episode-id:cast ep=episode:cast]
          =/  es=episode-state:cast
            (fall (~(get by estate) eid) *episode-state:cast)
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv eid)]
              ['title' s+title.ep]
              ['audio-url' s+audio-url.ep]
              ['pub-date' ?:(=(0 pub-date.ep) (numb:enjs:format 0) (sect:enjs:format pub-date.ep))]
              ['duration' (numb:enjs:format duration.ep)]
              ['played' b+played.es]
              ['position' (numb:enjs:format position.es)]
              ['archived' b+(~(has in archived) eid)]
          ==
      ==
    ::
        [%queue ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'queue'
          :-  %a
          %+  turn  queue
          |=  [pid=podcast-id:cast eid=episode-id:cast]
          =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
          =/  eps=(unit (map episode-id:cast episode:cast))  (~(get by episodes) pid)
          =/  ep=(unit episode:cast)
            ?~  eps  ~
            (~(get by u.eps) eid)
          %-  pairs:enjs:format
          :~  ['podcast-id' s+(scot %uv pid)]
              ['episode-id' s+(scot %uv eid)]
              ['podcast-title' s+?~(pod '' title.u.pod)]
              ['podcast-image' s+?~(pod '' image-url.u.pod)]
              ['title' s+?~(ep '' title.u.ep)]
              ['audio-url' s+?~(ep '' audio-url.u.ep)]
              ['duration' (numb:enjs:format ?~(ep 0 duration.u.ep))]
              ['image-url' s+?~(ep '' image-url.u.ep)]
          ==
      ==
    ::
        [%player ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'current'
          ?~  current  ~
          =/  pid  podcast-id.u.current
          =/  eid  episode-id.u.current
          =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
          =/  ep-map=(unit (map episode-id:cast episode:cast))  (~(get by episodes) pid)
          =/  ep=(unit episode:cast)
            ?~  ep-map  ~
            (~(get by u.ep-map) eid)
          =/  es=episode-state:cast
            (fall (~(get by estate) eid) *episode-state:cast)
          %-  pairs:enjs:format
          :~  ['podcast-id' s+(scot %uv pid)]
              ['episode-id' s+(scot %uv eid)]
              ['podcast-title' s+?~(pod '' title.u.pod)]
              ['episode-title' s+?~(ep '' title.u.ep)]
              ['position' (numb:enjs:format position.es)]
              ['image-url' s+?~(pod '' image-url.u.pod)]
          ==
      ==
    ::
        [%settings ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['playback-speed' (numb:enjs:format playback-speed.settings)]
          ['auto-download' b+auto-download.settings]
          ['refresh-interval' (numb:enjs:format (div refresh-interval.settings ~s1))]
      ==
    ::
        [%history ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'history'
          :-  %a
          %+  turn  (scag 50 history)
          |=  [ts=@da pid=podcast-id:cast eid=episode-id:cast]
          =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
          =/  ep-map=(unit (map episode-id:cast episode:cast))  (~(get by episodes) pid)
          =/  ep=(unit episode:cast)
            ?~  ep-map  ~
            (~(get by u.ep-map) eid)
          %-  pairs:enjs:format
          :~  ['timestamp' (sect:enjs:format ts)]
              ['podcast-id' s+(scot %uv pid)]
              ['episode-id' s+(scot %uv eid)]
              ['podcast-title' s+?~(pod '' title.u.pod)]
              ['episode-title' s+?~(ep '' title.u.ep)]
              ['image-url' s+?~(pod '' image-url.u.pod)]
          ==
      ==
    ::
        [%'podcast-speeds' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'speeds'
          %-  pairs:enjs:format
          %+  turn  ~(tap by podcast-speeds)
          |=  [pid=podcast-id:cast spd=@ud]
          [(scot %uv pid) (numb:enjs:format spd)]
      ==
    ::
        [%'feed-errors' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'errors'
          %-  pairs:enjs:format
          %+  turn  ~(tap by feed-errors)
          |=  [url=@t msg=@t]
          [url s+msg]
      ==
    ::
        [%'export-opml' ~]
      =/  pods=(list [podcast-id:cast podcast:cast])  ~(tap by podcasts)
      =/  outlines=tape
        %-  zing
        %+  turn  pods
        |=  [pid=podcast-id:cast pod=podcast:cast]
        ;:  welp
          "<outline type=\"rss\" text=\""
          (escape-xml (trip title.pod))
          "\" title=\""
          (escape-xml (trip title.pod))
          "\" xmlUrl=\""
          (escape-xml (trip feed-url.pod))
          "\" />"
        ==
      =/  xml-tape=tape
        ;:  welp
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
          "<opml version=\"2.0\">"
          "<head><title>Cast Subscriptions</title></head>"
          "<body>"
          outlines
          "</body></opml>"
        ==
      [[200 ['content-type' 'text/xml']~] `(as-octs:mimes:html (crip xml-tape))]
    ::
        [%stats ~]
      =/  total-seconds=@ud
        %+  roll  ~(val by listen-time)
        |=  [s=@ud a=@ud]
        (add s a)
      =/  total-completed=@ud
        %+  roll  ~(val by completed-count)
        |=  [s=@ud a=@ud]
        (add s a)
      =/  per-pod=(list [podcast-id:cast @ud @ud])
        %+  turn  ~(tap by podcasts)
        |=  [pid=podcast-id:cast pod=podcast:cast]
        :+  pid
          (fall (~(get by listen-time) pid) 0)
        (fall (~(get by completed-count) pid) 0)
      ::  sort by listen seconds descending
      =/  sorted=(list [podcast-id:cast @ud @ud])
        %+  sort  per-pod
        |=  [[* a=@ud *] [* b=@ud *]]
        (gth a b)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['total-seconds' (numb:enjs:format total-seconds)]
          ['total-completed' (numb:enjs:format total-completed)]
          :-  'podcasts'
          :-  %a
          %+  turn  sorted
          |=  [pid=podcast-id:cast secs=@ud comp=@ud]
          =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv pid)]
              ['title' s+?~(pod '' title.u.pod)]
              ['image-url' s+?~(pod '' image-url.u.pod)]
              ['seconds' (numb:enjs:format secs)]
              ['completed' (numb:enjs:format comp)]
          ==
      ==
    ::
        [%'pi-credentials' ~]
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['key' s+key.pi-creds]
          ['secret' s+secret.pi-creds]
      ==
    ::
        [%'s3-config' ~]
      ::  read credentials and configuration from %storage agent
      ::  scry as json to avoid cross-desk type mismatch
      ::  json shape: {"storage-update":{"credentials":{...}}}
      =/  cred-json=json
        .^(json %gx /(scot %p our.bowl)/storage/(scot %da now.bowl)/credentials/json)
      =/  conf-json=json
        .^(json %gx /(scot %p our.bowl)/storage/(scot %da now.bowl)/configuration/json)
      =/  get-str
        |=  [=json keys=(list @t)]
        ^-  @t
        ?~  keys  ?:(?=([%s *] json) p.json '')
        ?.  ?=([%o *] json)  ''
        =/  v  (~(get by p.json) i.keys)
        ?~  v  ''
        $(json u.v, keys t.keys)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['endpoint' s+(get-str cred-json ~['storage-update' 'credentials' 'endpoint'])]
          ['accessKeyId' s+(get-str cred-json ~['storage-update' 'credentials' 'accessKeyId'])]
          ['secretAccessKey' s+(get-str cred-json ~['storage-update' 'credentials' 'secretAccessKey'])]
          ['bucket' s+(get-str conf-json ~['storage-update' 'configuration' 'currentBucket'])]
          ['region' s+(get-str conf-json ~['storage-update' 'configuration' 'region'])]
      ==
    ==
  ::
  ++  escape-xml
    |=  t=tape
    ^-  tape
    %-  zing
    %+  turn  t
    |=  c=@
    ^-  tape
    ?+  c  [c ~]
      %'&'   "&amp;"
      %'<'   "&lt;"
      %'>'   "&gt;"
      %'"'   "&quot;"
      %'\''  "&apos;"
    ==
  ::
  ++  handle-poke
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  body=(unit octs)  body.request.req
    ?~  body
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  jon=(unit json)  (de:json:html q.u.body)
    ?~  jon
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  act=(unit action:cast)
      %-  mole
      |.((action:cast (json:grab:cast-action-mark u.jon)))
    ?~  act
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      [[400 ~] ~]
    =/  [cards=(list card) new-this=_this]
      (handle-action u.act)
    :_  new-this
    %+  welp
      %+  give-simple-payload:app:server  eyre-id
      %-  json-response:gen:server
      (pairs:enjs:format ~[['ok' b+%.y]])
    cards
  ::
  ++  cast-action-mark
    |_  act=action:cast
    ++  grab
      |%
      ++  json
        |=  jon=^json
        ^-  action:cast
        =,  dejs:format
        =/  typ=@t  ((ot ~[action+so]) jon)
        ?+  typ  !!
            %subscribe
          [%subscribe ((ot ~[url+so]) jon)]
        ::
            %unsubscribe
          [%unsubscribe ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %refresh
          [%refresh ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'refresh-all'
          [%refresh-all ~]
        ::
            %'set-position'
          =/  f  (ot ~[episode-id+(se %uv) position+ni])
          =/  [eid=@uv pos=@ud]  (f jon)
          [%set-position eid pos]
        ::
            %'set-played'
          =/  f  (ot ~[episode-id+(se %uv) played+bo])
          =/  [eid=@uv played=?]  (f jon)
          [%set-played eid played]
        ::
            %enqueue
          =/  f  (ot ~[podcast-id+(se %uv) episode-id+(se %uv)])
          =/  [pid=@uv eid=@uv]  (f jon)
          [%enqueue pid eid]
        ::
            %dequeue
          =/  f  (ot ~[podcast-id+(se %uv) episode-id+(se %uv)])
          =/  [pid=@uv eid=@uv]  (f jon)
          [%dequeue pid eid]
        ::
            %'set-current'
          =/  f  (ot ~[podcast-id+(se %uv) episode-id+(se %uv)])
          =/  [pid=@uv eid=@uv]  (f jon)
          [%set-current pid eid]
        ::
            %'clear-current'
          [%clear-current ~]
        ::
            %download
          =/  f  (ot ~[podcast-id+(se %uv) episode-id+(se %uv)])
          =/  [pid=@uv eid=@uv]  (f jon)
          [%download pid eid]
        ::
            %'set-settings'
          =/  f  (ot ~[playback-speed+ni auto-download+bo refresh-interval+ni])
          =/  [spd=@ud dl=? interval=@ud]  (f jon)
          [%set-settings [spd dl (mul ~s1 interval)]]
        ::
            %'import-opml'
          =/  urls=(list @t)
            ((ot ~[urls+(ar so)]) jon)
          [%import-opml urls]
        ::
            %'add-episode'
          =/  f  (ot ~[podcast-id+(se %uv) title+so audio-url+so])
          =/  [pid=@uv tit=@t url=@t]  (f jon)
          [%add-episode pid tit url]
        ::
            %'set-archived'
          =/  f  (ot ~[episode-id+(se %uv) archived+bo])
          =/  [eid=@uv arc=?]  (f jon)
          [%set-archived eid arc]
        ::
            %'mark-all-played'
          [%mark-all-played ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'mark-all-unplayed'
          [%mark-all-unplayed ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'archive-all'
          [%archive-all ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'unarchive-all'
          [%unarchive-all ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'reorder-queue'
          =/  order=(list [podcast-id:cast episode-id:cast])
            ((ot ~[order+(ar (ot ~[podcast-id+(se %uv) episode-id+(se %uv)]))]) jon)
          [%reorder-queue order]
        ::
            %'mark-before-played'
          =/  f  (ot ~[podcast-id+(se %uv) date+ni])
          =/  [pid=@uv d=@ud]  (f jon)
          [%mark-before-played pid (add ~1970.1.1 (mul ~s1 d))]
        ::
            %'set-podcast-speed'
          =/  f  (ot ~[podcast-id+(se %uv) speed+ni])
          =/  [pid=@uv spd=@ud]  (f jon)
          [%set-podcast-speed pid spd]
        ::
            %'reorder-podcasts'
          =/  order=(list podcast-id:cast)
            ((ot ~[order+(ar (se %uv))]) jon)
          [%reorder-podcasts order]
        ::
            %'set-note'
          =/  f  (ot ~[episode-id+(se %uv) note+so])
          =/  [eid=@uv n=@t]  (f jon)
          [%set-note eid n]
        ::
            %'add-bookmark'
          =/  f  (ot ~[episode-id+(se %uv) position+ni label+so])
          =/  [eid=@uv pos=@ud lbl=@t]  (f jon)
          [%add-bookmark eid pos lbl]
        ::
            %'remove-bookmark'
          =/  f  (ot ~[episode-id+(se %uv) position+ni])
          =/  [eid=@uv pos=@ud]  (f jon)
          [%remove-bookmark eid pos]
        ::
            %'log-listen'
          =/  f  (ot ~[podcast-id+(se %uv) seconds+ni])
          =/  [pid=@uv secs=@ud]  (f jon)
          [%log-listen pid secs]
        ::
            %'log-complete'
          [%log-complete ((ot ~[podcast-id+(se %uv)]) jon)]
        ::
            %'set-pi-credentials'
          =/  f  (ot ~[key+so secret+so])
          =/  [k=@t s=@t]  (f jon)
          [%set-pi-credentials [k s]]
        ==
      --
    --
  --
::
++  on-peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+  pole  (on-peek:def `path`pole)
  ::
    ::  .^(json %gx /=cast=/podcasts/json)
    [%x %podcasts ~]
      =/  =json
        %-  pairs:enjs:format
        :~  :-  'podcasts'
            :-  %a
            %+  turn  ~(tap by podcasts)
            |=  [pid=podcast-id:cast pod=podcast:cast]
            =/  eps=(map episode-id:cast episode:cast)
              (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
            =/  ep-list=(list [episode-id:cast episode:cast])  ~(tap by eps)
            =/  visible=(list [episode-id:cast episode:cast])
              (skip ep-list |=([eid=episode-id:cast *] (~(has in archived) eid)))
            =/  played-set=(set episode-id:cast)
              %-  ~(gas in *(set episode-id:cast))
              %+  murn  ~(tap by estate)
              |=  [eid=episode-id:cast es=episode-state:cast]
              ?.(played.es ~ `eid)
            =/  unplayed=@ud
              %+  roll  visible
              |=  [[eid=episode-id:cast ep=episode:cast] count=@ud]
              ?.  (~(has in played-set) eid)  +(count)
              count
            %-  pairs:enjs:format
            :~  ['id' s+(scot %uv pid)]
                ['title' s+title.pod]
                ['author' s+author.pod]
                ['image-url' s+image-url.pod]
                ['episode-count' (numb:enjs:format (lent visible))]
                ['unplayed-count' (numb:enjs:format unplayed)]
            ==
        ==
      ``json+!>(json)
  ::
    [%x %settings ~]
      =/  =json
        %-  pairs:enjs:format
        :~  ['playback-speed' (numb:enjs:format playback-speed.settings)]
            ['auto-download' b+auto-download.settings]
        ==
      ``json+!>(json)
  ==
::
++  on-arvo
  |=  [=(pole knot) =sign-arvo]
  ^-  (quip card _this)
  |^
  ?+  pole  `this
  ::
      [%eyre %connect ~]
    ?>  ?=([%eyre %bound *] sign-arvo)
    ?:  accepted.sign-arvo
      %-  (slog leaf+"cast: bound at /apps/cast/api" ~)
      `this
    %-  (slog leaf+"cast: FAILED to bind at /apps/cast/api" ~)
    `this
  ::
      [%timer %refresh ~]
    ?>  ?=([%behn %wake *] sign-arvo)
    ?^  error.sign-arvo
      %-  (slog leaf+"cast: timer error" ~)
      `this
    ::  refresh all feeds and reset timer
    =/  pods=(list [podcast-id:cast podcast:cast])  ~(tap by podcasts)
    :_  this
    :-  [%pass /timer/refresh %arvo %b [%wait (add now.bowl refresh-interval.settings)]]
    %+  turn  pods
    |=  [pid=podcast-id:cast pod=podcast:cast]
    ^-  card
    :*  %pass  /fetch/refresh/(scot %uv pid)
        %arvo  %i
        %request
        [%'GET' feed-url.pod ~ ~]
        *outbound-config:iris
    ==
  ::
      [%fetch %subscribe pid=@ url=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    %-  (slog leaf+"cast: got iris response on subscribe wire" ~)
    (handle-feed-response (slav %uv pid.pole) client-response.sign-arvo %.y `(slav %t url.pole))
  ::
      [%fetch %refresh pid=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    (handle-feed-response (slav %uv pid.pole) client-response.sign-arvo %.n ~)
  ::
      [%fetch %download pid=@ eid=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    (handle-download-response (slav %uv pid.pole) (slav %uv eid.pole) client-response.sign-arvo)
  ==
  ::
  ++  handle-feed-response
    |=  [pid=podcast-id:cast resp=client-response:iris is-new=? orig-url=(unit @t)]
    ^-  (quip card _this)
    =/  feed-url=@t  (fall orig-url '')
    ?.  ?=(%finished -.resp)
      %-  (slog leaf+"cast: unexpected response for {(trip feed-url)}" ~)
      `this
    =/  code=@ud  status-code.response-header.resp
    ::  follow redirects (301, 302, 307, 308)
    ?:  ?&  (gte code 301)
            (lte code 308)
        ==
      =/  location=(unit @t)
        =/  locs=(list @t)
          %+  murn  headers.response-header.resp
          |=  [key=@t value=@t]
          ^-  (unit @t)
          ?.  =('location' (crip (cass (trip key))))  ~
          `value
        ?~  locs  ~
        `i.locs
      ?~  location
        %-  (slog leaf+"cast: {(a-co:co code)} but no Location header for {(trip feed-url)}" ~)
        `this
      %-  (slog leaf+"cast: following redirect to {(trip u.location)}" ~)
      :_  this
      :~  :*  %pass
              ?:  is-new
                /fetch/subscribe/(scot %uv pid)/(scot %t u.location)
              /fetch/refresh/(scot %uv pid)
              %arvo  %i
              %request
              [%'GET' u.location ~ ~]
              *outbound-config:iris
          ==
      ==
    =/  err-url=@t
      ?^  orig-url  u.orig-url
      =/  pod=(unit podcast:cast)  (~(get by podcasts) pid)
      ?~  pod  ''
      feed-url.u.pod
    ?.  =(200 code)
      %-  (slog leaf+"cast: got HTTP {(a-co:co code)} for {(trip feed-url)}" ~)
      ?:  =('' err-url)  `this
      `this(feed-errors (~(put by feed-errors) err-url (crip "HTTP {(a-co:co code)}")))
    ?~  full-file.resp
      %-  (slog leaf+"cast: empty response for {(trip feed-url)}" ~)
      ?:  =('' err-url)  `this
      `this(feed-errors (~(put by feed-errors) err-url 'Empty response'))
    =/  body=@t  q.data.u.full-file.resp
    ::  hash body and skip parsing if unchanged
    =/  body-hash=@uvH  (sham body)
    =/  old-hash=(unit @uvH)  (~(get by feed-hashes) pid)
    ?:  ?&  ?=(^ old-hash)
            =(u.old-hash body-hash)
            ?!  is-new
        ==
      %-  (slog leaf+"cast: feed unchanged for {(trip feed-url)}, skipping parse" ~)
      `this
    =.  feed-hashes  (~(put by feed-hashes) pid body-hash)
    %-  (slog leaf+"cast: parsing feed {(trip feed-url)} ({(a-co:co (met 3 body))} bytes)" ~)
    =/  result  (parse-feed:rss feed-url body)
    ?~  result
      %-  (slog leaf+"cast: parse-feed failed for {(trip feed-url)}" ~)
      ?:  =('' err-url)  `this
      `this(feed-errors (~(put by feed-errors) err-url 'Feed parse failed'))
    =/  [pod=podcast:cast eps=(list [episode-id:cast episode:cast])]
      u.result
    ::  clear feed error on success
    =?  feed-errors  ?=(^ orig-url)
      (~(del by feed-errors) u.orig-url)
    ::  also clear by existing podcast's feed-url for refresh case
    =/  existing-feed-url=(unit @t)
      =/  ep=(unit podcast:cast)  (~(get by podcasts) pid)
      ?~  ep  ~
      `feed-url.u.ep
    =?  feed-errors  ?=(^ existing-feed-url)
      (~(del by feed-errors) u.existing-feed-url)
    ::  preserve feed-url from existing podcast if refreshing
    =/  existing-pod=(unit podcast:cast)  (~(get by podcasts) pid)
    =?  feed-url.pod  ?=(^ existing-pod)
      feed-url.u.existing-pod
    =.  last-fetched.pod  now.bowl
    =/  existing-eps=(map episode-id:cast episode:cast)
      (fall (~(get by episodes) pid) *(map episode-id:cast episode:cast))
    ::  find new episodes not already in our map
    =/  new-eps=(list [episode-id:cast episode:cast])
      %+  skip  eps
      |=  [eid=episode-id:cast *]
      (~(has by existing-eps) eid)
    ::  merge all episodes
    =/  all-eps=(map episode-id:cast episode:cast)
      %-  ~(gas by existing-eps)
      eps
    =.  podcasts  (~(put by podcasts) pid pod)
    =.  episodes  (~(put by episodes) pid all-eps)
    ?:  is-new
      %-  (slog leaf+"cast: subscribed to {(trip title.pod)} ({(a-co:co (lent eps))} episodes)" ~)
      =.  podcast-order  (snoc podcast-order pid)
      =/  upd=update:cast  [%podcast-added pid pod eps]
      :_  this
      :~  [%give %fact ~[/updates] cast-update+!>(upd)]
      ==
    ?~  new-eps
      `this
    %-  (slog leaf+"cast: {(a-co:co (lent new-eps))} new episodes for {(trip title.pod)}" ~)
    =/  upd=update:cast  [%episodes-updated pid new-eps]
    :_  this
    :~  [%give %fact ~[/updates] cast-update+!>(upd)]
    ==
  ::
  ++  handle-download-response
    |=  [pid=podcast-id:cast eid=episode-id:cast resp=client-response:iris]
    ^-  (quip card _this)
    ?.  ?=(%finished -.resp)
      %-  (slog leaf+"cast: download unexpected response" ~)
      `this
    ?~  full-file.resp
      %-  (slog leaf+"cast: download empty body" ~)
      `this
    =/  audio=octs  data.u.full-file.resp
    %-  (slog leaf+"cast: downloaded {(a-co:co p.audio)} bytes" ~)
    ::  update episode-state
    =/  es=episode-state:cast
      (fall (~(get by estate) eid) *episode-state:cast)
    =.  downloaded.es  %.y
    =.  estate  (~(put by estate) eid es)
    =.  cache  (~(put by cache) eid audio)
    =/  upd=update:cast  [%download-complete eid]
    :_  this
    :~  [%give %fact ~[/updates] cast-update+!>(upd)]
    ==
  --
::
++  on-watch
  |=  =(pole knot)
  ^-  (quip card _this)
  ?+    pole  (on-watch:def `path`pole)
      [%http-response eyre-id=@ta ~]
    `this
  ::
      [%updates ~]
    ?>  =(src our):bowl
    `this
  ==
--
