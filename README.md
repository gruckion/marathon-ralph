# Marathon Ralph

![Marathon Ralph banner](assets/banner.jpg)

**Give it a spec file. Get a tested, working application.**

Marathon Ralph is a Claude Code plugin that autonomously builds applications from specification files. It creates a Linear project, breaks your spec into issues, and works through them one by one — writing code, tests, and E2E tests — until everything is done.

## Why This Exists

Building a full application requires managing dozens of tasks, maintaining quality across sessions, and ensuring every feature is tested. Marathon Ralph automates this entire workflow:

- **No task management** — Issues are auto-generated from your spec
- **No context loss** — Continues across sessions via Linear
- **No skipped tests** — Every feature gets unit, integration, and E2E tests
- **No broken builds** — Verification runs before each new feature

## Quick Start

```bash
# 1. Start a marathon from your spec file
/marathon-ralph:start app_spec.md

# 2. Check progress anytime
/marathon-ralph:status

# 3. Stop if needed (preserves progress)
/marathon-ralph:cancel
```

That's it. The marathon runs autonomously until all issues are complete.

## Example Spec File

```markdown
# My Todo Application

## Overview
A todo app with authentication, task management, and team collaboration.

## Tech Stack
- Frontend: Next.js 14 with App Router
- Styling: Tailwind CSS
- Database: PostgreSQL with Prisma
- Auth: NextAuth.js

## Features

### Authentication
- Email/password sign up and sign in
- OAuth with Google and GitHub
- Password reset via email

### Task Management
- Create, read, update, delete tasks
- Task properties: title, description, due date, priority
- Filter and search tasks

### Team Collaboration
- Create and manage teams
- Invite members via email
- Shared task lists
```

Marathon Ralph reads this spec, creates ~15-25 Linear issues (depending on complexity), and implements each one with full test coverage.

## Prerequisites

Marathon Ralph requires Linear MCP for project management.

### Setup Linear MCP

```bash
# Add the Linear MCP server
claude mcp add --transport http linear https://mcp.linear.app/mcp
```

### Authenticate

1. Type `/mcp` in Claude Code
2. Select **linear** → **Authenticate**
3. Complete OAuth in browser
4. You'll see: "Authentication successful"

## Commands

| Command | Description |
|---------|-------------|
| `/marathon-ralph:start <spec-file>` | Start new marathon from spec |
| `/marathon-ralph:start` | Resume existing marathon |
| `/marathon-ralph:status` | Show progress and current issue |
| `/marathon-ralph:cancel` | Stop marathon (preserves Linear project) |

### Natural Language

You can also use natural language:

- "Marathon this spec.md until complete"
- "How's the marathon going?"
- "Stop the marathon"

## How It Works

For each issue, Marathon Ralph runs this loop:

```markdown
VERIFY → PLAN → CODE → TEST → QA → DONE
```

1. **Verify** — Run tests, lint, type checks (catches regressions)
2. **Plan** — Analyze issue, explore codebase, create implementation plan
3. **Code** — Implement the feature following the plan
4. **Test** — Write unit and integration tests
5. **QA** — Write E2E tests (web projects only)
6. **Done** — Mark issue complete, move to next

If verification fails, a bug issue is automatically created and prioritized.

## State Management

Marathon state is stored in `.claude/marathon-ralph.json`:

```json
{
  "active": true,
  "phase": "coding",
  "session_id": "8a718ed2-2856-435b-bd9a-63c5b8291b42",
  "linear": {
    "project_name": "My Todo App",
    "total_issues": 18
  },
  "stats": {
    "completed": 7,
    "in_progress": 1,
    "todo": 10
  }
}
```

Add `.claude/` to your `.gitignore`.

## Continuous Operation

Marathon Ralph uses a Stop Hook to continue automatically. When Claude would normally exit, the hook checks for remaining issues and continues the loop.

**Session-scoped:** The marathon only affects the session that started it. Other Claude sessions working in the same directory are not blocked by the Stop hook.

Safety limit: 100 iterations per session. Resume with `/marathon-ralph:start` if reached.

---

## Troubleshooting

<details>
<summary><strong>Linear MCP not connected</strong></summary>

```bash
# Check if Linear is listed
claude mcp list

# Add if missing
claude mcp add --transport http linear https://mcp.linear.app/mcp

# Restart Claude Code
```

</details>

<details>
<summary><strong>Linear MCP not authenticated</strong></summary>

1. Type `/mcp` in Claude Code
2. Select **linear** → **Authenticate**
3. Complete OAuth flow in browser

If it keeps failing, clear cookies for `mcp.linear.app` and retry.
</details>

<details>
<summary><strong>Marathon stuck</strong></summary>

1. Check status: `/marathon-ralph:status`
2. Cancel and restart: `/marathon-ralph:cancel` then `/marathon-ralph:start`

</details>

<details>
<summary><strong>State file corrupted</strong></summary>

```bash
rm .claude/marathon-ralph.json
```

Then start fresh. Check Linear for actual progress.
</details>

<details>
<summary><strong>Stop hook not working</strong></summary>

1. Verify `hooks/stop-hook.sh` exists and is executable
2. Check `.claude/marathon-ralph.json` has `active: true`

</details>

---

## Architecture

```
marathon-ralph/
├── agents/           # Specialized subagents
│   ├── setup.md      # Verify Linear connection
│   ├── init.md       # Create project + issues
│   ├── verify.md     # Run tests/lint/types
│   ├── plan.md       # Create implementation plan
│   ├── code.md       # Implement feature
│   ├── test.md       # Write tests
│   └── qa.md         # Write E2E tests
├── commands/         # Slash commands
│   ├── start.md
│   ├── status.md
│   └── cancel.md
├── hooks/            # Stop hook for continuous operation
└── skills/           # Natural language triggers
```

### Agent Models

| Agent | Model | Purpose |
|-------|-------|---------|
| setup | haiku | Fast environment checks |
| init | opus | Complex spec analysis |
| verify, plan, code, test, qa | sonnet | Implementation work |

---

## Related

- [Chief Wiggum](../chief-wiggum/) — Single-session iterative development
- [Ralph Wiggum technique](https://ghuntley.com/ralph/) — Original methodology
