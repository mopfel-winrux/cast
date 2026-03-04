/+  *test, rss
|%
++  test-parse-iso8601-tz
  %+  expect-eq
    !>(`~2026.3.4..18.00.48)
    !>((parse-iso8601:rss '2026-03-04T18:00:48+00:00'))
::
++  test-parse-iso8601-empty
  %+  expect-eq
    !>(~)
    !>((parse-iso8601:rss ''))
::
++  test-parse-iso8601-z
  %+  expect-eq
    !>(`~2008.11.25..00.46.52)
    !>((parse-iso8601:rss '2008-11-25T00:46:52+00:00'))
::
++  test-parse-rfc2822-leading-zero
  %+  expect-eq
    !>(`~2024.1.1)
    !>((parse-rfc2822:rss 'Mon, 01 Jan 2024 00:00:00 GMT'))
::
++  test-parse-rfc2822-no-leading-zero
  %+  expect-eq
    !>(`~2024.1.1)
    !>((parse-rfc2822:rss 'Mon, 1 Jan 2024 00:00:00 GMT'))
::
++  test-parse-rfc2822-no-dow
  %+  expect-eq
    !>(`~2024.6.15..14.30.00)
    !>((parse-rfc2822:rss '15 Jun 2024 14:30:00 GMT'))
::
++  test-parse-duration-seconds
  %+  expect-eq
    !>(`3.600)
    !>((parse-duration:rss '3600'))
::
++  test-parse-duration-mmss
  %+  expect-eq
    !>(`2.730)
    !>((parse-duration:rss '45:30'))
::
++  test-parse-duration-hhmmss
  %+  expect-eq
    !>(`3.600)
    !>((parse-duration:rss '1:00:00'))
::
++  test-parse-duration-padded
  %+  expect-eq
    !>(`90)
    !>((parse-duration:rss '01:30'))
--
