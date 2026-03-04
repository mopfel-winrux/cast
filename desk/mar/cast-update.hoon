/-  cast
|_  upd=update:cast
++  grow
  |%
  ++  noun  upd
  ++  json
    ^-  json
    =,  enjs:format
    ?-  -.upd
        %podcast-added
      %-  pairs
      :~  ['type' s+'podcast-added']
          ['podcast-id' s+(scot %uv podcast-id.upd)]
          :-  'podcast'
          (podcast-to-json podcast.upd)
          :-  'episodes'
          :-  %a
          %+  turn  episodes.upd
          |=  [eid=episode-id:cast ep=episode:cast]
          %-  pairs
          :~  ['id' s+(scot %uv eid)]
              (episode-to-pairs ep)
          ==
      ==
    ::
        %podcast-removed
      %-  pairs
      :~  ['type' s+'podcast-removed']
          ['podcast-id' s+(scot %uv podcast-id.upd)]
      ==
    ::
        %episodes-updated
      %-  pairs
      :~  ['type' s+'episodes-updated']
          ['podcast-id' s+(scot %uv podcast-id.upd)]
          :-  'new-episodes'
          :-  %a
          %+  turn  new-episodes.upd
          |=  [eid=episode-id:cast ep=episode:cast]
          %-  pairs
          :~  ['id' s+(scot %uv eid)]
              (episode-to-pairs ep)
          ==
      ==
    ::
        %position-updated
      %-  pairs
      :~  ['type' s+'position-updated']
          ['episode-id' s+(scot %uv episode-id.upd)]
          ['position' (numb position.upd)]
      ==
    ::
        %played-updated
      %-  pairs
      :~  ['type' s+'played-updated']
          ['episode-id' s+(scot %uv episode-id.upd)]
          ['played' b+played.upd]
      ==
    ::
        %queue-updated
      %-  pairs
      :~  ['type' s+'queue-updated']
          :-  'queue'
          :-  %a
          %+  turn  queue.upd
          |=  [=podcast-id:cast =episode-id:cast]
          %-  pairs
          :~  ['podcast-id' s+(scot %uv podcast-id)]
              ['episode-id' s+(scot %uv episode-id)]
          ==
      ==
    ::
        %settings-updated
      %-  pairs
      :~  ['type' s+'settings-updated']
          (settings-to-pairs settings.upd)
      ==
    ::
        %current-updated
      %-  pairs
      :~  ['type' s+'current-updated']
          :-  'current'
          ?~  current.upd  ~
          %-  pairs
          :~  ['podcast-id' s+(scot %uv podcast-id.u.current.upd)]
              ['episode-id' s+(scot %uv episode-id.u.current.upd)]
          ==
      ==
    ::
        %download-complete
      %-  pairs
      :~  ['type' s+'download-complete']
          ['episode-id' s+(scot %uv episode-id.upd)]
      ==
    ==
  --
++  grab
  |%
  ++  noun  update:cast
  --
++  grad  %noun
::
::  helper arms
::
++  podcast-to-json
  |=  pod=podcast:cast
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['feed-url' s+feed-url.pod]
      ['title' s+title.pod]
      ['author' s+author.pod]
      ['description' s+description.pod]
      ['image-url' s+image-url.pod]
      ['link' s+link.pod]
      ['last-fetched' (sect last-fetched.pod)]
  ==
::
++  episode-to-pairs
  |=  ep=episode:cast
  ^-  [[@t json] [@t json] [@t json] [@t json] [@t json] [@t json] [@t json] ~]
  =,  enjs:format
  :~  ['title' s+title.ep]
      ['description' s+description.ep]
      ['audio-url' s+audio-url.ep]
      ['pub-date' (sect pub-date.ep)]
      ['duration' (numb duration.ep)]
      ['guid' s+guid.ep]
      ['image-url' s+image-url.ep]
  ==
::
++  settings-to-pairs
  |=  set=settings:cast
  ^-  [[@t json] [@t json] [@t json] ~]
  =,  enjs:format
  :~  ['playback-speed' (numb playback-speed.set)]
      ['auto-download' b+auto-download.set]
      ['refresh-interval' (numb (div (msec:milly refresh-interval.set) 1.000))]
  ==
::
++  milly
  |%
  ++  msec
    |=  =@dr
    ^-  @ud
    (div dr (div ~s1 1.000))
  --
--
