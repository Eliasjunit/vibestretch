# Privacy

vibestretch collects nothing. There is no account, no server and no analytics.

## What it does on your machine

- It runs one POSIX shell script from your agent's hooks, as your user.
- It reads the hook payload on stdin, and only for the session id.
- It keeps small state files (timestamps and the last exercise) under
  `~/.cache/vibestretch/`. Delete that folder at any time; it starts fresh.
- It reads your own exercise list from `~/.config/vibestretch/exercises.txt`,
  if you made one.
- On macOS it reads the keyboard/mouse idle time, to stay quiet while you are
  away. The number is used on the spot and not stored.
- It plays a bundled sound with the system player and can ask your terminal
  to show a desktop notification.

## What it never does

- It makes no network calls. Nothing leaves your machine.
- It sends no telemetry and no crash reports.
- It adds nothing to the model's context and does not read your prompts, code
  or the agent's answers.

The optional `/vibestretch:statusline` skill for Claude Code edits your Claude
Code `settings.json`, after backing it up, and only when you run it.

## Changes

Any change to this page ships in the repository's history, next to the code it
describes.

Questions: open an issue on
[Eliasjunit/vibestretch](https://github.com/Eliasjunit/vibestretch/issues).
