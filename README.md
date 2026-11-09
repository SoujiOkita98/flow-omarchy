# Flow for Omarchy

Small, agent-first AI dictation for [Omarchy](https://omarchy.org). Press a key,
talk, press again, and clean text appears where your cursor is. It works in any
language and keeps mixed languages as you spoke them.

> **Based on [FreeFlow](https://github.com/zachlatta/freeflow) by Zach Latta.**
> Same pipeline, same cleanup prompt, rebuilt for Linux.

## Why this exists

I built this for myself. I use [FreeFlow](https://github.com/zachlatta/freeflow)
on my Mac and love it, and when I moved to Omarchy I wanted the same thing.
FreeFlow is a native macOS app and its author has chosen to keep it Mac-only
([#22](https://github.com/zachlatta/freeflow/issues/22)), which is a fair
choice for a free project. So I rebuilt the parts I use as a small script for
my own setup, and I'm sharing it in case it helps other Omarchy users.

**All credit goes to Zach Latta and FreeFlow's contributors.** The idea, the
pipeline design and the cleanup prompt are theirs, used under FreeFlow's MIT
license. This is an independent project, not affiliated with or endorsed by
FreeFlow, so please report problems here. On a Mac, use FreeFlow itself.

## Design

- **Agent-first.** Setup is meant to be done by your AI agent (Claude Code,
  Codex, …). [`AGENTS.md`](AGENTS.md) tells it exactly what to do, and
  `flow-omarchy doctor` tells it whether everything works.
- **Minimal UI.** A small pill at the bottom of the screen shows a live
  waveform while you talk, then "Transcribing". It follows your Omarchy theme
  and never takes focus. Settings live in one text file.
- **Small.** One bash script and one shell plugin. Nothing runs while you are
  not dictating.

## Setup

### With your AI agent (recommended)

Get a free API key at [console.groq.com/keys](https://console.groq.com/keys)
and copy it. Then tell your agent:

> Set up Flow for Omarchy for me by following
> https://github.com/SoujiOkita98/flow-omarchy/blob/main/AGENTS.md.
> My Groq API key is on the clipboard.

### By hand

```bash
git clone https://github.com/SoujiOkita98/flow-omarchy ~/.local/src/flow-omarchy
cd ~/.local/src/flow-omarchy
make install PREFIX=~/.local
omarchy-install-dictation-flow-omarchy   # asks for the API key
flow-omarchy doctor                      # every line should say ok
```

## Use

- **Alt + Space**: press to start, press again to stop.
- **Right Alt**: hold to talk (Omarchy's default; your agent can make it a tap toggle).

Everything you say is transcribed, cleaned up (filler words removed,
"Thursday, no actually Wednesday" becomes "Wednesday", punctuation fixed) and
pasted into the focused window. `flow-omarchy paste-again` pastes the last
result again.

## Settings

`~/.config/flow-omarchy/config` (`flow-omarchy config` opens it):

| Setting | Default | |
| --- | --- | --- |
| `FLOW_API_KEY` | | Provider API key |
| `FLOW_API_URL` | Groq | Any OpenAI-compatible API (Ollama, LM Studio, …) |
| `FLOW_TRANSCRIPTION_MODEL` | `whisper-large-v3` | |
| `FLOW_MODEL` | `openai/gpt-oss-20b` | Cleanup model; falls back to `FLOW_FALLBACK_MODEL` |
| `FLOW_CLEANUP` | `1` | `0` pastes exactly what was transcribed |
| `FLOW_LANGUAGE` | auto | Main language code, e.g. `zh`, `de` |
| `FLOW_OUTPUT_LANGUAGE` | | Translate everything into this language, e.g. `English` |
| `FLOW_CONTEXT` | `1` | Send the focused app's name and window title as a spelling hint |
| `FLOW_OUTPUT` | `paste` | `paste`, `clipboard` or `stdout` |
| `FLOW_TIMEOUT` | `20` | Seconds per request; raise for local models |

Names and terms to always spell right go in `~/.config/flow-omarchy/vocabulary`,
one per line. `~/.config/flow-omarchy/prompt.txt` replaces the cleanup prompt.

## Privacy

There is no Flow server. Audio, the transcript and the focused window's name
and title go only to the provider you configure (Groq by default). The last
result is kept in `~/.local/state/flow-omarchy/last.txt`.

## Not ported (yet)

From FreeFlow: Edit Mode (rewriting selected text by voice), history,
screenshot-based context, the settings window and realtime transcription.

## Uninstall

```bash
omarchy-remove-dictation-flow-omarchy
make uninstall PREFIX=~/.local
```

## License

MIT. See [LICENSE](LICENSE). The cleanup prompt in
`share/flow-omarchy/prompts/cleanup.txt` is copied verbatim from FreeFlow
([`Sources/PostProcessingService.swift`](https://github.com/zachlatta/freeflow/blob/3778646/Sources/PostProcessingService.swift)).
