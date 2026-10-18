# Architecture and trade-offs

A personal planning agent built from an Obsidian vault, Claude Code and a private GitHub repo. This document explains how it works, why each choice was made, what it costs you, and how to reproduce it. Written October 2026. Anything I could not test is listed in section 9.

## 1. Goals and constraints

**Goals**
- Build and adjust a realistic daily and weekly plan from a roadmap, classes, meetings, habits and tasks.
- Learn how the person actually works (how long things take, when they focus, what they skip) and get better over time.
- Keep everything readable and editable by the person in Obsidian.

**Constraints that shaped the design**
- **No API credits.** The agent has to run on a Claude subscription, so the harness has to be Claude Code (see section 8, decision 1).
- **The human stays in control.** The agent proposes and writes to a few folders; it cannot delete, rewrite its own rules or touch the person's other notes.
- **Plain files.** Memory is markdown you can read, diff and fix by hand. No database, no embeddings.
- **Survive agent mistakes.** Every change goes through git, so any mistake is one revert away.

## 2. System overview

```
 YOU (laptop / phone)                GITHUB (private repo)               AGENT MACHINE
 -------------------                 ---------------------               -------------
 Obsidian vault (clone)              main  <-------------------+         agent clone
   Tasks + Day Planner               ^                          |           branch: agent
   Obsidian Git plugin  --push-->    |                    Action merges     Claude Code
                        <--pull--    |                    if paths allowed   CLAUDE.md
                                     |                          |            Agent/*.md memory
                                     +--- sync.sh --> pulls main |           .claude/commands
                                                                 |           cron: morning.sh
                                     agent  <------ publish.sh --+
```

Two clones, one remote. The agent never works inside the vault you have open in Obsidian. GitHub is the only bridge.

## 3. Components

| Component | What it is | Responsibility |
|---|---|---|
| Obsidian vault | Markdown files plus the Tasks and Day Planner plugins | The interface and the source of truth for you. Daily notes hold the plan as time blocks. |
| `CLAUDE.md` | Instruction file in the repo root | The agent's operating rules: memory protocol, ownership, formats, how to plan and review. Loaded every session. |
| `Agent/` | Six markdown memory files | Profile, Preferences, Learned, Durations, Calendar-Sources, Changelog. Section 4. |
| `.claude/commands/` | Slash commands | The workflows: `/onboard`, `/plan-day`, `/review-day`, `/plan-week`, `/learn`, `/memory-audit`. |
| `.claude/settings.json` | Permission rules | Which folders the agent may write and which commands it may run. |
| `scripts/sync.sh`, `publish.sh` | Small shell scripts | The only way the agent touches git: pull `main` into `agent`, commit the allowed folders and push `agent`. |
| `.github/workflows/agent-merge.yml` | GitHub Action | Merges `agent` into `main` when only allowed paths changed and nothing was deleted. |
| `scripts/morning.sh` | Cron entry point | Sync, run `claude -p` for the day's plan, publish. |

## 4. Memory design

Claude has no memory between sessions, so the vault is the memory. It has three layers:

1. **Instructions** (`CLAUDE.md`): how to behave. Written by the human, changed only by the human.
2. **Loaded memory** (`Profile.md`, `Preferences.md`, `Learned.md`): imported into every session with `@` references, so the agent always starts with them. They are kept small on purpose, because they cost context every time.
3. **On-demand memory** (`Durations.md`, `Calendar-Sources.md`, daily notes, `Roadmap/`): read only when needed. These grow without bound, so they are not auto-loaded.

**How learning works**
- An explicit statement ("I never work after 22:00") goes straight into `Preferences.md`.
- An inference ("tasks in this category run long") goes into `Learned.md` as one line with a date, an evidence count and a confidence level. If the pattern repeats, the count goes up instead of adding a duplicate.
- At three observations, or when the person confirms, the line is promoted to `Preferences.md` and the old line is marked superseded.
- Time estimates are learned from numbers: the evening review appends estimate versus actual to `Durations.md`, and `/memory-audit` recomputes a median multiplier per category (needs at least three rows).
- Nothing is ever deleted, only marked superseded. `Changelog.md` records each memory change, and git has the full history.
- The agent tells the person in one line what it saved, so wrong inferences get corrected early.

