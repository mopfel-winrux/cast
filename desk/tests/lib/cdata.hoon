/+  *test, rss
|%
++  test-tag-space-before-close
  ::  space before > like <foo bar="x" >
  %+  expect-eq
    !>(%.y)
    !>(?=(^ (de-xml:html (sanitize-xml:rss '<root><foo bar="x" ></foo></root>'))))
::
++  test-xmlns-attr
  ::  xmlns attribute on element
  =/  xml=tape
    "<root><link xmlns='http://www.w3.org/2005/Atom'>text</link></root>"
  %+  expect-eq
    !>(%.y)
    !>(?=(^ (de-xml:html (crip xml))))
::
++  test-rawvoice-tag
  ::  rawvoice:subscribe with many attrs and space before >
  =/  xml=@t
    %-  crip
    "<rss><channel><rawvoice:subscribe feed='x' android='y' ></rawvoice:subscribe><title>T</title></channel></rss>"
  %+  expect-eq
    !>(%.y)
    !>(?=(^ (de-xml:html (sanitize-xml:rss xml))))
::
++  test-double-space-attr
  ::  double space between attrs
  =/  xml=tape
    "<rss><channel><foo bar='x'  baz='y'></foo><title>T</title></channel></rss>"
  %+  expect-eq
    !>(%.y)
    !>(?=(^ (de-xml:html (crip xml))))
::
++  test-sanitize-martyrmade-mini
  ::  minimal version of martyrmade feed structure
  =/  xml=@t
    %-  crip
    ;:  weld
      "<rss xmlns:rawvoice='https://example.com' xmlns:itunes='http://example.com'>"
      "<channel>"
      "<rawvoice:subscribe feed='x' android='y' ></rawvoice:subscribe>"
      "<title>The Podcast</title>"
      "<link>https://example.com</link>"
      "<link rel='self' href='https://example.com/feed' xmlns='http://www.w3.org/2005/Atom'>https://example.com</link>"
      "<itunes:new-feed-url>https://example.com/feed</itunes:new-feed-url>"
      "<itunes:image href='https://example.com/img.jpg' />"
      "<item><title>Ep</title><guid>g1</guid>"
      "<enclosure url='https://example.com/ep.mp3' type='audio/mpeg' />"
      "<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>"
      "</item></channel></rss>"
    ==
  %+  expect-eq
    !>(%.y)
    !>(?=(^ (de-xml:html (sanitize-xml:rss xml))))
--
