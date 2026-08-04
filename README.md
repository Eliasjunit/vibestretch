# 🧘 vibestretch

Stretch nudges in your terminal while your coding agent works.

![vibestretch nudges you to stretch while Claude Code works](assets/demo.gif)

Your agent grinds for minutes at a time. You sit there, slouched, not blinking.
Some tools sell that attention window to advertisers. vibestretch gives it back to your spine:

```
🧘 Slow neck rolls — 5 each direction. · vibestretch · 7 min of agent time
```

The nudge reaches you several ways, because you're rarely looking at the right
spot when it fires:

- a line in the session — for when you're watching the agent work
- a soft chime of its own (bundled, nothing system-sounding) — for when you're
  not looking at any screen at all
- a notification banner (Warp, Ghostty, iTerm2, WezTerm, kitty) — for the
  moment it fires, see the note below
- your status line, if you run [`/vibestretch:statusline`](#show-it-in-your-status-line)
  — the one channel that's still there when you come back from another app

All out of the box, nothing to configure. `VIBESTRETCH_SOUND=0` mutes the
sound, `VIBESTRETCH_NOTIFY=0` drops the banner.

> **About that banner.** What your terminal does with the notification sequence
> is its own call: some post a real OS notification that waits in the
> notification center, others (Warp) draw their own banner inside the window —
> which you never see if you're looking at another app, and which is gone by
> the time you come back. Either way it's a moment, not a record, so
> vibestretch doesn't lean on it: the chime catches you while you're away, and
> the status line is what's still saying it when you return. On macOS,
> terminals that post real notifications can be set to **Alerts** (System
> Settings → Notifications) so the banner waits instead of fading.
>
> The terminal's tab title would be the obvious place for a badge, and it isn't
> available: Claude Code rewrites the title itself every turn, so anything a
> plugin parks there is gone in seconds. Tried in 0.4.2, removed in 0.4.5.

A one-line nudge — a stretch, a micro-workout, or an eye exercise (20-20-20 and friends) —
lands in the session only when you've genuinely been sitting through agent work.
Short tasks, fast models, quick back-and-forth: silence.

## Install (Claude Code)

```
/plugin marketplace add Eliasjunit/vibestretch
/plugin install vibestretch@vibestretch
```

That's it. No dependencies, no daemon, no telemetry, no ads, no links in your terminal —
a few small POSIX shell scripts (plus one chime.wav) wired into Claude Code hooks.
Nothing ever leaves your machine.

## When it nudges

vibestretch counts one thing only: **agent time** — the minutes an agent turn was
in flight while you were at the machine, added up since your last nudge. That is
not how long you have been at your desk, and the counter never claims to be: an
hour of reading and typing with quick turns in between adds almost nothing. What
it measures is the time the agent kept you waiting. A nudge fires only when all
three are true:

1. The current turn has been running for a while — you're actually waiting right now
   (default: 2+ min).
2. Your accumulated agent time since the last nudge is high enough — one big task
   or several medium ones both count (default: 5+ min).
3. The last nudge wasn't recent (default: 15 min cooldown).

Step away from the keyboard for 45+ minutes and the debt resets — you already had
your break. That reset is measured against the system's input clock, not against
anything the plugin bookkeeps, so it also fires when you come back to a window
where the agent kept working on its own and you haven't typed a prompt yet. And time when nobody touches the machine is never counted at all: on
macOS the hooks read the system keyboard/mouse idle clock, so an agent grinding
overnight adds no agent time and never chimes at an empty chair. (On Linux
there's no portable idle clock, so this guard degrades to the 45-minute reset.)
This makes vibestretch model-agnostic by construction: fast models finish
turns before thresholds hit, so there's nothing to mute.

## Configure

Environment variables (all optional, all in seconds):

| Variable | Default | Meaning |
|---|---|---|
| `VIBESTRETCH_MIN_TURN` | `120` | Current turn must run at least this long |
| `VIBESTRETCH_MIN_ACTIVE` | `300` | Accumulated agent time since your last break |
| `VIBESTRETCH_COOLDOWN` | `900` | Minimum gap between nudges |
| `VIBESTRETCH_AWAY` | `300` | No keyboard/mouse for this long = you're away: no debt, no nudges (macOS-only detection; `0` disables the guard) |
| `VIBESTRETCH_DISABLE` | unset | Set to anything to mute nudges |
| `VIBESTRETCH_NOTIFY` | `1` | Set to `0` to drop the desktop notification |
| `VIBESTRETCH_SOUND` | `1` | Set to `0` to mute the sound |

Running Claude Code headlessly (`claude -p` from a script, cron, or a bot)? Set
`VIBESTRETCH_DISABLE=1` in that environment. Otherwise those unattended sessions
count as sitting time you never actually sat through, and spend the nudge you
should have gotten at your desk.

## How it works

Three [Claude Code hooks](https://docs.claude.com/en/docs/claude-code/hooks):

- `UserPromptSubmit` marks the moment the agent starts working
- `PostToolUse` accumulates agent-active time between tool calls and emits a nudge when due
- `Stop` closes out the turn's accounting

The nudge is a `systemMessage` (a brief in-session notice shown to you, never
added to the model's context) plus an optional `terminalSequence` carrying the
desktop notification. Terminals that aren't known to support the sequence get
nothing rather than stray bytes.

State lives in `~/.cache/vibestretch/`. Exercises rotate so you don't get squats twice in a row.

`sh tests/run.sh` checks the part that matters — that the plugin never claims
time you didn't spend waiting. The system idle clock is stubbed, so "you left
for 90 minutes" is a variable and every case is deterministic.

## Show it in your status line

The in-session notice is transient by platform design, and plugins can't draw
in the status line — that bar belongs to you. So vibestretch offers the next
best thing, one command:

```
/vibestretch:statusline
```

It backs up your settings, wraps your existing status line command (or installs
a minimal one if you have none), and adds the nudge segment: the exercise in
green for 5 minutes after each nudge, and a quiet `🧘 12m agent time` counter
whenever 2+ minutes of fresh debt have built up. Run it again after a plugin
update to refresh the helpers; undo with `/vibestretch:statusline off`. If you
ever uninstall the plugin, run `off` first — uninstalling alone would leave the
segment configured but frozen.

Prefer wiring it yourself? The state is plain files
(`~/.cache/vibestretch/`: `current` — latest exercise text, `last-nudge` —
unix time it fired, `active` — seconds of agent time since the last nudge).
Rather than parsing
them by hand, copy `scripts/statusline-segment.sh` somewhere stable and call
it from your status line command — it handles the edge cases (empty files,
mute, staleness) that a quick snippet won't.

## Roadmap

- [ ] OpenAI Codex CLI support
- [ ] Gemini CLI support
- [ ] Your own exercise list

## Who made this

Built in public by [Junit](https://github.com/Eliasjunit) — solo founder shipping
AI products (and trying not to fuse with the chair while agents write the code).

MIT.