**Why plain markdown instead of a database or vector store:** the person can read and fix every memory by hand, git diffs show exactly what the agent learned, and a few hundred lines of curated notes fit in context. **The cost:** no semantic search, no automatic forgetting, and `Learned.md` needs periodic consolidation (`/memory-audit`) or it bloats and the agent slows down.

## 5. The GitHub bridge

The requirement: the agent updates the calendar and notes in Obsidian through GitHub.

1. You edit in Obsidian. Obsidian Git commits and pushes to `main`.
2. `sync.sh` fetches and merges `main` into the agent's `agent` branch. It stops on a conflict.
3. Claude edits files in the agent clone: plan blocks in daily notes, task lines, memory files, rows in `Calendar-Sources.md`.
4. `publish.sh` commits only `Agent/`, `Daily/` and `Tasks/`, and pushes only `agent`.
5. The GitHub Action checks the diff. If every changed path is inside the three folders and nothing was deleted, it merges `agent` into `main`. Otherwise it fails and the change waits for you.
6. Obsidian Git pulls `main` on its interval and the plan appears in your vault.

**What "the calendar" means here:** the Day Planner renders time blocks from the daily notes, so the plan block in each `Daily/YYYY-MM-DD.md` is the calendar. `Agent/Calendar-Sources.md` holds the fixed events and deadlines the planner works around.

**Conflict avoidance by ownership.** You and the agent both write daily notes, so the agent only writes between `<!-- plan:start -->` and `<!-- plan:end -->` and the Log and Review sections it was asked to fill. You write everything else. This keeps most merges conflict-free, but it is a convention, not a lock.

## 6. Safety model

Several independent layers, because no single one is airtight:

| Layer | What it prevents | How strong |
|---|---|---|
| Separate agent clone | The agent touching the vault you have open | Strong |
| `settings.json` permissions | Writes outside `Agent/`, `Daily/`, `Tasks/`; `rm`; direct `git push`, `reset`, `checkout`; edits to `CLAUDE.md`, `.claude/`, `scripts/`, `.github/` | Medium. Rules match command prefixes, so treat them as a seatbelt, not a sandbox. |
| `publish.sh` | Committing or pushing anything but the three folders, or pushing any branch but `agent` | Medium. It only constrains what the script does, not what other commands could do. |
| GitHub Action path check | Anything outside the three folders, or any deletion, reaching `main` | Strong, if you keep the workflow protected from agent edits |
| Git history | Any mistake that did get through | Strong. Revert the merge commit. |
| Your review | Wrong learning, bad plans | You are the last check. Read `Changelog.md` now and then. |

**Gap to know about:** the agent machine holds git credentials that can technically push to any branch. A hard guarantee needs a GitHub ruleset that blocks pushes to `main` except for you and the Actions app, with the agent using its own credential. I have not tested that combination. Without it, the permission rules are what stands between the agent and `main`.

## 7. A day in the life

1. **08:00** cron runs `morning.sh`: sync, `claude -p` builds the plan (fixed events first, then tasks sized with your duration multipliers, deep work in peak hours, buffers), publish. The plan appears in Obsidian a few minutes later.
2. **During the day** you mention a new meeting in a Claude session. The agent adds it to `Calendar-Sources.md`, rebuilds the affected days, publishes, and says which days changed.
3. **Evening** `/review-day`: you say what got done and how long things took. The agent ticks tasks, appends to `Durations.md`, records patterns in `Learned.md`, moves unfinished work forward, and publishes.
4. **Sunday** `/plan-week`: look back, check the roadmap, propose a week outline; after you approve, the daily plans are written.
5. **Every few weeks** `/memory-audit` consolidates `Learned.md` and recomputes multipliers.

## 8. Trade-offs and alternatives considered

