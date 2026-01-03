---
description: Cancel the active marathon
allowed-tools: ["Read", "Write", "Bash"]
---

# Cancel Marathon

Stop the current marathon session and preserve the Linear project for later.

## Process

1. **Read State**: Check `.claude/marathon-ralph.json` for active marathon
2. **Validate**: If no active marathon, report and exit
3. **Confirm**: Show current state and ask user to confirm cancellation
4. **Cancel**: Update state file and add note to Linear META issue
5. **Report**: Inform user the marathon is cancelled but project preserved

## Step 1: Read State

Read the marathon state file:

```bash
cat .claude/marathon-ralph.json
```

If the file does not exist or `active` is `false`:

- Report: "No active marathon to cancel."
- Exit without further action

## Step 2: Show Current State

Display the current marathon status:

```markdown
Marathon: [project_name]
Phase: [phase]
Progress: [completed]/[total_issues] issues completed
Current Issue: [current_issue.id] - [current_issue.title]
```

## Step 3: Confirm with User

Ask for explicit confirmation:

```markdown
Cancel marathon "[project_name]"? This will stop autonomous processing. (y/n)
```

Wait for user response. If not "y" or "yes":

- Report: "Cancellation aborted. Marathon will continue."
- Exit without changes

## Step 4: Update State

If user confirms, update `.claude/marathon-ralph.json`:

```json
{
  "active": false,
  // Keep existing phase (do NOT change to "complete")
  // Keep all other fields for reference
}
```

Only set `active: false`. Keep the phase as-is so status shows it was cancelled, not completed naturally.

## Step 5: Update Linear META Issue

If `linear.meta_issue_id` exists in state, add a comment to the META issue:

```markdown
## Marathon Cancelled - [timestamp]

Marathon was manually cancelled by user.
Progress at cancellation: [completed]/[total_issues] issues completed.

The Linear project and remaining issues have been preserved.
To resume, run `/marathon-ralph:run` again.
```

Use the Linear MCP to add this comment:

- Tool: `linear_addComment`
- Issue ID: The META issue ID from state

## Step 6: Report Completion

Report to user:

```markdown
Marathon cancelled.

Summary:
- Project: [project_name]
- Progress: [completed]/[total_issues] issues completed
- Linear project preserved

You can resume later with /marathon-ralph:run or view progress in Linear.
```

## Important Notes

- This command does NOT delete the Linear project or issues
- The user can resume the marathon later by running `/marathon-ralph:run`
- Remaining issues stay in "Todo" status in Linear
- Any issue currently "In Progress" stays in that status (user can update manually in Linear)
- The state file is preserved for reference and potential resume

## Error Handling

### State File Not Found

If `.claude/marathon-ralph.json` does not exist:

```markdown
No active marathon to cancel.

To start a new marathon, use:
/marathon-ralph:run --spec-file path/to/spec.md
```

### Linear MCP Not Available

If unable to add comment to META issue:

- Log warning but continue with cancellation
- The state file update is the critical action
- Linear comment is informational only

### State File Corruption

If state file exists but is malformed:

- Report the error
- Suggest manual deletion: `rm .claude/marathon-ralph.json`
- Do not attempt automatic recovery
