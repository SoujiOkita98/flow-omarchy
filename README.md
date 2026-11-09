# Flow for Omarchy

AI dictation for [Omarchy](https://omarchy.org) and other Wayland desktops.
Hold a key and talk. Flow transcribes your speech, cleans it up (removes
filler words, applies self-corrections like "Thursday, no actually Wednesday",
and fixes punctuation and the spelling of names) and pastes the result into the
focused window.

## Why this exists

I use [FreeFlow](https://github.com/zachlatta/freeflow) by Zach Latta on my
Mac and love it. When I moved to [Omarchy](https://omarchy.org) I missed it.
FreeFlow is a native macOS app, and its author has chosen to keep it Mac-only
([#22](https://github.com/zachlatta/freeflow/issues/22)), which is a fair
choice for a free project. So I rebuilt the parts I use as a small script for
my own Omarchy setup, and I'm sharing it in case it helps other Omarchy users.

**All credit goes to Zach Latta and FreeFlow's contributors.** The idea, the
pipeline design and the cleanup prompt are theirs, used under FreeFlow's MIT
license. This is an independent project. It is not affiliated with or endorsed
by FreeFlow, so please report problems here, not to FreeFlow. If you're on a
Mac, use [FreeFlow](https://github.com/zachlatta/freeflow) itself.

## How it works

It follows the same pipeline as FreeFlow on macOS:

1. Record the microphone with PipeWire (`pw-record`).
2. Transcribe with Whisper large v3 on Groq (any OpenAI-compatible provider works).
3. Clean up with `openai/gpt-oss-20b`, falling back to `qwen/qwen3.8-27b`.
4. Paste through the clipboard, then restore what was on the clipboard before.

There is no Flow server. Audio and text go only to the provider you configure.

## Install on Omarchy

```bash
git clone https://github.com/SoujiOkita98/flow-omarchy
cd flow-omarchy
make install-omarchy PREFIX=~/.local
omarchy-install-dictation-flow-omarchy
```

The last step asks for a free [Groq API key](https://console.groq.com/keys) and
makes Flow your dictation backend. Then:

- hold **Right Alt** to talk (push-to-talk), or
- press **Alt + Space** to start and again to stop.

To go back to Voxtype: `omarchy-dictation-use voxtype && omarchy-restart-hyprctl`.

This is an early version (0.1). It covers dictation and cleanup; FreeFlow's Edit
Mode and history are not ported yet.

## Other Wayland desktops

```bash
make install PREFIX=~/.local
flow-omarchy setup
```

Bind `flow-omarchy toggle` (or `flow-omarchy start` on press and `flow-omarchy stop` on release)
to a key in your compositor. Pasting into the focused window and window context
use `hyprctl`; elsewhere set `FLOW_OUTPUT="type"` (needs `wtype`) or
`"clipboard"`.

## Commands

| Command | What it does |
| --- | --- |
| `flow-omarchy start` / `stop` / `toggle` | Record, then transcribe, clean up and paste |
| `flow-omarchy cancel` | Stop and discard the recording |
| `flow-omarchy status` | `idle`, `recording` or `processing` |
| `flow-omarchy setup` | Save an API key and check it works |
| `flow-omarchy config` | Edit settings |
| `flow-omarchy paste-again` | Paste the last result again |

## Settings

`~/.config/flow-omarchy/config` (created by `flow-omarchy setup`, mode 600):

| Setting | Default | |
| --- | --- | --- |
| `FLOW_API_KEY` | `$GROQ_API_KEY` | Provider API key |
| `FLOW_API_URL` | `https://api.groq.com/openai/v1` | OpenAI-compatible base URL (Ollama, LM Studio, …) |
| `FLOW_TRANSCRIPTION_URL` | API URL | Separate transcription endpoint |
| `FLOW_TRANSCRIPTION_MODEL` | `whisper-large-v3` | |
| `FLOW_MODEL` / `FLOW_FALLBACK_MODEL` | `openai/gpt-oss-20b` / `qwen/qwen3.8-27b` | Cleanup models |
| `FLOW_CLEANUP` | `1` | `0` pastes the raw transcript |
| `FLOW_CONTEXT` | `1` | Send the focused app's name and window title as a spelling hint |
| `FLOW_LANGUAGE` | auto | Dictation language code, e.g. `de`, `zh`; empty auto-detects and keeps mixed languages |
| `FLOW_OUTPUT_LANGUAGE` | none | Translate the result into this language, e.g. `English` |
| `FLOW_OUTPUT` | `paste` | `paste`, `type` (wtype), `clipboard` or `stdout` |
| `FLOW_TIMEOUT` | `20` | Seconds per provider request; raise it for local models |

- `~/.config/flow-omarchy/vocabulary`: names and terms to spell exactly, one per line.
- `~/.config/flow-omarchy/prompt.txt`: replaces the cleanup prompt.

## Differences from FreeFlow on macOS

Context comes from the focused window's app name and title, not a screenshot
summary. Not yet ported: Edit Mode (transforming selected text), the settings
window, pipeline history and the realtime transcription mode.

## Development

```bash
make check   # runs the pipeline against a local mock provider: no mic, network or key
```

## License

MIT. The cleanup prompt in `share/prompts/cleanup.txt` is copied verbatim from
FreeFlow ([`Sources/PostProcessingService.swift`](https://github.com/zachlatta/freeflow/blob/3778646/Sources/PostProcessingService.swift)).
