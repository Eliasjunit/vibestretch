---
description: Put the vibestretch nudge into the user's Claude Code status line
  (wraps their existing statusLine command or installs a minimal one), update a
  previous install, or remove it again with "off". Run on explicit user request
  only.
disable-model-invocation: true
---

# Set up the vibestretch status line segment

You are wiring the vibestretch nudge into the user's status line. The plugin
itself cannot draw there — the status line belongs to the user — so the setup
edits the user's own configuration, with their approval implied by invoking
this skill. Work carefully: back up before changing anything, verify before
saving, and tell the user how to undo.

If the user invoked this skill with the argument `off` (`$ARGUMENTS` contains
"off"), jump to **Removal** at the bottom.

## Steps

1. **Read the current config.** Open `~/.claude/settings.json` (it may not
   exist) and look at the `statusLine` key (it may be absent). Note the exact
   current value.

2. **Branch on what's already there.**
   - The command already points at `~/.claude/vibestretch/statusline-wrap.sh`:
     this is an UPDATE, not a first install. Re-copy both helper scripts as in
     step 3 (that is how segment fixes reach installed users), tell the user
     the copies were refreshed, and STOP — settings are already correct.
   - The command (or a local script it points to — read it and grep) mentions
     `vibestretch` some other way: the user integrated manually (for example
     the README snippet). Say so, and ask whether they want the managed
     wrapper instead before touching anything. If yes, warn them to remove
     their manual snippet afterwards or the segment will show twice.
   - Otherwise: fresh install, continue.

3. **Copy the helper scripts to a stable location.** The plugin's install path
   can change on update, so the status line must not point into it. Copy
   `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-segment.sh` and
   `${CLAUDE_PLUGIN_ROOT}/scripts/statusline-wrap.sh` to
   `~/.claude/vibestretch/`, create the directory if needed, `chmod +x` both.

4. **Back up.** If `~/.claude/settings.json` exists, copy it to
   `~/.claude/settings.json.vibestretch-backup` (overwriting an older backup —
   it's from a previous run of this skill). If it doesn't exist, skip the
   backup and remember: undo for a fresh file is "remove the statusLine key",
   not "restore a backup". Also save the old command for `off`: write the
   exact previous `statusLine.command` (or an empty file if there was none) to
   `~/.claude/vibestretch/previous-command`.

5. **Build the new command.**
   - If there was an existing `statusLine.command`, the new command is the
     wrapper with the old command as its single argument:
     `~/.claude/vibestretch/statusline-wrap.sh '<old command>'`
     Quote carefully: the old command should become ONE shell argument. If it
     contains single quotes, escape them for shell (`'\''`). (If quoting
     splits it anyway, the wrapper rejoins its arguments with spaces — a
     mis-quote degrades loudly, not silently.)
   - If there was no status line, use the wrapper with no argument:
     `~/.claude/vibestretch/statusline-wrap.sh`
     (it prints the model name plus the segment).

6. **Verify by comparison, before saving.** Build a realistic stdin fixture —
   include the fields real payloads carry, at least:
   `{"model":{"display_name":"Test","id":"claude-test"},"session_id":"t",
   "transcript_path":"/tmp/nonexistent.jsonl","workspace":{"current_dir":"/tmp",
   "project_dir":"/tmp"},"cwd":"/tmp"}`
   Run the OLD command with it, then the NEW command with the same stdin.
   The new output must contain the old output (multi-line output is fine —
   status lines may legally render several rows; compare content, not line
   count). If the old command itself fails on the fixture, say so and ask the
   user before proceeding — don't guess. If the new command fails or loses
   the old output, do NOT touch settings.json — report instead.

7. **Save, then re-verify the saved value.** Update only `statusLine.command`
   in `~/.claude/settings.json` (create `statusLine` as
   `{"type": "command", "command": "..."}` if absent; create the file if
   missing), preserving every other key. Then READ THE FILE BACK, extract the
   command exactly as saved, and run it once more with the fixture — this
   catches JSON-escaping mistakes, where the saved command differs from the
   one you verified in step 6.

8. **Report.** Tell the user:
   - what the status line command was and what it is now;
   - the segment shows the exercise for 5 minutes after each nudge, then a
     quiet `🧘 Nm agent time` counter once 2+ minutes of agent time have
     accumulated, and nothing when there's no debt or after 45 min away;
   - undo: `/vibestretch:statusline off`, or put the old command back by
     hand (the full-file backup, if one was made, also works but rolls back
     any OTHER settings changed since);
   - takes effect on the next status line refresh, no restart;
   - if they later uninstall the plugin, they should run
     `/vibestretch:statusline off` FIRST — uninstalling alone leaves the
     wrapper configured and the segment frozen on the last state.

## Removal (`off`)

1. Read `~/.claude/vibestretch/previous-command`. If it exists and is
   non-empty, set `statusLine.command` back to its content. If it exists and
   is empty, remove the `statusLine` key entirely. If the file is missing,
   fall back to asking the user or restoring the backup, and say which you
   did.
2. Leave `~/.claude/vibestretch/` and the backup file in place (harmless,
   and the user may re-enable), but mention they can delete them.
3. Confirm to the user what the status line command is now.
