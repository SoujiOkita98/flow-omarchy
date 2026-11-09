# Flow for Omarchy: guide for AI agents

Flow is meant to be set up by an AI agent on the user's behalf. Follow these
steps in order, run each command yourself, and tell the user in plain words
what you did. Flow is based on FreeFlow by Zach Latta; keep that credit
wherever you describe it.

Flow has only been tested on its author's Omarchy machine (Omarchy 4.5,
Hyprland 0.56, PipeWire 1.6, Groq). Tell the user this before installing.
If something fails on their setup, say so plainly rather than guessing.

## Set Flow up for a user

1. **Check first.** If `command -v flow-omarchy && flow-omarchy doctor` prints
   only `ok` lines, Flow is already set up: stop and tell the user.

2. **Install** with Omarchy's plugin manager (no sudo needed):

   ```bash
   omarchy plugin add https://github.com/SoujiOkita98/flow-omarchy --yes
   ```

   The repo lands in `~/.config/omarchy/plugins/io.github.soujiokita98.flow-omarchy`. If it is already
   there, run `omarchy plugin update io.github.soujiokita98.flow-omarchy --yes` instead.

3. **API key.** The user must create it themselves (free) at
   https://console.groq.com/keys and copy it to the clipboard. Never ask them
   to paste it into the chat, and never print, log or commit it. Save and test
   it straight from the clipboard, then clear the clipboard:

   ```bash
   wl-paste -n | ~/.config/omarchy/plugins/io.github.soujiokita98.flow-omarchy/bin/omarchy-install-dictation-flow-omarchy && wl-copy --clear
   ```

   This one command saves and tests the key (`API key works`), puts
   `flow-omarchy` on PATH, turns on the recording pill and makes Flow
   Omarchy's dictation backend (stopping the previous one, e.g. Voxtype).
   The key is stored in `~/.config/flow-omarchy/config` with mode 600.
   Re-running it with empty input keeps the saved key. Don't uninstall the
   user's previous dictation tool unless they ask.

4. **Verify** with `flow-omarchy doctor`. Every line must say `ok`; a `fix`
   line says what to do.

5. **Hand over.** Tell the user: press **Alt + Space** to start and again to
   stop, or hold **Right Alt** to talk. A small pill at the bottom of the
   screen shows the waveform, then "Transcribing", then the text is pasted.
   Ask them to try it once and say whether the text appeared.

## Common requests

- **Tap Right Alt to start and stop** (instead of holding it). Add this inside
  the dictation block of `~/.config/hypr/bindings.lua`, or after it guarded by
  `if o.dictation_installed and o.dictation_installed() then … end`, then
  validate with `hyprctl reload && hyprctl configerrors`:

  ```lua
  hl.unbind("ALT + Alt_R")
  o.bind("ALT + Alt_R", "Toggle dictation", "omarchy-dictation toggle", { ignore_mods = true })
  ```

- **Spell names right:** add them to `~/.config/flow-omarchy/vocabulary`, one per line.
- **Language:** set `FLOW_LANGUAGE` (e.g. `zh`) or `FLOW_OUTPUT_LANGUAGE`
  (e.g. `English`, to translate) in `~/.config/flow-omarchy/config`.
- **No cleanup, exact words:** `FLOW_CLEANUP=0`.
- **Local or other provider:** set `FLOW_API_URL` (and models) to any
  OpenAI-compatible endpoint, raise `FLOW_TIMEOUT` for local models, then
  run `flow-omarchy setup` again.
- **Text didn't appear:** run `flow-omarchy doctor`, then
  `flow-omarchy paste-again`. The last result is in
  `~/.local/state/flow-omarchy/last.txt`.
- **Uninstall:** `omarchy-remove-dictation-flow-omarchy` (removes Flow, its
  settings including the key, and the plugin).

Config changes apply on the next dictation. Never edit `/usr/share/omarchy/`.

## Working on this repository

- `bin/flow-omarchy` is the whole program (bash). `bin/omarchy-*` are the
  Omarchy dictation backend adapter, installer and remover.
- The repo root is the Omarchy shell plugin (`manifest.json`, `Overlay.qml`,
  `i18n/`; id `io.github.soujiokita98.flow-omarchy`, IPC target `flow`: `recording`, `processing`, `info`,
  `error`, `hide`). Edits reach a running shell only after
  `omarchy restart shell` when the plugin directory is a symlink.
- `prompts/cleanup.txt` is FreeFlow's prompt, verbatim.
  Don't edit it; extend the prompt in `system_prompt()` instead.
- Run `make check` (tests against a local mock provider: no mic, network or
  key; validates the manifest) and `shellcheck bin/*` before committing.
- Keep it small: no daemons, no new dependencies, minimal UI.
