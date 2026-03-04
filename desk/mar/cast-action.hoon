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
    ==
  --
++  grad  %noun
--
