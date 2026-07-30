# 🧘 vibestretch

Stretch nudges in your terminal while your coding agent works.

Your agent grinds for minutes at a time. You sit there, slouched, not blinking.
Some tools sell that attention window to advertisers. vibestretch gives it back to your spine:

```
🧘 vibestretch » ~7 min of agent time since your last break. You: slow neck rolls — 5 each direction.
```

A one-line nudge — a stretch, a micro-workout, or an eye exercise (20-20-20 and friends) —
lands in the session only when you've genuinely been sitting through agent work.
Short tasks, fast models, quick back-and-forth: silence.

## Install (Claude Code)

```
/plugin marketplace add Junit/vibestretch
/plugin install vibestretch@vibestretch
```

That's it. No dependencies, no daemon, no telemetry, no ads, no links in your terminal —
a single POSIX shell script wired into Claude Code hooks. Nothing ever leaves your machine.

## When it nudges

vibestretch tracks your sitting debt: how much agent-active time you've sat through
since your last break. A nudge fires only when all three are true:

1. The current turn has been running for a while — you're actually waiting right now
   (default: 2+ min).
2. Your accumulated agent time since the last nudge is high enough — one big task
   or several medium ones both count (default: 5+ min).
3. The last nudge wasn't recent (default: 15 min cooldown).

Step away from the keyboard for 45+ minutes and the debt resets — you already had
your break. This makes vibestretch model-agnostic by construction: fast models finish
turns before thresholds hit, so there's nothing to mute.

## Configure

Environment variables (all optional, all in seconds):

| Variable | Default | Meaning |
|---|---|---|
| `VIBESTRETCH_MIN_TURN` | `120` | Current turn must run at least this long |
| `VIBESTRETCH_MIN_ACTIVE` | `300` | Accumulated agent time since your last break |
| `VIBESTRETCH_COOLDOWN` | `900` | Minimum gap between nudges |
| `VIBESTRETCH_DISABLE` | unset | Set to anything to mute nudges |

## How it works

Three [Claude Code hooks](https://docs.claude.com/en/docs/claude-code/hooks):

- `UserPromptSubmit` marks the moment the agent starts working
- `PostToolUse` accumulates agent-active time between tool calls and emits a nudge when due
- `Stop` closes out the turn's accounting

State lives in `~/.cache/vibestretch/`. Exercises rotate so you don't get squats twice in a row.

## Roadmap

- [ ] OpenAI Codex CLI support
- [ ] Gemini CLI support
- [ ] Your own exercise list

## Who made this

Built in public by [Junit](https://github.com/Eliasjunit) — solo founder shipping
AI products (and trying not to fuse with the chair while agents write the code).

MIT.
