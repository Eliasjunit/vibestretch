#!/bin/sh
# vibestretch tests — run with `sh tests/run.sh` from anywhere.
#
# Everything here is about the one property that makes this plugin worth
# installing: it must never claim time you did not spend waiting. The OS idle
# clock (`ioreg`) is stubbed, so "you left for 90 minutes" is a variable rather
# than a coffee break, and every case is deterministic.
#
# The regression that started this file (0.4.6): a debt survived a 90-minute
# absence, because the reset lived only in the prompt hook and the human came
# back to a window where the agent had kept working — so the nudge greeted him
# the moment he sat down with minutes he had already walked off.
set -e
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/vibestretch.sh"
ROOT=$(mktemp -d)
BIN="$ROOT/bin"; mkdir -p "$BIN"
cat > "$BIN/ioreg" <<'EOF'
#!/bin/sh
# only the HIDIdleTime line matters; value in nanoseconds
echo "    \"HIDIdleTime\" = ${IDLE_STUB:-0}000000000"
EOF
chmod +x "$BIN/ioreg"
export PATH="$BIN:$PATH"
export XDG_CACHE_HOME="$ROOT/cache"
export VIBESTRETCH_SOUND=0 VIBESTRETCH_NOTIFY=0
VS="$XDG_CACHE_HOME/vibestretch"
SID="test-session"
PAYLOAD='{"session_id":"'"$SID"'","hook_event_name":"PostToolUse"}'

