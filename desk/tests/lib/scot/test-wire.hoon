/+  *test
|%
++  test-scot-t-with-slashes
  =/  url=@t  'https://vonupodcast.com/feed/podcast/'
  =/  wire=path  /fetch/subscribe/(scot %uv 0v1234)/(scot %t url)
  ::  check that the wire has exactly 4 segments
  =/  seg-count=@ud  (lent wire)
  (expect-eq !>(4) !>(seg-count))
--
