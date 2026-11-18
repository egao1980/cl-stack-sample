# Agent instructions

A small Common Lisp library (`cl-stack-sample`: durations like `1h30m`) and an agent that uses it (`cl-stack-sample/agent`).

**Claude Code** gets the cl-stack conventions, skills and the `lisp-mcp` server from the `lisp-workspace` plugin, which `.claude/settings.json` enables. Trust the folder and accept the plugin prompt. **Other agents:** read [lisp-workspace/plugin/context.md](https://github.com/egao1980/lisp-workspace/blob/main/plugin/context.md) and the skills in that repo.

## This project

- **Test:** run `cl-repo test` for the library and `cl-repo test --system cl-stack-sample/agent` for the agent. Never use Quicklisp or `CL_SOURCE_REGISTRY`.
- **Layout:** `src/` is the library, `agent/` is the agent, and `tests/` holds one Rove file per system.
- **Errors:** `invalid-duration` (under `duration-error`) with a `use-value` restart. `parse-durations` shows the policy side: a `handler-bind` that invokes the restart. Keep new errors in that tree, with restarts at the lowest site that can recover.
- **Agent tools:** a tool turns library errors into `tool-input-error`, so the model is told to fix its arguments.
- **Edits:** change `.lisp` and `.asd` files through lisp-mcp `edit-*` tools.
- **Branches:** name feature branches `agent/<topic>-<4 hex>`.