pass=0; fail=0
ok() { if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   $1"; else fail=$((fail+1)); echo "  FAIL $1: expected '$3', got '$2'"; fi; }

reset_state() { # reset_state <active seconds>
  rm -rf "$VS"; mkdir -p "$VS"
  echo "$1" > "$VS/active"
  date +%s > "$VS/last-activity"
  echo $(( $(date +%s) - 300 )) > "$VS/turn-$SID"   # a turn that has run 5 min
  echo $(( $(date +%s) - 5 )) > "$VS/seen-$SID"
  echo 0 > "$VS/last-nudge"
}
check() { printf '%s' "$PAYLOAD" | IDLE_STUB="$1" sh "$SCRIPT" check; }

echo "case 1: away 90 min, then back — debt must burn"
reset_state 780                    # 13 min of debt, exactly June's number
check 5400 >/dev/null              # agent works while he is out (90 min idle)
ok "debt frozen while away" "$(cat "$VS/active")" "780"
ok "away mark written" "$([ -f "$VS/away-touch" ] && echo yes || echo no)" "yes"
OUT=$(check 3)                     # he touches the keyboard, next tool call fires
# Not a bare "= 0": the two checks above are real calls seconds apart, so the
# turn legitimately adds a second or two back. What must not survive is the 780.
ok "debt burned on return" "$(awk '$1<10 {print "burned"}' "$VS/active")" "burned"
ok "no nudge on return" "$(printf '%s' "$OUT" | grep -c systemMessage || true)" "0"
ok "away mark cleared" "$([ -f "$VS/away-touch" ] && echo yes || echo no)" "no"

echo "case 2: short break (10 min) — debt must survive"
# MIN_ACTIVE is raised out of reach so the nudge can't fire and zero the counter
# itself — this case is about the reset, not about nudging.
reset_state 780
VIBESTRETCH_MIN_ACTIVE=999999 check 600 >/dev/null
ok "away mark written" "$([ -f "$VS/away-touch" ] && echo yes || echo no)" "yes"
VIBESTRETCH_MIN_ACTIVE=999999 check 3 >/dev/null
ok "debt kept after short break" "$(awk '$1>=780 {print "kept"}' "$VS/active")" "kept"

echo "case 3: never left — normal accounting still accumulates"
reset_state 100
check 2 >/dev/null
ok "debt grows while present" "$(cat "$VS/active" | awk '$1>100 {print "grew"}')" "grew"

echo "case 4: the nudge itself still fires when the debt is real"
reset_state 780
OUT=$(VIBESTRETCH_MIN_TURN=10 VIBESTRETCH_MIN_ACTIVE=60 VIBESTRETCH_COOLDOWN=0 check 2)
ok "nudge fires for a present human" "$(printf '%s' "$OUT" | grep -c 'agent time' || true)" "1"

echo "case 5: non-macOS (no idle clock) — no crash, no bogus reset"
cat > "$BIN/ioreg" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$BIN/ioreg"
reset_state 780
VIBESTRETCH_MIN_ACTIVE=999999 check 0 >/dev/null
ok "debt untouched without an idle clock" "$(awk '$1>=780 {print "kept"}' "$VS/active")" "kept"
ok "no away mark without an idle clock" "$([ -f "$VS/away-touch" ] && echo yes || echo no)" "no"

echo "case 6: host-specific output (Codex drops any object with unknown fields)"
cat > "$BIN/ioreg" <<'EOF'
#!/bin/sh
echo "    \"HIDIdleTime\" = ${IDLE_STUB:-0}000000000"
EOF
chmod +x "$BIN/ioreg"
nudge() { # nudge <host> — force the thresholds so a nudge is guaranteed
  # NOTIFY is muted globally in this file to keep the other cases quiet; this
  # case is precisely about the banner, so it is turned back on here.
  reset_state 780
  printf '%s' "$PAYLOAD" | IDLE_STUB=2 TERM_PROGRAM=WarpTerminal VIBESTRETCH_NOTIFY=1 \
    VIBESTRETCH_MIN_TURN=10 VIBESTRETCH_MIN_ACTIVE=60 VIBESTRETCH_COOLDOWN=0 \
    sh "$SCRIPT" check ${1:+"$1"}
}
CLAUDE_OUT=$(nudge)
CODEX_OUT=$(nudge codex)
GEMINI_OUT=$(nudge gemini)
ok "claude host keeps the terminal banner" "$(printf '%s' "$CLAUDE_OUT" | grep -c terminalSequence)" "1"
ok "codex host drops the terminal banner" "$(printf '%s' "$CODEX_OUT" | grep -c terminalSequence)" "0"
ok "codex host still nudges" "$(printf '%s' "$CODEX_OUT" | grep -c 'agent time')" "1"
ok "gemini host drops the terminal banner" "$(printf '%s' "$GEMINI_OUT" | grep -c terminalSequence)" "0"
ok "gemini host still nudges" "$(printf '%s' "$GEMINI_OUT" | grep -c 'agent time')" "1"
# An unknown host must degrade to the quiet, universally safe output rather than
# guessing that a banner is welcome.
ok "unknown host stays quiet" "$(printf '%s' "$(nudge someday-cli)" | grep -c terminalSequence)" "0"
# VS Code's terminal has no notifications of its own but swallows unknown OSC
# quietly, and the extensions people add for that gap listen for the 777 form.
VSCODE_OUT=$(reset_state 780; printf '%s' "$PAYLOAD" | IDLE_STUB=2 TERM_PROGRAM=vscode \
  VIBESTRETCH_NOTIFY=1 VIBESTRETCH_MIN_TURN=10 VIBESTRETCH_MIN_ACTIVE=60 \
  VIBESTRETCH_COOLDOWN=0 sh "$SCRIPT" check)
ok "vscode terminal gets the 777 banner" "$(printf '%s' "$VSCODE_OUT" | grep -c '777;notify')" "1"
# An unrecognised terminal is still sent nothing at all — stray bytes in someone
# else's session are worse than a missing banner.
UNKNOWN_TERM=$(reset_state 780; printf '%s' "$PAYLOAD" | IDLE_STUB=2 TERM_PROGRAM=SomeTerm \
  VIBESTRETCH_NOTIFY=1 VIBESTRETCH_MIN_TURN=10 VIBESTRETCH_MIN_ACTIVE=60 \
  VIBESTRETCH_COOLDOWN=0 sh "$SCRIPT" check)
ok "unknown terminal gets no sequence" "$(printf '%s' "$UNKNOWN_TERM" | grep -c terminalSequence)" "0"
ok "unknown terminal still nudges" "$(printf '%s' "$UNKNOWN_TERM" | grep -c 'agent time')" "1"
# Codex accepts exactly: continue, stopReason, suppressOutput, systemMessage
ok "codex output has no field outside their schema" \
  "$(printf '%s' "$CODEX_OUT" | tr ',' '\n' | grep -o '"[a-zA-Z]*":' | tr -d '":' \
     | grep -vE '^(continue|stopReason|suppressOutput|systemMessage)$' | wc -l | tr -d ' ')" "0"

echo "case 7: your own exercise list"
EXFILE="$ROOT/exercises.txt"
cat > "$EXFILE" <<'EOF'
# my list — comments and blank lines are skipped

Do the thing
Say "hello" to the \ window
EOF
custom_nudge() { # custom_nudge [starting index] — reset_state wipes state, so the
                 # rotation index is seeded explicitly rather than carried over
  reset_state 780
  [ -n "$1" ] && echo "$1" > "$VS/idx"
  printf '%s' "$PAYLOAD" | IDLE_STUB=2 VIBESTRETCH_EXERCISES="$EXFILE" VIBESTRETCH_MIN_TURN=10 \
    VIBESTRETCH_MIN_ACTIVE=60 VIBESTRETCH_COOLDOWN=0 sh "$SCRIPT" check
}
OUT1=$(custom_nudge 0)
ok "custom exercise is used" "$(printf '%s' "$OUT1" | grep -c 'Do the thing')" "1"
ok "built-ins are not used" "$(printf '%s' "$OUT1" | grep -c '20-20-20')" "0"
ok "rotation stored for next time" "$(cat "$VS/idx")" "1"
# the second line carries a quote and a backslash — the JSON has to survive it,
# or the host drops the whole nudge
OUT2=$(custom_nudge 1)
ok "rotation advances" "$(printf '%s' "$OUT2" | grep -c 'hello')" "1"
ok "quotes and backslashes stay valid JSON" \
  "$(printf '%s' "$OUT2" | python3 -c 'import json,sys; json.loads(sys.stdin.read()); print("valid")' 2>/dev/null)" "valid"
# an index left over from a longer list must not point past the end
ok "stale index wraps instead of printing nothing" "$(custom_nudge 9 | grep -c 'systemMessage')" "1"
# a file that exists but says nothing usable: non-empty to the shell, empty to us
printf '# only comments\n\n' > "$EXFILE"
ok "unusable file falls back to built-ins" "$(custom_nudge 0 | grep -c '20-20-20')" "1"

rm -rf "$ROOT"
echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
