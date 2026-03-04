|%
::  identifiers
::
+$  podcast-id  @uv
+$  episode-id  @uv
::
::  podcast channel metadata
::
+$  podcast
  $:  feed-url=@t
      title=@t
      author=@t
      description=@t
      image-url=@t
      link=@t
      last-fetched=@da
  ==
::
::  single episode
::
+$  episode
  $:  title=@t
      description=@t
      audio-url=@t
      pub-date=@da
      duration=@ud
      guid=@t
      image-url=@t
  ==
::
::  per-episode user state
::
+$  episode-state
  $:  played=?
      position=@ud
      downloaded=?
  ==
::
::  playback queue
::
+$  queue  (list [=podcast-id =episode-id])
::
::  user preferences
::
+$  settings
  $:  playback-speed=@ud
      auto-download=?
      refresh-interval=@dr
  ==
::
::  agent state
::
+$  state-0
  $:  %0
      podcasts=(map podcast-id podcast)
      episodes=(map podcast-id (map episode-id episode))
      estate=(map episode-id episode-state)
      =queue
      =settings
      cache=(map episode-id octs)
      current=(unit [=podcast-id =episode-id])
      archived=(set episode-id)
  ==
::
::  poke actions
::
+$  action
  $%  [%subscribe url=@t]
      [%unsubscribe =podcast-id]
      [%refresh =podcast-id]
      [%refresh-all ~]
      [%set-position =episode-id position=@ud]
      [%set-played =episode-id played=?]
      [%enqueue =podcast-id =episode-id]
      [%dequeue =podcast-id =episode-id]
      [%set-current =podcast-id =episode-id]
      [%clear-current ~]
      [%download =podcast-id =episode-id]
      [%set-settings =settings]
      [%import-opml urls=(list @t)]
      [%add-episode =podcast-id title=@t audio-url=@t]
      [%set-archived =episode-id archived=?]
      [%mark-all-played =podcast-id]
      [%mark-all-unplayed =podcast-id]
      [%archive-all =podcast-id]
      [%unarchive-all =podcast-id]
  ==
::
::  subscription updates
::
+$  update
  $%  [%podcast-added =podcast-id =podcast episodes=(list [=episode-id =episode])]
      [%podcast-removed =podcast-id]
      [%episodes-updated =podcast-id new-episodes=(list [=episode-id =episode])]
      [%position-updated =episode-id position=@ud]
      [%played-updated =episode-id played=?]
      [%queue-updated =queue]
      [%settings-updated =settings]
      [%current-updated current=(unit [=podcast-id =episode-id])]
      [%download-complete =episode-id]
      [%archived-updated =episode-id archived=?]
      [%bulk-played-updated =podcast-id played=?]
  ==
--
