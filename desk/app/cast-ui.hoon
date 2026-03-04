::  cast-ui: fileserver for cast web frontend
::
::  serves static files from /site/ path in clay
::
/+  dbug, verb, server, default-agent
|%
+$  card  card:agent:gall
+$  versioned-state
  $:  state-0
  ==
+$  state-0
  $:  %0
      ~
  ==
--
::
%-  agent:dbug
=|  state-0
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
++  on-peek   on-peek:def
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
  :_  this
  :~  :*  %pass  /eyre/connect
          %arvo  %e  %connect
          [`/apps/cast dap.bowl]
      ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ?+  mark
    (on-poke:def mark vase)
  ::
      %handle-http-request
    (handle-http !<([@ta inbound-request:eyre] vase))
  ==
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
    ::  strip /apps/cast prefix
    =/  site=(list @t)  site.rl
    =/  site=(list @t)
      ?.  ?=([%apps %cast *] site)
        site
      t.t.site
    ::  route /api/* to the cast agent (should be handled by cast agent binding)
    ::  this handles the case where the binding falls through
    ?:  ?=([%api *] site)
      :_  this
      %+  give-simple-payload:app:server  eyre-id
      not-found:gen:server
    ::  serve static files
    :_  this
    %+  give-simple-payload:app:server  eyre-id
    (serve-file site)
  ::
  ++  serve-file
    |=  site=(list @t)
    ^-  simple-payload:http
    ::  default to index.html
    ?~  site
      =/  file=(unit octs)  (read-file /site/index/html)
      ?~  file  not-found:gen:server
      (html-response:gen:server u.file)
    ::  parse extension from last segment
    =/  last=@t  (rear site)
    =/  last-tape=tape  (trip last)
    =/  dot=(unit @ud)  (find "." last-tape)
    =/  ext=@t
      ?~  dot  'html'
      (crip (slag +(u.dot) last-tape))
    ::  strip extension from last segment to get base name
    =/  base=@t
      ?~  dot  last
      (crip (scag u.dot last-tape))
    ::  build clay path: /site/dir.../basename/ext
    ::  e.g. ~['css' 'app.css'] -> /site/css/app/css
    =/  clay-path=path
      =/  head=(list @t)
        ?:  (lte (lent site) 1)  ~
        (scag (dec (lent site)) `(list @t)`site)
      (welp /site (welp head `path`/[base]/[ext]))
    =/  file=(unit octs)  (read-file clay-path)
    ?~  file
      ::  SPA fallback: serve index.html
      =/  index=(unit octs)  (read-file /site/index/html)
      ?~  index  not-found:gen:server
      (html-response:gen:server u.index)
    (file-response ext u.file)
  ::
  ++  read-file
    |=  pax=path
    ^-  (unit octs)
    =/  full=path
      %+  welp
        /(scot %p our.bowl)/[q.byk.bowl]/(scot %da now.bowl)
      pax
    ?.  .^(? %cu full)
      ~
    =/  =@t  .^(@t %cx full)
    `(as-octs:mimes:html t)
  ::
  ++  file-response
    |=  [ext=@t =octs]
    ^-  simple-payload:http
    =/  content-type=@t
      ?+  ext  'application/octet-stream'
        %html  'text/html'
        %css   'text/css'
        %js    'text/javascript'
        %json  'application/json'
        %png   'image/png'
        %jpg   'image/jpeg'
        %jpeg  'image/jpeg'
        %svg   'image/svg+xml'
        %ico   'image/x-icon'
        %woff2  'font/woff2'
      ==
    [[200 ~[['content-type' content-type]]] `octs]
  --
::
++  on-arvo
  |=  [=(pole knot) =sign-arvo]
  ^-  (quip card _this)
  ?+  pole  `this
  ::
      [%eyre %connect ~]
    ?>  ?=([%eyre %bound *] sign-arvo)
    ?:  accepted.sign-arvo
      %-  (slog leaf+"cast-ui: bound at /apps/cast" ~)
      `this
    %-  (slog leaf+"cast-ui: FAILED to bind at /apps/cast" ~)
    `this
  ==
::
++  on-watch
  |=  =(pole knot)
  ^-  (quip card _this)
  ?+    pole  (on-watch:def `path`pole)
      [%http-response eyre-id=@ta ~]
    `this
  ==
--
