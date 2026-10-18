---
description: Build or rebuild the plan for a day (default today). Usage /plan-day [YYYY-MM-DD]
argument-hint: [date]
---
Plan the day for: $ARGUMENTS (if empty, use today's date; check it with the `date` command).

Follow "Planning a day" in CLAUDE.md exactly:
1. Open or create `Daily/<date>.md` from `Templates/Daily.md`.
2. Read `Agent/Calendar-Sources.md`, `Tasks/Inbox.md`, yesterday's note and `Roadmap/Roadmap.md`. Read `Agent/Durations.md` for multipliers.
3. Write the schedule between the plan markers, with the `**Why:**` lines under it.
4. Reply with the schedule, the main trade-off, anything that didn't fit, and one thing I should double-check.

If a preference you need is missing, make a reasonable assumption, state it, and add it to `Agent/Learned.md` with low confidence.
