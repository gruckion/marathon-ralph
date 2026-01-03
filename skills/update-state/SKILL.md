---
name: update-state
description: Programmatically update marathon-ralph state file using deterministic jq commands. Use this instead of manually editing the JSON file.
allowed-tools: Bash
---

# Update Marathon State

This skill provides deterministic state file updates using jq. **Always use this skill instead of manually editing `.claude/marathon-ralph.json`.**

## Why Use This Skill

- **Deterministic**: jq commands are atomic and predictable
- **Zero token overhead**: Script executes without loading into context
- **Consistent**: Same operation always produces same result
- **Safe**: Prevents malformed JSON from manual edits

## Available Commands

### Complete an Issue

Marks an issue as done: increments completed count, decrements todo, clears current_issue.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" complete-issue
```

### Start an Issue

Sets the current issue being worked on.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" start-issue "<issue_id>" "<issue_title>"
```

### Set Phase

Updates the marathon phase (setup, init, coding, complete).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" set-phase "<phase>"
```

### Mark Complete

Marks the entire marathon as complete (sets active=false, phase=complete).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" mark-complete
```

### Update Stats

Manually update the stats object.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" update-stats <completed> <in_progress> <todo>
```

### Clear Session

Clears the session_id (used when --force takeover is needed).

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" clear-session
```

## Usage Examples

After completing the verify-plan-code-test-qa cycle for an issue:

```bash
# Mark the issue complete in state file
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" complete-issue
```

When starting work on a new issue:

```bash
# Set current issue
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" start-issue "GRU-220" "Step 5: Toggle Completion"
```

When all issues are done:

```bash
# Mark marathon complete
bash "${CLAUDE_PLUGIN_ROOT}/skills/update-state/scripts/update-state.sh" mark-complete
```

## State File Location

The script uses `${CLAUDE_PROJECT_DIR:-.}/.claude/marathon-ralph.json`

## Exit Codes

- `0`: Success
- `1`: Invalid arguments or missing state file
- `2`: jq command failed
