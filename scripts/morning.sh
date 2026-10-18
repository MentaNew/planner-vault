#!/usr/bin/env bash
# Scheduled morning plan. Commits a snapshot before and after, so any change is one `git revert` away.
# Example crontab entry (weekdays 08:00):   0 8 * * 1-5 /full/path/to/vault/scripts/morning.sh >> /full/path/to/vault/scripts/morning.log 2>&1
set -euo pipefail
cd "$(dirname "$0")/.."

git add -A && git commit -qm "snapshot before morning plan $(date +%F)" || true

claude -p "Follow .claude/commands/plan-day.md for today. Write the plan into today's daily note and keep the chat reply to the schedule and one trade-off." \
  --permission-mode acceptEdits

git add -A && git commit -qm "morning plan $(date +%F)" || true
