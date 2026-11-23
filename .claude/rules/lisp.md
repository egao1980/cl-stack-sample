---
paths:
  - "**/*.lisp"
---

# Lisp files in cl-stack-sample: conditions and restarts

- Errors are conditions under `duration-error` (`src/conditions.lisp`), with
  slots and a `:report`. No `(error "string")` and no new error dialect.
- Signal where the problem is detected. Put the restart at the lowest site
  that can recover: `parse-duration` offers `use-value`.
- Policy lives above, in `handler-bind` that invokes a restart
  (`parse-durations`). Use `handler-case` only to unwind or translate
  (the agent's tools turn library errors into `tool-input-error`).
- No `ignore-errors` and no catch-all `(error (c) …)` in library code.
- A new error gets a test that checks its type and its slots.
