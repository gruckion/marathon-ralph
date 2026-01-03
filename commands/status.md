---
description: Check marathon progress and Linear project status
allowed-tools: ["Bash", "Read"]
---

# Marathon Ralph Status

Check the current marathon session status with live data from Linear.

## Process

### Step 1: Check State File Exists

```bash
test -f .claude/marathon-ralph.json && echo "EXISTS" || echo "NOT_FOUND"
```

### Step 2: Handle NOT_FOUND

If the state file does not exist, report:

```markdown
Marathon Ralph Status
---------------------
No active marathon session.

To start a new marathon:
  /marathon-ralph:run --spec-file <path-to-spec.md>
```

### Step 3: Handle EXISTS

Read `.claude/marathon-ralph.json` and display status based on the `phase` field.

#### Phase: setup

```markdown
Marathon Ralph Status
---------------------
Phase: Setup
Status: Verifying environment

Spec File: <spec_file if present>
Started: <created_at>
Last Updated: <last_updated>

Environment setup in progress. Linear MCP being verified.
```

#### Phase: init

```markdown
Marathon Ralph Status
---------------------
Phase: Initialization
Status: Creating Linear project

Spec File: <spec_file>
Started: <created_at>
Last Updated: <last_updated>

Linear project and issues are being created from the specification.
```

#### Phase: coding

When in coding phase, query Linear for real-time status:

1. **Query Linear for issue counts** using Linear MCP tools:
   - Get all issues in the project
   - Count by status: Done, In Progress, Todo/Backlog
   - Identify the current issue being worked on (In Progress status)

2. **Query META issue for recent activity**:
   - Read comments from the META issue (`linear.meta_issue_id`)
   - Show last 3-5 session notes

3. **Calculate progress**:
   - Progress percentage = (completed / total_issues) * 100

4. **Display status**:

```markdown
Marathon Ralph Status
---------------------
Phase: Coding
Status: Active Development

Spec File: <spec_file>
Linear Project: <linear.project_name> (<linear.team_name>)
Meta Issue: <linear.meta_issue_id>

Progress: [=========>          ] 45% (14/31 issues)

Issue Breakdown:
  Done:        14
  In Progress: 1
  Todo:        16

Current Issue: <current_issue.id> - <current_issue.title>

Recent Activity (from META issue):
  [2025-01-02 14:30] Completed ABC-14: User authentication
  [2025-01-02 12:15] Completed ABC-13: Database schema
  [2025-01-02 10:00] Started session, resumed from ABC-12

Started: <created_at>
Last Updated: <last_updated>
```

#### Phase: complete

```markdown
Marathon Ralph Status
---------------------
Phase: Complete
Status: Marathon Finished

Spec File: <spec_file>
Linear Project: <linear.project_name> (<linear.team_name>)
Meta Issue: <linear.meta_issue_id>

Final Stats:
  Total Issues: <linear.total_issues>
  Completed: <stats.completed>

Started: <created_at>
Completed: <last_updated>

To start a new marathon:
  /marathon-ralph:run --spec-file <path-to-spec.md>
```

### Step 4: Handle Partial State

If any expected fields are missing, show what is available and note missing information:

```markdown
Marathon Ralph Status
---------------------
Phase: <phase>
Status: <active ? "Active" : "Inactive">

<Available fields...>

Note: Some state information is incomplete.
```

### Step 5: Linear Query Instructions (for coding phase)

When in coding phase, use Linear MCP tools to get live data:

1. **Get project issues**:
   - Use available Linear MCP tools to query issues by project
   - Look for tools like `mcp__linear__get_issues`, `mcp__linear__search_issues`, or similar
   - Filter by project ID from state file

2. **Count by status**:
   - Done/Completed status
   - In Progress status
   - Todo/Backlog/Open status

3. **Get META issue comments**:
   - Query comments on the META issue for session history
   - Display most recent entries

4. **Identify current issue**:
   - Look for issue with "In Progress" status
   - If multiple, show the one with highest priority or most recent update

## State File Schema Reference

```json
{
  "active": true,
  "phase": "setup|init|coding|complete",
  "spec_file": "path/to/spec.md",
  "linear": {
    "team_id": "abc123-def456",
    "team_name": "My Team",
    "project_id": "proj_xyz789",
    "project_name": "My App",
    "meta_issue_id": "ABC-1",
    "total_issues": 35
  },
  "current_issue": {
    "id": "ABC-15",
    "title": "Implement user authentication"
  },
  "stats": {
    "completed": 14,
    "in_progress": 1,
    "todo": 20
  },
  "created_at": "2025-01-02T10:30:00Z",
  "last_updated": "2025-01-02T14:45:00Z"
}
```

## Progress Bar Rendering

Calculate and render a visual progress bar:

```markdown
Progress: [===========>        ] 55% (17/31 issues)
```

- Total width: 20 characters
- Filled characters: floor(percentage / 5)
- Arrow at the end of filled section
- Empty characters: remaining space

Example calculation for 55%:

- Filled = floor(55 / 5) = 11 characters
- Display: `[===========>        ]`

## Error Handling

- If state file is corrupted JSON: Report parsing error, suggest checking file
- If Linear MCP unavailable in coding phase: Show cached stats from state file with note
- If Linear query fails: Fall back to state file data with warning
