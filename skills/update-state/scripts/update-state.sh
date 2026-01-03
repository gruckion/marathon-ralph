#!/bin/bash

# update-state.sh - Deterministic state file updates for marathon-ralph
# Uses jq for atomic JSON modifications

set -e

# Configuration
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/marathon-ralph.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Check state file exists
if [ ! -f "$STATE_FILE" ]; then
  echo "Error: State file not found: $STATE_FILE" >&2
  exit 1
fi

# Helper: atomic update with temp file
atomic_update() {
  local jq_filter="$1"
  local temp_file="${STATE_FILE}.tmp.$$"

  if jq "$jq_filter" "$STATE_FILE" > "$temp_file" 2>/dev/null; then
    mv "$temp_file" "$STATE_FILE"
    echo "State updated successfully"
  else
    rm -f "$temp_file"
    echo "Error: jq update failed" >&2
    exit 2
  fi
}

# Command handling
case "$1" in
  complete-issue)
    # Increment completed, decrement todo, clear current_issue, update timestamp
    atomic_update "
      .stats.completed = ((.stats.completed // 0) + 1) |
      .stats.todo = ((.stats.todo // 0) - 1) |
      .stats.in_progress = 0 |
      .current_issue = null |
      .last_updated = \"$TIMESTAMP\"
    "
    ;;

  start-issue)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 start-issue <issue_id> <issue_title>" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    ISSUE_TITLE="$3"

    atomic_update "
      .current_issue = {\"id\": \"$ISSUE_ID\", \"identifier\": \"$ISSUE_ID\", \"title\": \"$ISSUE_TITLE\"} |
      .stats.in_progress = 1 |
      .last_updated = \"$TIMESTAMP\"
    "
    ;;

  set-phase)
    if [ -z "$2" ]; then
      echo "Usage: $0 set-phase <phase>" >&2
      exit 1
    fi
    PHASE="$2"

    # Validate phase
    case "$PHASE" in
      setup|init|coding|complete)
        atomic_update ".phase = \"$PHASE\" | .last_updated = \"$TIMESTAMP\""
        ;;
      *)
        echo "Error: Invalid phase. Must be: setup, init, coding, complete" >&2
        exit 1
        ;;
    esac
    ;;

  mark-complete)
    # Set active=false, phase=complete, clear current_issue
    atomic_update "
      .active = false |
      .phase = \"complete\" |
      .current_issue = null |
      .last_updated = \"$TIMESTAMP\"
    "
    ;;

  update-stats)
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo "Usage: $0 update-stats <completed> <in_progress> <todo>" >&2
      exit 1
    fi
    COMPLETED="$2"
    IN_PROGRESS="$3"
    TODO="$4"

    atomic_update "
      .stats.completed = $COMPLETED |
      .stats.in_progress = $IN_PROGRESS |
      .stats.todo = $TODO |
      .last_updated = \"$TIMESTAMP\"
    "
    ;;

  clear-session)
    # Clear session_id for --force takeover
    atomic_update "del(.session_id) | .last_updated = \"$TIMESTAMP\""
    ;;

  reset-iterations)
    # Reset stop_hook_iterations counter
    atomic_update ".stop_hook_iterations = 0 | .last_updated = \"$TIMESTAMP\""
    ;;

  *)
    echo "Usage: $0 <command> [args...]" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  complete-issue                    - Mark current issue done, update stats" >&2
    echo "  start-issue <id> <title>          - Set current issue being worked on" >&2
    echo "  set-phase <phase>                 - Set marathon phase" >&2
    echo "  mark-complete                     - Mark marathon as complete" >&2
    echo "  update-stats <done> <wip> <todo>  - Manually set stats" >&2
    echo "  clear-session                     - Clear session_id for takeover" >&2
    echo "  reset-iterations                  - Reset stop_hook_iterations to 0" >&2
    exit 1
    ;;
esac
