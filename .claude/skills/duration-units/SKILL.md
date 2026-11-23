---
name: duration-units
description: >-
  How parse-duration and format-duration in cl-stack-sample read and write
  units (d, h, m, s), and how to add or fix a unit with a test. Use before
  changing *units*, %parse-duration or tests/duration-test.lisp.
---

# Duration units

`src/duration.lisp` has one table, `*units*`: an alist of a unit letter and its
length in seconds, **largest first**. Both directions read it:

- `%parse-duration` walks the text: optional spaces, a number, one unit
  letter. The letter is looked up with `char-downcase`, so `1H` is `1h`.
  An unknown letter signals `invalid-duration` with the reason
  `unknown unit #\x`.
- `format-duration` walks the table in order and prints each non-zero part,
  so the order of the table is the order of the output (`2d4h`).

## Add a unit

1. Add `(#\w . 604800)` at its place in `*units*`: sorted by length, largest
   first. Nothing else in the parser changes.
2. Update the `missing unit (d, h, m or s)` message in `%parse-duration`.
3. Tests in `tests/duration-test.lisp` (Rove, `deftest-parametrize`):
   - a row in `parse-duration-reads-units`, e.g. `("1w 2d" 777600)`;
   - a round trip in `format-duration-round-trips`, e.g.
     `(ok (equal "1w" (format-duration 604800)))`.
4. Run `cl-repo test`. All tests must pass.

## Fix a unit bug

Read the failing test first: `cl-repo test` names the row. Fix the code, not
the test, unless the test is wrong about the documented behaviour (the
docstrings of `parse-duration` and `format-duration`). Keep errors in the
`duration-error` tree with the `use-value` restart (rule `lisp.md`).
