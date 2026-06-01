#!/bin/bash
set -euo pipefail

PROJECT="${PROJECT:-/Users/kamil/Projects/distracted}"

echo "[$(date '+%F %T')] Container worker started"

git config --global user.email "worker@distracted"
git config --global user.name "Distracted Worker"
git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "git@github.com:"
git config --global url."https://${GH_TOKEN}@github.com/".insteadOf "https://github.com/"

echo "[$(date '+%F %T')] Auth configured, starting Claude"

LOG=/home/worker/.claude/worker-run.log

claude \
    --add-dir "$PROJECT" \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --verbose \
    -p "$(cat "$PROJECT/.claude/worker-prompt.md")" \
    2>&1 | tee -a "$LOG"

echo "[$(date '+%F %T')] Worker finished"
