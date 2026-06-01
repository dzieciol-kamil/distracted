#!/bin/bash
# Distracted — autonomous dev worker
# Called by crontab every 10 minutes.
# Uses /tmp/distracted.lock as semaphore — skips run if previous is still active.
# Stale lock (> 8h) is removed automatically.

set -euo pipefail

LOCK=/tmp/distracted.lock
LOG=/tmp/distracted-worker.log
PROJECT=/Users/kamil/Projects/distracted
CLAUDE=/opt/homebrew/bin/claude
STALE_SECONDS=28800  # 8h

# --- Semaphore check ---
if [ -f "$LOCK" ]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK") ))
    if [ "$lock_age" -lt "$STALE_SECONDS" ]; then
        echo "[$(date '+%F %T')] Lock active (${lock_age}s old) — skipping" >> "$LOG"
        exit 0
    fi
    echo "[$(date '+%F %T')] Stale lock removed (${lock_age}s old)" >> "$LOG"
    rm -f "$LOCK"
fi

# --- Acquire ---
touch "$LOCK"
echo "[$(date '+%F %T')] Starting worker run" >> "$LOG"

# --- Cleanup on exit (error or success) ---
cleanup() {
    rm -f "$LOCK"
    echo "[$(date '+%F %T')] Worker run finished" >> "$LOG"
}
trap cleanup EXIT

# --- Run Claude ---
"$CLAUDE" \
    --add-dir "$PROJECT" \
    --dangerously-skip-permissions \
    -p "$(cat "$PROJECT/.claude/worker-prompt.md")" \
    >> "$LOG" 2>&1
