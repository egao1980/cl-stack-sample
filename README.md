# cl-stack-sample

A sample Common Lisp project on [cl-stack](https://github.com/egao1980/cl-stack). It shows four things working together:

| | What | Where |
|---|---|---|
| **cl-repo** | dependencies from OCI (GHCR), tests in a fresh image, CI with the canned workflow; no Quicklisp | `cl-stack-sample.asd`, `.github/workflows/test.yml` |
| **lisp-mcp** | the agent reads, edits (never unbalanced), compiles and debugs Lisp through MCP | from the `lisp-workspace` plugin |
| **Agentic configuration** | cl-stack conventions, Common Lisp skills and the MCP server as a Claude Code plugin | `.claude/settings.json`, `AGENTS.md` |
| **cl-stack-code** | the cl-stack coding agent CLI works on the project: interactive and headless `-p`, permission rules, lisp-mcp structural edits | `.cl-stack-code/settings.json`, section 4 |

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

`cl-repo sync`, which `test`, `run` and `ros` call first, installs the `:depends-on` of every system in the `.asd` (library, tests, agent) from `ghcr.io/egao1980/cl-systems`. This needs cl-repo client 0.27.17 or later (0.27.20 for `cl-repo ros`); the sample is tested with 0.27.39. Nothing goes in `CL_SOURCE_REGISTRY`, and there is no `ql:quickload`. CI runs the same two commands through [`test-system.yml`](https://github.com/egao1980/cl-repository/blob/main/.github/workflows/test-system.yml).

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
- **The `lisp-mcp` server** (0.7.3, as two MCP servers: `lisp-code` for reading and structural edits, `lisp-image` for live images), rooted at this project. On first use it builds a fast-start executable in `~/.cache/lisp-mcp/`; run `/mcp` to reconnect once it's ready.

Try:

```text
Add a "w" (week) unit to parse-duration, with tests. Run them.
```

The agent should:
1. Read `src/duration.lisp` with `source-read`.
2. Change `*units*` and the tests with `edit-*` tools. These refuse unbalanced writes and can compile as they write.
3. Run `cl-repo test`, or `repl-run-tests` in a live image. A long run comes back as a job id instead of timing out.

Other agents (Cursor, Codex) read [`AGENTS.md`](AGENTS.md), which points to the same conventions and skills.

## 4. Work on it with the cl-stack harness

[`cl-stack-code`](https://github.com/egao1980/cl-stack-code) is a coding agent written on cl-stack. It runs in the terminal, interactively or headless with `-p`, and works with any Anthropic or OpenAI-compatible model.

### Get the launcher

The launcher, `cl-stack-code.sh`, installs the published cl-stack-code from GHCR and runs it as a fast-start executable. It needs the toolchain from section 1. Get it in one of these ways:

- **Direct download** (the simplest):

  ```bash
  mkdir -p ~/.local/bin
  curl -fsSL https://raw.githubusercontent.com/egao1980/lisp-workspace/main/scripts/cl-stack-code.sh \
    -o ~/.local/bin/cl-stack-code && chmod +x ~/.local/bin/cl-stack-code
  ```

- **The `lisp-workspace` plugin** (section 3): the launcher is at `~/.claude/plugins/marketplaces/cl-stack/scripts/cl-stack-code.sh`.
- **The `lisp-workspace` submodule** (cl-workspace): `.lisp-workspace/scripts/cl-stack-code.sh`.

Build the executable once. It takes about two minutes, and later starts take well under a second:

```bash
cl-stack-code --which      # → ~/.cache/cl-stack-code/cl-stack-code-0.14.0-sbcl-bin-<version>
cl-stack-code --help
```

The launcher pins the cl-stack-code version (0.14.0). A new pin or a new SBCL builds a new executable. More in the [lisp-workspace README](https://github.com/egao1980/lisp-workspace#cl-stack-code-harness).

### Configure a model

`--model provider` or `--model provider:model`. The default is `anthropic`. Credentials come from the environment, never from the project's settings:

```bash
# Anthropic
export ANTHROPIC_API_KEY=…                  # optional: ANTHROPIC_MODEL, ANTHROPIC_BASE_URL

# any OpenAI-compatible server: OpenAI, LM Studio, llama.cpp, vLLM, Unsloth Studio, …
export OPENAI_BASE_URL=http://localhost:1234/v1 OPENAI_API_KEY=… OPENAI_MODEL=<model id>
cl-stack-code --model openai …
```

If the model id has a colon in it (`org/model:quant`), set `OPENAI_MODEL` and pass `--model openai`, because `provider:model` splits at the first colon. The model must support tool calls.

### Project settings: `.cl-stack-code/settings.json`

The project's [`.cl-stack-code/settings.json`](.cl-stack-code/settings.json) does two things.

**Turns on the Lisp image** (`"lispImage": {"image": "spawn"}`). cl-stack-code starts a Swank image next to the session. It also offers [lisp-mcp](https://github.com/egao1980/lisp-mcp)'s tools alongside its file and shell tools:

- `source-read` and `source-outline`, which read code without evaluating it;
- `edit-replace` and the other structural edits, which address a form (`defun parse-duration`) and refuse a write that would unbalance the file;
- the `repl-*` and `debug-*` tools.

**Allows these without asking:**

- reading anywhere in the project;
- editing `src/`, `tests/` and `agent/`, with the file tools or the `edit-*` tools;
- `cl-repo test`, plus `repl-load-system` and `repl-run-tests` for this project's systems;
- a few read-only shell commands: `git status`, `git diff`, `git log`, `ls`, `cat`, `head`, `tail`, `grep`, `wc` and `sed -n`.

It denies `.env`, `git push` and `cl-repo publish`. Anything else asks in the terminal. A headless run can't ask, so it refuses those calls and tells the model which flag would allow them.

A shell call is allowed only when every part of it is allowed. Each simple command has two parts, `bash:<words>` and `program:<argv0>`, so `cl-repo test` needs two rules: `bash(cl-repo test *)` and `bash(program:cl-repo)`. Put personal rules in `.cl-stack-code/settings.local.json` (gitignored) or `~/.config/cl-stack-code/settings.json`. Keys never go in settings: they come from the environment.

### Interactive

```bash
cl-stack-code --model openai
```

This opens a terminal session. You get a streamed transcript, `@` file mentions, approval dialogs for anything the rules don't allow, `/ps` for background jobs, and `-c` / `-r ID` to continue a session later.

### Headless: add a week unit

```bash
cl-stack-code --model openai --permission-mode acceptEdits \
  -p "Add a w (week) unit to parse-duration, with tests. Run them."
```

`acceptEdits` allows file edits. The settings file allows `cl-repo test`. Without that file, add the rules on the command line: `--allowed-tools 'bash(cl-repo test *) bash(program:cl-repo)'`. Add `--output-format stream-json` to see each tool call as a JSON line.

A recorded run is in [`docs/harness-session.md`](docs/harness-session.md). The model read the code with `source-read`. It added `(#\w . 604800)` to `*units*` and new test cases with `edit-replace`, which refused one unbalanced edit. Then `cl-repo test` passed on the first run. It took 20 model calls, about 14 minutes on a slow, shared local server. The [cl-stack-demos `harness/sample`](https://github.com/egao1980/cl-stack-demos/tree/main/harness/sample) demo repeats the session from a fresh clone.


### Skills and rules

cl-stack-code (0.12.0 and later) reads the same agent configuration as Claude Code:

- **`AGENTS.md`**, and `CLAUDE.md`, which imports it with `@AGENTS.md`.
- **Skills** in `.claude/skills/<name>/SKILL.md` (also `.cl-stack-code/skills/`). Their descriptions are in the system prompt; the model loads one with the `skill` tool. This project has [`duration-units`](.claude/skills/duration-units/SKILL.md): how `*units*` works, how to add a unit with a test, and how to fix one.
- **Path-scoped rules** in `.claude/rules/*.md` (also `.cl-stack-code/rules/`). [`lisp.md`](.claude/rules/lisp.md) has `paths: ["**/*.lisp"]`, so it loads the first time a tool reads a `.lisp` file: this project's conditions-and-restarts convention.

The `system`/`init` event (`--output-format stream-json`) lists what was found: `instructions`, `imports`, `skills` and `rules`.

### Use it in Zed

[Zed](https://zed.dev) runs cl-stack-code over the Agent Client Protocol (`cl-stack-code --acp`). Files are read and written through Zed's buffers, `cl-repo test` runs in Zed's terminal, and anything the project settings don't allow is a Zed permission prompt.

1. **Build and sync once** (the launcher pins cl-stack-code 0.14.0). `cl-stack-code --build`, so Zed gets the `initialize` reply in about a second. Then `cl-repo sync` in this checkout, so the session's Lisp image starts without installing anything.
2. **Add the agent** to `~/.config/zed/settings.json`. The entry and its fields are in [lisp-workspace `editors/zed/`](https://github.com/egao1980/lisp-workspace/tree/main/editors/zed):

   ```json
   "agent_servers": {
     "cl-stack-code": {
       "type": "custom",
       "command": "/Users/you/.local/bin/cl-stack-code",
       "args": ["--acp", "--model", "openai"],
       "env": {
         "OPENAI_BASE_URL": "http://localhost:8888/v1",
         "OPENAI_MODEL": "<model id>",
         "OPENAI_TIMEOUT": "600",
         "OPENAI_STREAM_IDLE_TIMEOUT": "300",
         "PATH": "/Users/you/.local/bin:/Users/you/.roswell/bin:/opt/homebrew/bin:/usr/bin:/bin"
       }
     }
   }
   ```

   `PATH` must contain `cl-repo` and `ros`: the Lisp image (`lispImage: spawn`) starts through `cl-repo run`.
3. **Start Zed with the key in its environment**, never in the settings file. Quit Zed first, then:

   ```bash
   export OPENAI_API_KEY=…
   zed .
   ```

4. In the Agent panel, start a new **cl-stack-code** thread. Its first card, "Context: AGENTS.md · skills: duration-units · rules: 1", lists what the session found; "Rule loaded: .claude/rules/lisp.md" appears when the agent first reads a `.lisp` file. Type a prompt, for example "the tests fail, find and fix the bug" or "Add a w (week) unit to parse-duration, with tests. Run them."

The Zed demo (a seeded bug on the `demo/zed-seeded-bug` branch, fixed by cl-stack-code over ACP) is in [cl-stack-demos `harness/zed-sample`](https://github.com/egao1980/cl-stack-demos/tree/main/harness/zed-sample).

### Model failures and limits (cl-stack-code 0.14.0)

- **Retries.** Rate limits (429, honouring `Retry-After`), overload (503 / 529), other 5xx and dropped connections are retried with backoff: 4 attempts by default. Each retry is a `system` / `retry` event in `stream-json`. Change the count with `--max-retries N`, or set `"retry": {"maxAttempts": …, "initialDelayMs": …, "maxDelayMs": …}` in settings. A rejected key (401 / 403) or an unknown model fails at once.
- **Typed failures.** When the retries run out, or the failure can't be retried, the result names it: a `subtype` such as `error_overloaded` or `error_auth`, an `error_class` such as `model-overloaded`, and a message with no key in it. A model provider failure exits with 3, and a turn timeout with 124. Edits made so far stay. `cl-stack-code -p --continue --retry` re-sends the failed turn.
- **Slow models.** A slow local model needs longer timeouts. Streamed calls are bounded by `OPENAI_STREAM_IDLE_TIMEOUT` (the longest silence inside a stream, 300 s by default). `OPENAI_TIMEOUT` (or `requestTimeoutMs`) bounds only a call that is not streamed. `--turn-timeout S` (`turnTimeoutMs`) bounds a whole turn, and `--max-turns` bounds a run.
- **Long sessions.** The conversation is compacted automatically near the context window (`autoCompact`, `contextWindow`), and `/compact` compacts on demand. The rules already loaded stay loaded after a compaction.
- **Plan mode.** Plan mode (explore, then propose a plan for you to approve) is coming.

The [cl-stack-demos `harness/code-resilience`](https://github.com/egao1980/cl-stack-demos/tree/main/harness/code-resilience) demo runs each of these failures against a scripted server.

## 5. Run the agent live

```bash
export ANTHROPIC_API_KEY=…                 # default provider
cl-repo ros run \
  -e '(asdf:load-system "cl-stack-sample/agent")' \
  -e '(print (cl-stack-sample/agent:ask "How long is 1h30m plus 45m plus 2d?"))' \
  -e '(uiop:quit)'
```

`cl-repo ros …` is short for `cl-repo run -- ros …`: it syncs, then starts `ros` with the source registry already set.

`ask` runs over the cl-stack async HTTP backend. Through ai-agent-protocol 0.16.0's loop, it retries rate limits, overload and transient failures (up to 4 attempts) and fails at once on a bad key. At 6 steps it makes one last call without tools, so the answer sums up what was done instead of stopping in the middle of a tool loop. For a longer-running agent, with compaction, permissions, subagents and `AGENTS.md` discovery, see the [agent harness tutorial](https://github.com/egao1980/cl-stack/blob/main/docs/tutorials/agent-harness.md).

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
| vLLM server | `vllm[:model]` | `127.0.0.1:8000/v1` | none | give the served model |
| vllm.cpp in-process | `vllm-cpp:<path.gguf>` | none: the engine runs in this Lisp | none | `VLLM_MODEL_PATH`; load `cl-stack-sample/vllm` |
| Offline echo | `mock` | none | none | none |

```bash
# the same command, other providers:
SAMPLE_LLM=openai:gpt-4o OPENAI_API_KEY=…            cl-repo ros run …
SAMPLE_LLM=lmstudio:qwen/qwen3.8-27b LM_API_TOKEN=… cl-repo ros run …
SAMPLE_LLM=ollama:llama3.1:8b                        cl-repo ros run …
SAMPLE_LLM=mock                                      cl-repo ros run …   # offline: "echo: …"
```

Without a model, the OpenAI-compatible providers send `OPENAI_MODEL`, or `gpt-4o-mini` when that is unset, so name the model for local servers. The model must support tool calls. Small local models sometimes answer without calling `add_durations`.

**Add a provider.** `*providers*` holds entries of the form `(name kind base-url api-key-env default-model)`. `kind` is `:anthropic` ([`llm-protocol-anthropic`](https://github.com/egao1980/llm-protocol-anthropic)), `:openai` ([`llm-protocol-openai`](https://github.com/egao1980/llm-protocol-openai), chat completions) or `:mock`. Push a new entry:

```lisp
(push '("groq" :openai "https://api.groq.com/openai/v1" "GROQ_API_KEY" "llama-3.3-70b-versatile")
      cl-stack-sample/agent:*providers*)
```

**vLLM in-process (vllm.cpp).** The `cl-stack-sample/vllm` system adds the `vllm-cpp` provider. It loads a GGUF into [vllm.cpp](https://github.com/egao1980/vllm-cpp) inside the Lisp image: Metal on darwin/arm64, CUDA on linux/amd64. No server is involved:

```bash
SAMPLE_LLM=vllm-cpp:$HOME/.lmstudio/models/lmstudio-community/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf \
cl-repo ros run \
  -e '(asdf:load-system "cl-stack-sample/vllm")' \
  -e '(print (cl-stack-sample/agent:ask "How long is 1h30m plus 45m plus 2d?"))' -e '(uiop:quit)'
;; → "The sum is 2d2h15m."   (add_durations ["1h30m","45m","2d"] → 2d2h15m)
```

- **Context length.** The engine loads with `*vllm-max-model-len*` set to 2048. vllm.cpp's default KV pool holds about 4064 tokens, so a larger value is refused at load.
- **Model support.** vllm-cpp 0.2.2's darwin overlay loads Qwen3.5-family GGUFs (`qwen35`, `qwen35moe`, `qwen3next`) and `deepseek4`.
- **Small models.** A 2B model handles a plain question, but may answer without calling the tool when the request is odd. A larger model follows the tool-error retry more reliably.
- **Install size.** `cl-repo sync` installs every system's dependencies, including the vllm-cpp native overlay. On linux/amd64 that is the CUDA build; without the NVIDIA driver it loads as unavailable.

**Add a provider kind.** `make-provider-backend` is a generic function on the kind keyword. `cl-stack-sample/vllm` does exactly this: one `defmethod` on `(eql :vllm-cpp)` and one `*providers*` entry.

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
cl-stack-sample.asd      5 systems: library, tests, agent, agent tests, vllm
src/                     package, conditions, duration
agent/agent.lisp         the add_durations tool and the agent
vllm/vllm.lisp           the in-process vllm.cpp provider (vllm-cpp:<gguf>)
tests/                   Rove: duration-test, agent-test
.claude/settings.json    cl-stack marketplace + lisp-workspace plugin
.cl-stack-code/          cl-stack-code project settings (permission rules)
docs/harness-session.md  a recorded cl-stack-code -p session
AGENTS.md / CLAUDE.md    project notes for agents
.github/workflows/       cl-repository test-system.yml, library + agent
```

MIT licensed.
