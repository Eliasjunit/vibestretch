#!/bin/sh
# Wraps an existing statusLine command and adds the vibestretch segment.
#
#   statusline-wrap.sh '<original command>'   # keep your status line, add us
#   statusline-wrap.sh                        # no prior status line: model + us
#
# Claude Code pipes session JSON to the statusLine command's stdin; we pass it
# through to the original untouched (trailing newline restored — $(cat) strips
# it, and `read`-based scripts fail without it).
#
# Review-driven guarantees: extra args are joined back into one command (a
# mis-quoted install runs loud, not truncated); a failing original command
# shows an explicit error instead of silently vanishing; the original runs
# under the user's own shell when it's bash/zsh, so bash-isms that worked
# before wrapping keep working.
IN=$(cat)

run_original() {
  case "${SHELL##*/}" in
    bash|zsh) printf '%s\n' "$IN" | "$SHELL" -c "$1" ;;
    *)        printf '%s\n' "$IN" | sh -c "$1" ;;
  esac
}

if [ "$#" -gt 0 ]; then
  CMD="$*"
  OUT=$(run_original "$CMD" 2>/dev/null)
  RC=$?
  if [ -z "$OUT" ] && [ "$RC" -ne 0 ]; then
    OUT="⚠ status line command failed (exit $RC) — run it by hand: $CMD"
  fi
else
  # minimal default: the model's display name from the session JSON
  OUT=$(printf '%s' "$IN" | sed -n 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

SEG=$("$(dirname -- "$0")/statusline-segment.sh")
if [ -z "$SEG" ]; then
  printf '%s\n' "$OUT"
elif [ -z "$OUT" ]; then
  printf '%s\n' "$SEG"
else
  # June's composition call: the exercise leads the line, the quiet counter
  # trails it. "sitting" is our own literal from statusline-segment.sh.
  case "$SEG" in
    *sitting*) printf '%s | %s\n' "$OUT" "$SEG" ;;
    *)         printf '%s | %s\n' "$SEG" "$OUT" ;;
  esac
fi
