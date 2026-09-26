# Focus History

[![test](https://github.com/FjedorGaede/herdr-focus-history/actions/workflows/test.yml/badge.svg)](https://github.com/FjedorGaede/herdr-focus-history/actions/workflows/test.yml)

Vim-style back/forward jumplist for [Herdr](https://herdr.dev/). Jump through workspace and agent focus history with simple keybindings.

> [!WARNING]
> **Early and personal.** This plugin is so far only used by me, on my own setup (Linux, herdr 0.9.1). It has tests and CI, but no guarantees: it may break with other herdr versions, setups, or workflows. Issues are welcome.

## Features

- **Two separate histories**: workspaces and agents
- **Vim-like navigation**: back and forward through your focus history
- **Automatic tracking**: every workspace switch and agent focus is recorded
- **Cleans up after itself**: closed workspaces and agent panes are removed from the history as soon as herdr reports them closed (and skipped at jump time as a safety net)
- **Keeps 100 entries** per history, vim-style (forward history is dropped when you jump somewhere new)

## Install

```bash
herdr plugin install FjedorGaede/herdr-focus-history
```

Or link locally for development:

```bash
git clone git@github.com:FjedorGaede/herdr-focus-history.git
herdr plugin link ./herdr-focus-history
```

## Usage

Add keybindings to your `~/.config/herdr/config.toml`:

```toml
# Workspace history
[[keys.command]]
key = "alt+p"
type = "plugin_action"
command = "focus-history.workspace-back"
description = "Jump to previous workspace"

[[keys.command]]
key = "alt+n"
type = "plugin_action"
command = "focus-history.workspace-forward"
description = "Jump to next workspace"

# Agent history
[[keys.command]]
key = "alt+shift+p"
type = "plugin_action"
command = "focus-history.agent-back"
description = "Jump to previous agent"

[[keys.command]]
key = "alt+shift+n"
type = "plugin_action"
command = "focus-history.agent-forward"
description = "Jump to next agent"
```

Then reload config:

```bash
herdr server reload-config
```

## How it works

Event hooks keep two histories in `~/.local/state/herdr/plugins/focus-history/`:

| herdr event | effect |
|---|---|
| `workspace.focused` | record the workspace |
| `pane.focused` | record the pane, if it's running an agent |
| `workspace.closed` | remove it (and any agents that were in it) |
| `pane.closed` | remove it from the agent history |

The four actions step through a history and focus the target. Workspaces or agents that disappeared without a close event (e.g. you quit the agent but kept the pane) are skipped at jump time.

### Project structure

```
src/
├── lib/
│   ├── history.sh    # Pure jumplist logic (push, step, prune)
│   ├── plugin.sh     # on_focus / on_navigate — what the plugin does
│   ├── herdr.sh      # The herdr interface: the only code that calls herdr
│   └── store.sh      # Load/save a history from the plugin state dir
├── record.sh         # Entry point for the focus event hooks
├── close.sh          # Entry point for the close event hooks
└── navigate.sh       # Entry point for the back/forward actions

test/
├── test-history.sh   # Unit tests for the jumplist logic
├── test-plugin.sh    # on_focus / on_navigate with the herdr interface stubbed
├── mutation-check.sh # Breaks the code on purpose; the tests must catch it
├── e2e/              # End-to-end tests against a real, throwaway herdr server
└── lib/assert.sh     # Test helpers
```

## Actions

- `focus-history.workspace-back` — Jump to previous workspace
- `focus-history.workspace-forward` — Jump to next workspace
- `focus-history.agent-back` — Jump to previous agent
- `focus-history.agent-forward` — Jump to next agent

## Development

```bash
./test/run-all.sh          # unit tests (fast, no herdr needed)
./test/mutation-check.sh   # verify the tests catch known bugs
./test/e2e/test-e2e.sh     # end-to-end: needs herdr and jq
```

- **Unit tests** never touch herdr: `test-plugin.sh` replaces the three functions in `src/lib/herdr.sh` with its own.
- **E2E tests** start a throwaway herdr server per test in a temp `HOME` and call it through `env -i`, so a herdr you're running is never touched. Agents are simulated with `herdr pane report-agent`. Set `E2E_HERDR` to test a specific herdr binary.
- **CI** runs unit + mutation tests with `/bin/bash` on Ubuntu and macOS (bash 3.2), and the e2e suite against herdr v0.9.1 on both.

## Requirements

- Herdr ≥ 0.9.0
- Linux or macOS
- bash, jq

## License

MIT
