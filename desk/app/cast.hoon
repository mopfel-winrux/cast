::  cast: podcast player for urbit
::
::  manages podcast subscriptions, episodes, playback state,
::  and serves a JSON API via eyre.
::
/-  cast, storage
/+  dbug, verb, server, default-agent, rss
|%
+$  card  card:agent:gall
+$  versioned-state
  $:  state-0:cast
  ==
--
::
%-  agent:dbug
=|  state-0:cast
=*  state  -
%+  verb  &
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
  =/  old  !<(versioned-state vase)
  :-  ~
  ?-  -.old
    %0  this(state old)
  ==
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
      :~  :*  %pass  /fetch/subscribe/(scot %uv pid)
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
      =/  upd=update:cast  [%podcast-removed pid]
      :_  %=  this
            podcasts  (~(del by podcasts) pid)
            episodes  (~(del by episodes) pid)
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
        [title.act '' audio-url.act now.bowl 0 audio-url.act '']
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
      :*  %pass  /fetch/subscribe/(scot %uv pid)
          %arvo  %i
          %request
          [%'GET' url ~ ~]
          *outbound-config:iris
      ==
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
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  :-  'podcasts'
          :-  %a
          %+  turn  ~(tap by podcasts)
          |=  [pid=podcast-id:cast pod=podcast:cast]
          %-  pairs:enjs:format
          :~  ['id' s+(scot %uv pid)]
              ['title' s+title.pod]
              ['author' s+author.pod]
              ['description' s+description.pod]
              ['image-url' s+image-url.pod]
              ['link' s+link.pod]
              ['feed-url' s+feed-url.pod]
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
          %-  pairs:enjs:format
          :~  ['podcast-id' s+(scot %uv podcast-id.u.current)]
              ['episode-id' s+(scot %uv episode-id.u.current)]
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
        [%'s3-config' ~]
      ::  read credentials and configuration from %storage agent
      =/  cred-upd=update:storage
        !<(update:storage .^(^vase %gx /(scot %p our.bowl)/storage/(scot %da now.bowl)/credentials/storage-update))
      =/  conf-upd=update:storage
        !<(update:storage .^(^vase %gx /(scot %p our.bowl)/storage/(scot %da now.bowl)/configuration/storage-update))
      ?>  ?=(%credentials -.cred-upd)
      ?>  ?=(%configuration -.conf-upd)
      %-  json-response:gen:server
      %-  pairs:enjs:format
      :~  ['endpoint' s+endpoint.credentials.cred-upd]
          ['accessKeyId' s+access-key-id.credentials.cred-upd]
          ['secretAccessKey' s+secret-access-key.credentials.cred-upd]
          ['bucket' s+current-bucket.configuration.conf-upd]
          ['region' s+region.configuration.conf-upd]
      ==
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
            %-  pairs:enjs:format
            :~  ['id' s+(scot %uv pid)]
                ['title' s+title.pod]
                ['author' s+author.pod]
                ['image-url' s+image-url.pod]
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
      [%fetch %subscribe pid=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    (handle-feed-response (slav %uv pid.pole) client-response.sign-arvo %.y)
  ::
      [%fetch %refresh pid=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    (handle-feed-response (slav %uv pid.pole) client-response.sign-arvo %.n)
  ::
      [%fetch %download pid=@ eid=@ ~]
    ?>  ?=([%iris %http-response *] sign-arvo)
    (handle-download-response (slav %uv pid.pole) (slav %uv eid.pole) client-response.sign-arvo)
  ==
  ::
  ++  handle-feed-response
    |=  [pid=podcast-id:cast resp=client-response:iris is-new=?]
    ^-  (quip card _this)
    ?.  ?=(%finished -.resp)
      %-  (slog leaf+"cast: unexpected response type" ~)
      `this
    ?~  full-file.resp
      %-  (slog leaf+"cast: empty response body" ~)
      `this
    =/  body=@t  q.data.u.full-file.resp
    =/  result  (parse-feed:rss '' body)
    ?~  result
      %-  (slog leaf+"cast: failed to parse feed" ~)
      `this
    =/  [pod=podcast:cast eps=(list [episode-id:cast episode:cast])]
      u.result
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
