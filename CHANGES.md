# Changelog

## 2.0.0

*   Rewrite `Kernel#with_retries` to `Retries.run`.
*   Replace `Retries.sleep_enabled` with `Retries.options` (Hash with defaults).
*   Replace Minitest tests with RSpec specs.
*   Add RuboCop and resolve offenses.
*   Update dependencies.
*   Require Ruby 2.4 or newer.
*   Resolve gem building warnings (add license field).
*   Add EditorConfig file.

## 0.0.5

* Bugfix for when `:rescue` isn't specified (@hlascelles).
* Add a contributors list.

## 0.0.4

* Add `total_delay` to the exception handler arguments (@mmazour).

## 0.0.3

* Update published homepage link in the gem.

## 0.0.2

* Add `Retries.sleep_enabled` for disabling sleeps in tests.
* Better Readme.

## 0.0.1

* Initial version
