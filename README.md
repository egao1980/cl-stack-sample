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

`cl-repo sync`, which `test` and `run` call first, installs the `:depends-on` of every system in the `.asd` (library, tests, agent) from `ghcr.io/egao1980/cl-systems`. This needs cl-repo client 0.27.17 or later. Nothing goes in `CL_SOURCE_REGISTRY`, and there is no `ql:quickload`. CI runs the same two commands through [`test-system.yml`](https://github.com/egao1980/cl-repository/blob/main/.github/workflows/test-system.yml).

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

```bash
export ANTHROPIC_API_KEY=…                 # default provider
cl-repo run -- ros run \
  -e '(asdf:load-system "cl-stack-sample/agent")' \
  -e '(print (cl-stack-sample/agent:ask "How long is 1h30m plus 45m plus 2d?"))' \
  -e '(uiop:quit)'
```

`ask` runs over the cl-stack async HTTP backend. It retries by failure class and stops after 6 steps. For a longer-running agent, with compaction, permissions, subagents and `AGENTS.md` discovery, see the [agent harness tutorial](https://github.com/egao1980/cl-stack/blob/main/docs/tutorials/agent-harness.md).

### Choose the model provider

A provider is named by a designator: `"provider"` or `"provider:model"`. The model is everything after the first colon, so `"ollama:llama3.1:8b"` works. It is set by, in order of precedence:

1. `(ask question :llm "openai:gpt-4o")`, or `(make-duration-agent :llm "…")`;
2. `(setf cl-stack-sample/agent:*default-llm* "…")`;
3. the `SAMPLE_LLM` environment variable;
4. `"anthropic"`.

| Provider | Designator | Endpoint | Credentials | Default model |
|----------|------------|----------|-------------|---------------|
| Anthropic | `anthropic[:model]` | `ANTHROPIC_BASE_URL`, else `api.anthropic.com` | `ANTHROPIC_API_KEY` | `claude-opus-5-5` |
| OpenAI | `openai[:model]` | `api.openai.com/v1` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| OpenRouter | `openrouter[:vendor/model]` | `openrouter.ai/api/v1` | `OPENROUTER_API_KEY` | `openai/gpt-4o-mini` |
| Any OpenAI-compatible server | `openai-compat[:model]` | `OPENAI_BASE_URL` | `OPENAI_API_KEY` | `OPENAI_MODEL` |
| LM Studio | `lmstudio[:model]` | `127.0.0.1:1234/v1` | `LM_API_TOKEN` when its server auth is on | give the loaded model id (`lms ls`) |
| Ollama | `ollama[:model]` | `127.0.0.1:11434/v1` | none | give one, e.g. `ollama:llama3.1:8b` |
| vLLM | `vllm[:model]` | `127.0.0.1:8000/v1` | none | give the served model |
| Offline echo | `mock` | none | none | none |

```bash
# the same command, other providers:
SAMPLE_LLM=openai:gpt-4o OPENAI_API_KEY=…            cl-repo run -- ros run …
SAMPLE_LLM=lmstudio:qwen/qwen3.8-27b LM_API_TOKEN=… cl-repo run -- ros run …
SAMPLE_LLM=ollama:llama3.1:8b                        cl-repo run -- ros run …
SAMPLE_LLM=mock                                      cl-repo run -- ros run …   # offline: "echo: …"
```

Without a model, the OpenAI-compatible providers send `OPENAI_MODEL`, or `gpt-4o-mini` when that is unset, so name the model for local servers. The model must support tool calls. Small local models sometimes answer without calling `add_durations`.

**Add a provider.** `*providers*` holds entries of the form `(name kind base-url api-key-env default-model)`. `kind` is `:anthropic` ([`llm-protocol-anthropic`](https://github.com/egao1980/llm-protocol-anthropic)), `:openai` ([`llm-protocol-openai`](https://github.com/egao1980/llm-protocol-openai), chat completions) or `:mock`. Push a new entry:

```lisp
(push '("groq" :openai "https://api.groq.com/openai/v1" "GROQ_API_KEY" "llama-3.3-70b-versatile")
      cl-stack-sample/agent:*providers*)
```

**Use any backend object.** `:backend` takes any `llm-protocol` backend, such as llama.cpp in-process (`llm-backend-llama-cpp`) or one from a provider catalog (`stack-llm:resolve-backend`). It bypasses designators:

```lisp
(cl-stack-sample/agent:ask "…" :backend (stack-llm-anthropic:make-vllm-anthropic-backend))
```

**Unknown provider.** `make-llm-backend` signals `llm-protocol:llm-unknown-provider`, listing the known names. Its `use-value` restart takes a backend to use instead, so a caller can fall back without unwinding:

```lisp
(handler-bind ((stack-llm:llm-unknown-provider
                 (lambda (c) (use-value (stack-llm:make-mock-llm-backend) c))))
  (cl-stack-sample/agent:make-llm-backend "nosuch"))
```

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
