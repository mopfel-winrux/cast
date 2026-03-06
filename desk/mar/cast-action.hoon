/-  cast
|_  act=action:cast
++  grow
  |%
  ++  noun  act
  --
++  grab
  |%
  ++  noun  action:cast
  ++  json
    |=  jon=json
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
++  grad  %noun
--
