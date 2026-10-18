# Planner vault

An Obsidian vault that doubles as the memory and workspace of a Claude Code planning agent. Claude reads `CLAUDE.md` plus the three files in `Agent/` at the start of every session, and writes what it learns back into them.

## Setup

1. Put this folder where you want your vault and open it in Obsidian ("Open folder as vault").
2. Install the community plugins **Tasks** and **Day Planner**. Set the Day Planner to read your `Daily/` notes, and set the daily-note template to `Templates/Daily.md`. Check that the task and time-block syntax in `CLAUDE.md` matches what the plugins expect.
3. Safety net: `git init && git add -A && git commit -m "initial vault"`. Claude can't push or reset (see `.claude/settings.json`), and you can undo anything with `git diff` and `git checkout -- <file>`.
4. In the vault folder run `claude`, then `/onboard`.

## Daily loop

| When | Command |
|------|---------|
| Morning | `/plan-day` |
| Anytime | `/learn <preference>` |
| Evening | `/review-day` |
| Sunday | `/plan-week` |
| Every few weeks | `/memory-audit` |

## What Claude may touch

Writes: `Agent/`, `Daily/`, `Tasks/`. Read-only: `Roadmap/` and everything else (blocked in `.claude/settings.json`; adjust the patterns if Claude keeps asking for permission). It never deletes files and never pushes.

## Memory files

- `Agent/Profile.md`: stable facts (classes, commitments, goals, habits)
- `Agent/Preferences.md`: rules the planner follows
- `Agent/Learned.md`: observations with evidence counts, promoted to Preferences when confirmed
- `Agent/Durations.md`: estimate vs actual log and per-category multipliers
- `Agent/Calendar-Sources.md`: fixed events and deadlines (you fill this in until a calendar connection exists)
- `Agent/Changelog.md`: audit trail of memory changes

## Scheduled morning plan

`scripts/morning.sh` runs the plan headlessly and commits before and after. Add it to cron or launchd (instructions at the top of the script). It only runs while the computer is awake and you are logged in. Make it executable with `chmod +x scripts/morning.sh` and run it once by hand first.

## Next steps

- Connect Google Calendar and Canvas through MCP servers so `Calendar-Sources.md` fills itself in.
- Get notifications (for example a push from the script) so the plan reaches your phone.
# planner-vault
