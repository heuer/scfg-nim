Changes
=======

0.4.0 -- 2026-07-09
-------------------
* Fixed bug where ``directive{`` (no whitespace between name and ``{``
  is silently accepted as start of a block
* Improved error messages
* Updated scfg test suite


0.3.0 -- 2026-02-18
-------------------
* Event/streaming API set as default
* Removed ``Block`` and ``Directive`` from the API (moved to examples)
* Removed various helper functions to minimize the API


0.2.4 -- 2026-02-18
-------------------
* Improved error messages
* Avoided unnecessary variable assignments


0.2.3 -- 2026-02-11
-------------------
* Added ``has_block`` to ``ScfgEvent`` to simplify deserialization


0.2.2 -- 2026-02-11
-------------------
* Added test cases, updated README; no code changes


0.2.1 -- 2026-02-11
-------------------
* Introduced an event-based API


0.2.0 -- 2026-01-30
-------------------
* Initial release

