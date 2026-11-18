# cl-stack-sample

A sample Common Lisp project on [cl-stack](https://github.com/egao1980/cl-stack). It shows three things working together:

| | What | Where |
|---|---|---|
| **cl-repo** | dependencies from OCI (GHCR), tests in a fresh image, CI with the canned workflow; no Quicklisp | `cl-stack-sample.asd`, `.github/workflows/test.yml` |
| **lisp-mcp** | the agent reads, edits (never unbalanced), compiles and debugs Lisp through MCP | from the `lisp-workspace` plugin |
| **Agentic configuration** | cl-stack conventions, Common Lisp skills and the MCP server as a Claude Code plugin | `.claude/settings.json`, `AGENTS.md` |

The code is deliberately small:

- **`cl-stack-sample`** parses and adds durations (`"1h30m"`, `"2d 4h"`). Errors follow CLHS 9: an `invalid-duration` condition with a `use-value` restart, and a `handler-bind` policy in `parse-durations`.
- **`cl-stack-sample/agent`** is an [`ai-agent-protocol`](https://github.com/egao1980/ai-agent-protocol) agent whose one tool is that library. A bad duration reaches the model as a `tool-input-error`, so it fixes its arguments and calls again.

## 1. Toolchain

```bash
brew install roswell oras       # or https://roswell.github.io/ and https://oras.land/
ros install sbcl-bin
curl -fsSL https://raw.githubusercontent.com/egao1980/cl-repository/main/install.sh | bash
```

The installer puts the cl-repository client in `~/.cl-repository-client` and the `cl-repo` command in `~/.local/bin`. It needs python3, used only to read OCI manifests.

## 2. Build and test

```bash
cl-repo test                                  # library: Rove, fresh SBCL image
cl-repo test --system cl-stack-sample/agent   # agent: mock LLM, offline
```

`cl-repo sync` installs every `:depends-on` from `ghcr.io/egao1980/cl-systems`. Nothing goes in `CL_SOURCE_REGISTRY`, and there is no `ql:quickload`. CI runs the same two commands through [`test-system.yml`](https://github.com/egao1980/cl-repository/blob/main/.github/workflows/test-system.yml).

## 3. Work on it with Claude Code

```bash
claude
```

Trust the folder. Claude Code then offers the `lisp-workspace` plugin from the `cl-stack` marketplace, because [`.claude/settings.json`](.claude/settings.json) lists both. To install it by hand:

```text
/plugin marketplace add egao1980/lisp-workspace
/plugin install lisp-workspace@cl-stack
```

The plugin brings:

- **Conventions** as session context: cl-repo only, Rove, conditions and restarts, own stack first.
- **Skills** such as `lisp-workspace:asdf`, `lisp-workspace:cl-unit-testing`, `lisp-workspace:cl-stack-conditions` and `lisp-workspace:lisp-mcp-tooling`.
- **The `lisp-mcp` server**, rooted at this project. On first use it builds a fast-start executable in `~/.cache/lisp-mcp/`; run `/mcp` to reconnect once it's ready.

Try:

```text
Add a "w" (week) unit to parse-duration, with tests. Run them.
```

The agent should:
1. Read `src/duration.lisp` with `source-read`.
2. Change `*units*` and the tests with `edit-*` tools. These refuse unbalanced writes and can compile as they write.
3. Run `cl-repo test`, or `repl-run-tests` in a live image. A long run comes back as a job id instead of timing out.

Other agents (Cursor, Codex) read [`AGENTS.md`](AGENTS.md), which points to the same conventions and skills.

## 4. Run the agent live

With `ANTHROPIC_API_KEY` set:

```bash
cl-repo run -- ros run \
  -e '(asdf:load-system "cl-stack-sample/agent")' \
  -e '(print (cl-stack-sample/agent:ask "How long is 1h30m plus 45m plus 2d?"))' \
  -e '(uiop:quit)'
```

`ask` uses Anthropic (`claude-opus-5-5`) over the cl-stack async HTTP backend. Retries follow the failure class, and the run stops after 6 steps. Pass `:backend` to use any other `llm-protocol` backend. To build a longer-running agent, with compaction, permissions, subagents and `AGENTS.md` discovery, see the [agent harness tutorial](https://github.com/egao1980/cl-stack/blob/main/docs/tutorials/agent-harness.md).

## Layout

```text
cl-stack-sample.asd      4 systems: library, tests, agent, agent tests
src/                     package, conditions, duration
agent/agent.lisp         the add_durations tool and the agent
tests/                   Rove: duration-test, agent-test
.claude/settings.json    cl-stack marketplace + lisp-workspace plugin
AGENTS.md / CLAUDE.md    project notes for agents
.github/workflows/       cl-repository test-system.yml, library + agent
```

MIT licensed.
