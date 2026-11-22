# A recorded cl-stack-code session

This is the headless run from [README section 4](../README.md#4-work-on-it-with-the-cl-stack-harness), recorded on 2026-11-22.

- **Harness:** cl-stack-code 0.10.1, run through the lisp-workspace launcher.
- **Model:** `unsloth/Qwen3.8-Flash-Next-GGUF` (UD-IQ4_XS) on an Unsloth Studio server on the LAN, an OpenAI-compatible endpoint shared with other jobs. It used the server's default sampling.
- **Project:** a fresh clone of this repo, with this [`.cl-stack-code/settings.json`](../.cl-stack-code/settings.json). That file allows the project's edits, `cl-repo test` and a few read-only commands, and turns on the Lisp image (`"lispImage": {"image": "spawn"}`), which brings lisp-mcp's structural tools (`source-*`, `edit-*`, `repl-*`).

```bash
export OPENAI_BASE_URL=http://<host>:8888/v1 OPENAI_API_KEY=… OPENAI_MODEL=unsloth/Qwen3.8-Flash-Next-GGUF
cl-stack-code --model openai --permission-mode acceptEdits --output-format stream-json \
  -p "Add a w (week) unit to parse-duration, with tests. Run them."
```

**Outcome:** `"subtype":"success"`.

- **Cost:** 20 model calls in 859 s (this server is slow and shared); 18.2k input tokens plus 318k cached, 4.0k output tokens.
- **Tests:** the first `cl-repo test` passed, and so does a separate `cl-repo test` on the result.

## Tool calls

The table lists every tool call from the stream-json output: the step (model call), the tool, its main argument (the locator, for `edit-replace`), and the result status. `<project>` is the project's absolute path.

| Step | Tool | Argument | Status |
|---|---|---|---|
| 1 | `ls` |  | error |
| 1 | `glob` | **/*.lisp | done |
| 2 | `read` | src/duration.lisp | done |
| 2 | `read` | src/package.lisp | done |
| 3 | `read` | tests/duration-test.lisp | done |
| 3 | `grep` | d, h, m or s | done |
| 4 | `grep` | 86400\|3600\|\*units\*\|d, h | done |
| 4 | `bash` | ls -a && cat *.asd 2>/dev/null; ls src agent tests | done |
| 5 | `grep` | 1h30m | done |
| 6 | `source-read` | defparameter *units* | done |
| 7 | `edit-replace` | defparameter *units* | done |
| 8 | `read` | src/duration.lisp | done |
| 9 | `edit-replace` | line:23 | done |
| 10 | `edit-replace` | defun parse-duration | error |
| 11 | `edit-replace` | defun parse-duration | done |
| 12 | `edit-replace` | deftest-parametrize parse-duration-reads-units | done |
| 13 | `edit-replace` | line:13 | done |
| 14 | `read` | tests/duration-test.lisp | done |
| 15 | `edit-replace` | deftest format-duration-round-trips | done |
| 16 | `read` | agent/agent.lisp | done |
| 17 | `bash` | cl-repo test 2>&1 \| tail -40 | done |
| 18 | `bash` | cl-repo test --system cl-stack-sample/agent 2>&1 \| tail -15 | done |
| 19 | `grep` | README.md | done |
| 19 | `bash` | cd <project>/ && git --no-pager diff | denied |

What happened along the way:

- **Steps 1–6: reading.** The model read the library, the package and the tests with `read`, `grep` and lisp-mcp's `source-read`. None of these needs approval.
- **Steps 7–15: editing.** It made the changes with `edit-replace`, addressing whole forms (`defparameter *units*`, `defun parse-duration`, `deftest format-duration-round-trips`) or a line. The settings allow `edit-*` under `src/` and `tests/`.
- **Step 10: a refused edit.** The replacement for `defun parse-duration` was the docstring part only, so it did not read as balanced Lisp. The tool refused it: "Edit input does not read as balanced Lisp: While reading list, expected the character ) when input ended". The file stayed as it was. In step 11 the model sent the whole form.
- **Steps 17–18: testing.** It ran `cl-repo test` and `cl-repo test --system cl-stack-sample/agent`. Both passed.
- **Step 19: one denial.** `git --no-pager diff` matches no allow rule, so the headless run refused it, and the model wrote its answer.

## The final answer

> Done. `w` is now a first-class unit.
> 
> **`src/duration.lisp`**
> - `*units*` gained `(#\w . 604800)` at the front (list stays largest-first, so `format-duration`/`add-durations` emit weeks too).
> - The "missing unit" message now reads `(w, d, h, m or s)`, and the `parse-duration` docstring mentions `"1w"`.
> 
> Parsing is case-insensitive via the existing `char-downcase`, so `1W` works; no other code changed.
> 
> **`tests/duration-test.lisp`**
> - `parse-duration-reads-units`: `"1w"` → 604800, `"1W"` → 604800, `"1w2d 3h"` → 788400.
> - `format-duration-round-trips`: `(format-duration 604800)` → `"1w"`, `(format-duration (parse-duration "1w 24h"))` → `"1w1d"`, `(add-durations "5d" "2d")` → `"1w"`.
> 
> **Runs**
> - `cl-repo test` → all passed (including the new week cases).
> - `cl-repo test --system cl-stack-sample/agent` → all passed (unchanged, checked for regressions).

## The change

```diff
diff --git a/src/duration.lisp b/src/duration.lisp
index 3ab5f37..72e33da 100644
--- a/src/duration.lisp
+++ b/src/duration.lisp
@@ -1,7 +1,7 @@
 (in-package #:cl-stack-sample)
 
 (defparameter *units*
-  '((#\d . 86400) (#\h . 3600) (#\m . 60) (#\s . 1))
+  '((#\w . 604800) (#\d . 86400) (#\h . 3600) (#\m . 60) (#\s . 1))
   "Unit letters and their length in seconds, largest first.")
 
 (declaim (ftype (function (string) (values (integer 0) &optional)) %parse-duration))
@@ -20,7 +20,7 @@
           (unless n (fail "expected a number"))
           (when (minusp n) (fail "negative amount"))
           (setf pos next)
-          (when (>= pos end) (fail "missing unit (d, h, m or s)"))
+          (when (>= pos end) (fail "missing unit (w, d, h, m or s)"))
           (let ((unit (assoc (char-downcase (char text pos)) *units*)))
             (unless unit (fail (format nil "unknown unit ~s" (char text pos))))
             (incf total (* n (cdr unit)))
@@ -30,7 +30,7 @@
       total)))
 
 (defun parse-duration (text)
-  "Seconds in TEXT such as \"1h30m\", \"45s\" or \"2d 4h\".
+  "Seconds in TEXT such as \"1h30m\", \"45s\", \"2d 4h\" or \"1w\".
 Signals INVALID-DURATION with a USE-VALUE restart: invoke it with the
 number of seconds to return instead."
   (check-type text string)
diff --git a/tests/duration-test.lisp b/tests/duration-test.lisp
index 2dabbac..12c00d0 100644
--- a/tests/duration-test.lisp
+++ b/tests/duration-test.lisp
@@ -8,6 +8,9 @@
      ("45s" 45)
      ("1h30m" 5400)
      ("2d 4h" 187200)
+     ("1w" 604800)
+     ("1W" 604800)
+     ("1w2d 3h" 788400)
      ("1H" 3600)
      ("  90m  " 5400))
   (ok (= seconds (parse-duration text))))
@@ -28,6 +31,9 @@
   (ok (equal "0s" (format-duration 0)))
   (ok (equal "1h30m" (format-duration 5400)))
   (ok (equal "2d4h" (format-duration (parse-duration "2d 4h"))))
+  (ok (equal "1w" (format-duration 604800)))
+  (ok (equal "1w1d" (format-duration (parse-duration "1w 24h"))))
+  (ok (equal "1w" (add-durations "5d" "2d")))
   (ok (equal "1h45m" (add-durations "1h" "45m"))))
 
 (deftest use-value-restart-recovers
```

## Independent check

`cl-repo test` in the project after the run:

```text
  ✓ Expect (EQUAL "1w" (FORMAT-DURATION 604800)) to be true.
  ✓ Expect (EQUAL "1w1d" (FORMAT-DURATION (PARSE-DURATION "1w 24h"))) to be true.
  ✓ Expect (EQUAL "1w" (ADD-DURATIONS "5d" "2d")) to be true.
  All 1 test passed.
```

## The same session without the Lisp image

An earlier run used the same prompt and model, but without `lispImage`, so only the plain `edit` tool was available. It also succeeded, but it took 23 model calls and 1181 s. In one step it sent two `edit` calls on `src/duration.lisp`. Both reported `done`, but the second overwrote the first, so the `*units*` change was lost ([cl-stack-code#30](https://github.com/egao1980/cl-stack-code/issues/30)). The first test run failed, and the model found the lost edit and applied it again.