| # | Decision | Chosen | Alternatives | Why, and what it costs |
|---|---|---|---|---|
| 1 | Agent harness | **Claude Code** | Hermes Agent, an API-key harness, a custom agent (the Planner app) | Anthropic restricts subscription logins to Claude Code and Claude.ai, and third-party harnesses on a subscription are blocked or billed as extra usage, so Hermes would need pay-per-token API credits. Claude Code runs on the subscription. You give up Hermes' built-in messaging gateway, cron scheduler and self-written skills. |
| 2 | Memory | **Markdown files in the vault** | Hermes' `MEMORY.md` (2,200 and 1,375 character caps), database, vector store | Human-readable, diffable, unlimited size. No semantic search and manual consolidation. |
| 3 | Scheduling logic | **The model reasons over explicit rules** | A constraint solver (OR-Tools CP-SAT, as in the earlier Planner app) | Zero code and easy to change in plain English. Less consistent as constraints pile up; weaker guarantees (for example that the deep-work cap is never exceeded). A solver exposed as an MCP tool is the upgrade path. |
| 4 | Where the agent works | **Separate clone, GitHub in between** | Agent edits your Obsidian folder directly | Protects the vault you have open and gives a reviewable history. Adds latency (minutes, not seconds) and needs a GitHub account and Actions. |
| 5 | Merging | **Auto-merge via Action with a path check** | Pull request you review each time; direct push to `main` | Hands-off but limited to safe paths. A PR per change is safer and tedious. Direct push is simplest and has no guard. |
| 6 | Scheduling the morning run | **Local cron on the agent machine** | A cloud scheduled task against the repo; Hermes cron on a VPS | Free and simple, but the machine must be awake. A cloud run works with the laptop closed; I have not verified whether it draws on the subscription or its limits. |
| 7 | Calendar inputs | **Manual `Calendar-Sources.md`, updated through chat** | Google Calendar and Canvas through MCP servers | No credentials or OAuth to manage, and no way for the agent to edit your real calendar. You have to tell it about changes. MCP connections are the obvious next step. |
| 8 | Learning | **Evidence counts and promotion rules** | Let the model rewrite its own memory freely | Slower to adopt a pattern, but stops one odd day from becoming a rule. |

## 9. Known limitations and untested assumptions

- I could not run any of this against a real vault, GitHub repo or Claude Code install. Treat the scripts, workflow and settings as a careful first draft and test each step.
- The Tasks plugin and Day Planner syntax in `CLAUDE.md` is from memory. Check it against the plugin docs.
- The folder-scoped patterns in `settings.json` (for example `Edit(Agent/**)`) may not match as written; if Claude keeps asking permission, adjust them.
- Slash commands may not run in headless mode, so `morning.sh` points Claude at the command file instead of calling `/plan-day`.
- Headless and scheduled runs draw on your subscription's usage limits. A daily plan is a small job, but check your limits if you add more.
- Obsidian Git on mobile is limited; pulling the plan to a phone may be unreliable.
- The model can still misjudge: invent an estimate, miss a constraint, or save a wrong inference. The one-line "saved to…" messages and `Changelog.md` exist so you catch that early.
- Sync conflicts stop the scripts rather than resolving automatically; you resolve them.

## 10. Reproduce it

1. Create a private GitHub repo and push this folder as `main`.
2. Clone it twice: once as your Obsidian vault, once as the agent clone (run `git checkout -b agent` there).
3. In the vault: install Tasks, Day Planner and Obsidian Git; configure auto pull, commit and push to `main`; set the daily-note template to `Templates/Daily.md`.
4. In GitHub: allow Actions to write to the repo.
5. In the agent clone: install Claude Code, log in with your subscription, run `claude` and `/onboard`.
6. Make a test edit, run `/plan-day`, and confirm the plan reaches Obsidian. Then try an edit outside the allowed folders and confirm the Action refuses it.
7. Add `scripts/morning.sh` to cron or launchd once it works by hand.
8. After a week, run `/memory-audit` and read `Learned.md` critically.

## 11. Extending it

- Google Calendar and Canvas through MCP servers, read-only first, writing events to a separate "Agent Plan" calendar.
- A constraint solver as a tool for hard guarantees on load and deadlines.
- Push notifications for the morning plan.
- Moving to a cloud scheduled run if the laptop is often asleep at 08:00.
- Stronger isolation: a GitHub ruleset on `main`, or running the agent in a container with only the agent clone mounted.

## Sources

Research notes behind decision 1 and the design:
- Anthropic's restriction on subscription OAuth in third-party tools: https://gigazine.net/gsc_news/en/20260220-anthropic-third-party-block
- The April 2026 enforcement and its fallout: https://falcao.org/posts/anthropic-claude-access-crackdown-ecosystem-fallout/
- Anthropic's statements on personal Agent SDK and `claude -p` use: https://engineerscodex.com/anthropic-claude-subscription-switcharoo
- Hermes context files and memory limits: https://hermes-agent.nousresearch.com/docs/user-guide/features/context-files and https://www.eesel.ai/blog/hermes-agent-review
- Canvas MCP server examples: https://mcpservers.org/tr/servers/ahnopologetic/canvas-lms-mcp
