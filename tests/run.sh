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
ok "debt burned on return" "$(cat "$VS/active")" "0"
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

rm -rf "$ROOT"
echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
