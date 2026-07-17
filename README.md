# 🧘 unslouch

Stretch nudges in your terminal while your coding agent works.

Your agent grinds for minutes at a time. You sit there, slouched, not blinking.
Some tools sell that attention window to advertisers. unslouch gives it back to your spine:

```
🧘 unslouch » Agent has been at it for 4 min. Meanwhile, you: slow neck rolls — 5 each direction.
```

When a Claude Code turn runs longer than a few minutes, unslouch drops a one-line
nudge into the session: a stretch, a micro-workout, or an eye exercise (20-20-20 and friends).
Long task → more nudges, spaced out. Short tasks → silence.

## Install (Claude Code)

```
/plugin marketplace add Junit/unslouch
/plugin install unslouch@unslouch
```

That's it. No dependencies, no daemon, no telemetry — a single POSIX shell script
wired into Claude Code hooks. Nothing ever leaves your machine.

## Configure

Environment variables (all optional):

| Variable | Default | Meaning |
|---|---|---|
| `UNSLOUCH_FIRST_MIN` | `3` | Minutes of continuous agent work before the first nudge |
| `UNSLOUCH_REPEAT_MIN` | `5` | Minutes between nudges within one long turn |
| `UNSLOUCH_LINK` | repo URL | Link shown in the nudge footer |
| `UNSLOUCH_DISABLE` | unset | Set to anything to mute nudges |

## How it works

Three [Claude Code hooks](https://docs.claude.com/en/docs/claude-code/hooks):

- `UserPromptSubmit` marks the moment the agent starts working
- `PostToolUse` checks elapsed time between the agent's tool calls and emits a nudge when due
- `Stop` clears the timer when the agent finishes

State lives in `~/.cache/unslouch/`. Exercises rotate so you don't get squats twice in a row.

## Roadmap

- [ ] OpenAI Codex CLI support
- [ ] Gemini CLI support
- [ ] Your own exercise list

## Who made this

Built in public by [Junit](https://github.com/Eliasjunit) — solo founder shipping
AI products (and trying not to fuse with the chair while agents write the code).
Follow the build: link coming with the first post.

MIT.
