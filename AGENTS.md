# Marathon Ralph

Autonomous development plugin. Creates Linear projects from specs, works through issues with verify-plan-code-test-qa loop.

## Commands

| Command                             | Description                              |
| ----------------------------------- | ---------------------------------------- |
| `/marathon-ralph:run <spec>`        | Start new marathon from spec file        |
| `/marathon-ralph:run`               | Resume existing marathon                 |
| `/marathon-ralph:status`            | Show progress and current issue          |
| `/marathon-ralph:cancel`            | Stop marathon (preserves Linear project) |

## Critical Warnings

### Next.js/React SSR

- **ALWAYS run `npm run build`** before marking issues complete - catches hydration errors missed by dev mode
- **Never nest interactive elements**: `<button>` inside `<button>`, `<a>` inside `<button>`, etc.
- **DialogTrigger + Button = invalid HTML** if DialogTrigger renders as button (use `asChild`)
- Hydration errors often only appear in production build, not dev server

### HTML Validity

- Check component composition - wrapper components may render invalid nesting
- `<button>` can only contain phrasing content (no `<div>`, no nested buttons)
- When in doubt, inspect rendered HTML structure

### E2E Tests

- **Monitor browser console** for errors during tests - tests can pass while app has runtime errors
- Use `page.on('console', ...)` or `page.on('pageerror', ...)` to catch React errors
- Failed hydration = broken app even if tests "pass"

### Command Execution Circuit Breaker

**CRITICAL: Prevent infinite retry loops**

When running commands (tests, builds, etc.), apply these circuit breaker rules:

1. **Empty output detection**: If a command returns empty output (0 chars) or times out:
   - Do NOT immediately retry the same command
   - First check: Is the working directory correct?
   - Second check: Does the script exist? (check package.json)
   - Third check: For monorepos, are you using the correct filter?

2. **Maximum retries**: After 3 failed attempts with the same command:
   - STOP and report the issue
   - Document what was tried
   - Suggest alternative approaches

3. **Command variation**: If a command fails, try variations:
   - For monorepos: Try `bun run --filter=<workspace> test` instead of `bun run test`
   - Try with verbose flags: `--verbose` or `-v`
   - Check if the command exists: Read package.json scripts first

4. **Timeout handling**: If commands consistently timeout:
   - Try running a simpler command first to verify the environment
   - Check for hung processes: `ps aux | grep node`
   - Try with longer timeout or in background

**Example circuit breaker flow:**

```markdown
Attempt 1: bun run test → empty output
  → Check: Does root package.json have "test" script? NO
  → Check: Is this a monorepo? YES (turbo.json exists)
Attempt 2: bun run --filter=web test → 2990 chars output
  → Success!
```

**Never retry the same failing command more than 3 times.**

## Development Loop

```markdown
VERIFY → PLAN → CODE → TEST → QA → EXIT → [stop hook continues]
```

Each iteration processes ONE issue, then the exit agent updates state/Linear and exits. The stop hook handles continuation to the next issue.

## Prerequisites

Linear MCP required:

```bash
claude mcp add --transport http linear https://mcp.linear.app/mcp
```

## Package Manager

Use `ni` (auto-detects package manager):

- `ni` / `ni -D <pkg>` - Install
- `nr <script>` - Run script
- `nx <bin>` - Execute binary

## State

Stored in `.claude/marathon-ralph.json`. Session-scoped via `session_id`.

**State updates use the `update-state` skill** - never edit the JSON file manually. The skill uses jq for atomic, deterministic updates.
