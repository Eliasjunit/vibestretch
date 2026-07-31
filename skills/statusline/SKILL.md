---
description: Put the vibestretch nudge into the user's Claude Code status line.
  Wraps their existing statusLine command (or installs a minimal one) so the
  current exercise shows at the bottom for 5 minutes after each nudge, then a
  quiet sitting-debt counter. Run on explicit user request only.
disable-model-invocation: true
---

# Set up the vibestretch status line segment

You are wiring the vibestretch nudge into the user's status line. The plugin
itself cannot draw there — the status line belongs to the user — so the setup
edits the user's own configuration, with their approval implied by invoking
this skill. Work carefully: back up before changing anything, verify before
saving, and tell the user how to undo.

## Steps

1. **Read the current config.** Open `~/.claude/settings.json` and look at the
   `statusLine` key (it may be absent). Note the exact current value.

2. **Check it isn't already set up.** If the `statusLine` command mentions
   `vibestretch`, or it points to a local script whose content mentions
   `vibestretch` (read it and grep), report that the segment is already in
   place and STOP — do not double-wrap.

3. **Copy the helper scripts to a stable location.** The plugin's install path
   can change on update, so the status line must not point into it. Copy
   `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-segment.sh` and
   `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-wrap.sh` to
   `~/.claude/vibestretch/`, create the directory if needed, `chmod +x` both.

4. **Back up settings.** Copy `~/.claude/settings.json` to
   `~/.claude/settings.json.vibestretch-backup` (overwrite an older backup of
   the same name — it's from a previous run of this skill).

5. **Build the new command.**
   - If there was an existing `statusLine.command`, the new command is the
     wrapper with the old command as its single argument:
     `~/.claude/vibestretch/statusline-wrap.sh '<old command>'`
     Quote carefully: the old command becomes ONE shell argument. If it
     contains single quotes, escape them for shell (`'\''`), then escape the
     whole value for JSON.
   - If there was no status line, use the wrapper with no argument:
     `~/.claude/vibestretch/statusline-wrap.sh`
     (it prints the model name plus the segment).

6. **Verify before saving.** Run the new command in Bash with realistic stdin,
   for example:
   `echo '{"model":{"display_name":"Test"},"session_id":"x"}' | <new command>`
   It must exit 0 and print one line. If the user had a status line, that
   line must contain the old command's output. If this fails, do NOT touch
   settings.json — report what happened instead.

7. **Save.** Update only `statusLine.command` in `~/.claude/settings.json`
   (create `statusLine` as `{"type": "command", "command": "..."}` if absent),
   preserving every other key in the file byte-for-byte.

8. **Report.** Tell the user:
   - what the status line command was and what it is now;
   - that the segment shows the exercise for 5 minutes after each nudge, then
     `🧘 Nm sitting` once 2+ minutes of agent time have accumulated, and
     nothing when there's no debt;
   - undo = restore `~/.claude/settings.json.vibestretch-backup` (or just put
     the old command back);
   - the change takes effect on the next status line refresh, no restart.
