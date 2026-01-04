#!/bin/bash

# marathon-ralph Stop Hook
# Checks if marathon should continue or allow exit
# Enables continuous autonomous operation by blocking exit when marathon is active

set -e

# Read input from stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract current session ID from stdin JSON
CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // empty')

# Get project directory from environment or default to current
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/marathon-ralph.json"

# If no state file exists, allow exit (not in a marathon)
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Read marathon state using jq
ACTIVE=$(jq -r '.active // false' "$STATE_FILE" 2>/dev/null || echo "false")
PHASE=$(jq -r '.phase // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown")
MARATHON_SESSION=$(jq -r '.session_id // empty' "$STATE_FILE" 2>/dev/null || echo "")

# If not active or phase is complete, allow exit
if [ "$ACTIVE" != "true" ] || [ "$PHASE" = "complete" ]; then
  exit 0
fi

# SESSION SCOPING: Determine if this session should own the marathon
#
# Case 1: No session_id in state (unclaimed marathon)
#   → Claim ownership by writing current session_id to state
#   → Then block exit to continue the marathon
#
# Case 2: session_id matches current session
#   → This session owns the marathon, block exit
#
# Case 3: session_id doesn't match (another session owns it)
#   → Allow exit, this is not our marathon

if [ -z "$MARATHON_SESSION" ]; then
  # Unclaimed marathon - claim ownership
  TEMP_FILE="${STATE_FILE}.tmp.$$"
  if jq --arg sid "$CURRENT_SESSION" '.session_id = $sid' "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null; then
    mv "$TEMP_FILE" "$STATE_FILE"
  else
    rm -f "$TEMP_FILE"
  fi
  # Now we own it, continue to blocking logic below
elif [ "$MARATHON_SESSION" != "$CURRENT_SESSION" ]; then
  # Another session owns this marathon - allow exit
  exit 0
fi
# else: session_id matches current session - we own it, continue to block

# Check iteration safety limit to prevent infinite loops
ITERATIONS=$(jq -r '.stop_hook_iterations // 0' "$STATE_FILE" 2>/dev/null || echo "0")
MAX_ITERATIONS=25  # Reduced from 100 for faster failure detection

# Validate iterations is a number
if ! [[ "$ITERATIONS" =~ ^[0-9]+$ ]]; then
  ITERATIONS=0
fi

if [ "$ITERATIONS" -ge "$MAX_ITERATIONS" ]; then
  # Safety limit reached - allow exit and notify
  cat << 'EOF'
{
  "decision": "allow",
  "reason": "Max iterations (25) reached. Marathon paused for safety. Resume with /marathon-ralph:run"
}
EOF
  exit 0
fi

# Get current issue for failure tracking
CURRENT_ISSUE_ID=$(jq -r '.current_issue.id // .current_issue.identifier // empty' "$STATE_FILE" 2>/dev/null || echo "")

# Check failure limits if we have a current issue
if [ -n "$CURRENT_ISSUE_ID" ]; then
  # Get script directory for update-state.sh
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  UPDATE_STATE="$SCRIPT_DIR/../skills/update-state/scripts/update-state.sh"

  if [ -x "$UPDATE_STATE" ]; then
    # Check limits
    LIMITS_CHECK=$("$UPDATE_STATE" check-limits "$CURRENT_ISSUE_ID" 2>/dev/null || echo "{}")

    # Parse limit check results
    SHOULD_ABORT=$(echo "$LIMITS_CHECK" | jq -r '.should_abort // false' 2>/dev/null || echo "false")
    SHOULD_SKIP_ISSUE=$(echo "$LIMITS_CHECK" | jq -r '.should_skip_issue // false' 2>/dev/null || echo "false")
    SAME_ERROR_REPEATING=$(echo "$LIMITS_CHECK" | jq -r '.same_error_repeating // false' 2>/dev/null || echo "false")

    if [ "$SHOULD_ABORT" = "true" ]; then
      # Too many consecutive failures - abort marathon
      ABORT_REASON=$(echo "$LIMITS_CHECK" | jq -r '.abort_reason // "too many failures"' 2>/dev/null)
      cat << EOF
{
  "decision": "allow",
  "reason": "Marathon aborted: $ABORT_REASON. Review errors and resume with /marathon-ralph:run"
}
EOF
      # Mark marathon complete to stop further attempts
      "$UPDATE_STATE" mark-complete 2>/dev/null || true
      exit 0
    fi

    if [ "$SHOULD_SKIP_ISSUE" = "true" ] || [ "$SAME_ERROR_REPEATING" = "true" ]; then
      # Skip this issue and continue to next
      SKIP_REASON="max attempts exceeded"
      if [ "$SAME_ERROR_REPEATING" = "true" ]; then
        SKIP_REASON="same error repeating (stuck in loop)"
      fi

      # Mark issue as skipped in state
      "$UPDATE_STATE" skip-issue "$CURRENT_ISSUE_ID" "$SKIP_REASON" 2>/dev/null || true

      # Continue to next issue - modify the block message
      cat << EOF
{
  "decision": "block",
  "reason": "Issue $CURRENT_ISSUE_ID skipped: $SKIP_REASON. Continue to next issue:\n\n1. Read state file for project context\n2. Query Linear for next Todo issue\n3. If no issues remain, complete marathon\n4. If issues remain, continue with verify-plan-code-test-qa loop"
}
EOF
      exit 0
    fi
  fi
fi

# Increment iteration count in state file
NEW_ITERATIONS=$((ITERATIONS + 1))
TEMP_FILE="${STATE_FILE}.tmp.$$"
jq ".stop_hook_iterations = $NEW_ITERATIONS" "$STATE_FILE" > "$TEMP_FILE" 2>/dev/null
if [ $? -eq 0 ]; then
  mv "$TEMP_FILE" "$STATE_FILE"
else
  rm -f "$TEMP_FILE"
fi

# Marathon is active in coding phase - block exit and continue
# Provide instructions for the next iteration of the marathon loop
cat << 'EOF'
{
  "decision": "block",
  "reason": "Marathon in progress. Continue with next issue:\n\n1. Read `.claude/marathon-ralph.json` for project context (project_id, team_id, current_issue)\n2. Run marathon-verify agent to check codebase health (tests, lint, types)\n3. Query Linear for next Todo issue in the project using mcp__linear__list_issues with project filter\n4. If no Todo issues remain:\n   - Update `.claude/marathon-ralph.json` with phase: \"complete\" and active: false\n   - Add completion note to META issue in Linear\n   - Report marathon complete\n5. If issues remain:\n   - Update state file with new current_issue\n   - Run marathon-plan agent to create implementation plan\n   - Run marathon-code agent to implement the feature\n   - Run marathon-test agent to write unit/integration tests\n   - Run marathon-qa agent to write E2E tests (web projects only)\n   - Mark issue Done in Linear using mcp__linear__update_issue\n   - Update stats in state file\n   - Commit all changes with Linear issue ID\n   - Continue to next issue"
}
EOF

exit 0
