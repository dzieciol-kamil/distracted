#!/bin/bash
PROJECT="${PROJECT:-/home/worker/distracted}"
REPO_URL="https://${GH_TOKEN}@github.com/dzieciol-kamil/distracted.git"

git config --global user.name "Distracted Worker"
git config --global user.email "kdzieciol+worker@gmail.com"

if [ ! -d "$PROJECT/.git" ]; then
    echo "[$(date '+%F %T')] Cloning repo..."
    git clone "$REPO_URL" "$PROJECT"
else
    git -C "$PROJECT" pull --ff-only 2>&1 || true
fi

/worker.sh || echo "[$(date '+%F %T')] Worker exited with error — sleeping anyway"

echo "[$(date '+%F %T')] Done. Sleeping 600s before exit."
sleep 600
