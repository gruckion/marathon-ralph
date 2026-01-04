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

  init-failure-tracking)
    # Initialize failure tracking structure if not present
    atomic_update '
      .failure_tracking = (.failure_tracking // {}) |
      .failure_tracking.global = (.failure_tracking.global // {
        "consecutive_failures": 0,
        "repeated_error_count": 0,
        "last_failure_signature": null
      }) |
      .failure_tracking.issue_attempts = (.failure_tracking.issue_attempts // {}) |
      .config = (.config // {}) |
      .config.failure_limits = (.config.failure_limits // {
        "max_issue_attempts": 5,
        "max_phase_attempts": {"verify": 3, "plan": 3, "code": 3, "test": 5, "qa": 5},
        "max_consecutive_failures": 5,
        "max_repeated_errors": 3,
        "max_stop_hook_iterations": 25
      }) |
      .last_updated = "'"$TIMESTAMP"'"
    '
    ;;

  increment-phase-attempt)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 increment-phase-attempt <issue_id> <phase>" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    PHASE="$3"

    atomic_update '
      .failure_tracking = (.failure_tracking // {}) |
      .failure_tracking.issue_attempts = (.failure_tracking.issue_attempts // {}) |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"] = (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"] // {
        "total_attempts": 0,
        "phases": {},
        "skipped_phases": []
      }) |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].total_attempts += 1 |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"] = (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"] // {
        "attempts": 0,
        "error_signature": null
      }) |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].attempts += 1 |
      .last_updated = "'"$TIMESTAMP"'"
    '
    ;;

  get-phase-attempts)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 get-phase-attempts <issue_id> <phase>" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    PHASE="$3"

    jq -r '.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].attempts // 0' "$STATE_FILE"
    ;;

  record-error)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 record-error <issue_id> <phase> [message]" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    PHASE="$3"
    ERROR_MSG="${4:-unknown error}"

    # Generate error signature by normalizing and hashing
    # Remove timestamps, line numbers, paths to get stable signature
    NORMALIZED_ERROR=$(echo "$ERROR_MSG" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}//g' | sed -E 's/:[0-9]+:[0-9]+//g' | sed -E 's|/[^ ]*||g' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    ERROR_SIGNATURE=$(echo "$NORMALIZED_ERROR" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$NORMALIZED_ERROR" | md5 2>/dev/null || echo "unknown")

    # Get previous signature for this phase
    PREV_SIGNATURE=$(jq -r '.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].error_signature // ""' "$STATE_FILE")
    PREV_GLOBAL_SIGNATURE=$(jq -r '.failure_tracking.global.last_failure_signature // ""' "$STATE_FILE")

    # Check if same signature as before
    if [ "$ERROR_SIGNATURE" = "$PREV_SIGNATURE" ] || [ "$ERROR_SIGNATURE" = "$PREV_GLOBAL_SIGNATURE" ]; then
      # Increment repeated error count
      atomic_update '
        .failure_tracking.global.repeated_error_count = ((.failure_tracking.global.repeated_error_count // 0) + 1) |
        .failure_tracking.global.consecutive_failures = ((.failure_tracking.global.consecutive_failures // 0) + 1) |
        .failure_tracking.global.last_failure_signature = "'"$ERROR_SIGNATURE"'" |
        .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].error_signature = "'"$ERROR_SIGNATURE"'" |
        .last_updated = "'"$TIMESTAMP"'"
      '
    else
      # New error type, reset repeated count but increment consecutive
      atomic_update '
        .failure_tracking.global.repeated_error_count = 1 |
        .failure_tracking.global.consecutive_failures = ((.failure_tracking.global.consecutive_failures // 0) + 1) |
        .failure_tracking.global.last_failure_signature = "'"$ERROR_SIGNATURE"'" |
        .failure_tracking.issue_attempts["'"$ISSUE_ID"'"] = (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"] // {"total_attempts": 0, "phases": {}, "skipped_phases": []}) |
        .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"] = (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"] // {"attempts": 0, "error_signature": null}) |
        .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].error_signature = "'"$ERROR_SIGNATURE"'" |
        .last_updated = "'"$TIMESTAMP"'"
      '
    fi
    echo "Error recorded with signature: $ERROR_SIGNATURE"
    ;;

  skip-phase)
    if [ -z "$2" ] || [ -z "$3" ]; then
      echo "Usage: $0 skip-phase <issue_id> <phase> [reason]" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    PHASE="$3"
    REASON="${4:-exceeded retry limit}"

    atomic_update '
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"] = (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"] // {"total_attempts": 0, "phases": {}, "skipped_phases": []}) |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].skipped_phases = (
        (.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].skipped_phases // []) + [{"phase": "'"$PHASE"'", "reason": "'"$REASON"'", "timestamp": "'"$TIMESTAMP"'"}]
      ) |
      .last_updated = "'"$TIMESTAMP"'"
    '
    echo "Phase $PHASE skipped: $REASON"
    ;;

  skip-issue)
    if [ -z "$2" ]; then
      echo "Usage: $0 skip-issue <issue_id> [reason]" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    REASON="${3:-exceeded retry limit}"

    atomic_update '
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].skipped = true |
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"].skip_reason = "'"$REASON"'" |
      .current_issue = null |
      .last_updated = "'"$TIMESTAMP"'"
    '
    echo "Issue $ISSUE_ID skipped: $REASON"
    ;;

  reset-issue-tracking)
    if [ -z "$2" ]; then
      echo "Usage: $0 reset-issue-tracking <issue_id>" >&2
      exit 1
    fi
    ISSUE_ID="$2"

    atomic_update '
      .failure_tracking.issue_attempts["'"$ISSUE_ID"'"] = {
        "total_attempts": 0,
        "phases": {},
        "skipped_phases": []
      } |
      .last_updated = "'"$TIMESTAMP"'"
    '
    ;;

  reset-on-success)
    # Reset global consecutive failure counters on successful completion
    atomic_update '
      .failure_tracking.global.consecutive_failures = 0 |
      .failure_tracking.global.repeated_error_count = 0 |
      .failure_tracking.global.last_failure_signature = null |
      .stop_hook_iterations = 0 |
      .last_updated = "'"$TIMESTAMP"'"
    '
    ;;

  get-skipped-phases)
    if [ -z "$2" ]; then
      echo "Usage: $0 get-skipped-phases <issue_id>" >&2
      exit 1
    fi
    ISSUE_ID="$2"

    jq -r '.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].skipped_phases // []' "$STATE_FILE"
    ;;

  check-limits)
    if [ -z "$2" ]; then
      echo "Usage: $0 check-limits <issue_id> [phase]" >&2
      exit 1
    fi
    ISSUE_ID="$2"
    PHASE="${3:-}"

    # Get limits from config or use defaults
    MAX_ISSUE_ATTEMPTS=$(jq -r '.config.failure_limits.max_issue_attempts // 5' "$STATE_FILE")
    MAX_CONSECUTIVE_FAILURES=$(jq -r '.config.failure_limits.max_consecutive_failures // 5' "$STATE_FILE")
    MAX_REPEATED_ERRORS=$(jq -r '.config.failure_limits.max_repeated_errors // 3' "$STATE_FILE")

    # Get current values
    ISSUE_ATTEMPTS=$(jq -r '.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].total_attempts // 0' "$STATE_FILE")
    CONSECUTIVE_FAILURES=$(jq -r '.failure_tracking.global.consecutive_failures // 0' "$STATE_FILE")
    REPEATED_ERRORS=$(jq -r '.failure_tracking.global.repeated_error_count // 0' "$STATE_FILE")

    # Build result JSON
    RESULT="{\"issue_id\": \"$ISSUE_ID\""

    # Check issue-level limit
    if [ "$ISSUE_ATTEMPTS" -ge "$MAX_ISSUE_ATTEMPTS" ]; then
      RESULT="$RESULT, \"should_skip_issue\": true, \"reason\": \"max issue attempts ($ISSUE_ATTEMPTS/$MAX_ISSUE_ATTEMPTS) exceeded\""
    else
      RESULT="$RESULT, \"should_skip_issue\": false"
    fi

    # Check global consecutive failures
    if [ "$CONSECUTIVE_FAILURES" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
      RESULT="$RESULT, \"should_abort\": true, \"abort_reason\": \"max consecutive failures ($CONSECUTIVE_FAILURES/$MAX_CONSECUTIVE_FAILURES) exceeded\""
    else
      RESULT="$RESULT, \"should_abort\": false"
    fi

    # Check repeated errors
    if [ "$REPEATED_ERRORS" -ge "$MAX_REPEATED_ERRORS" ]; then
      RESULT="$RESULT, \"same_error_repeating\": true"
    else
      RESULT="$RESULT, \"same_error_repeating\": false"
    fi

    # If phase specified, check phase limit
    if [ -n "$PHASE" ]; then
      MAX_PHASE_ATTEMPTS=$(jq -r '.config.failure_limits.max_phase_attempts["'"$PHASE"'"] // 3' "$STATE_FILE")
      PHASE_ATTEMPTS=$(jq -r '.failure_tracking.issue_attempts["'"$ISSUE_ID"'"].phases["'"$PHASE"'"].attempts // 0' "$STATE_FILE")

      if [ "$PHASE_ATTEMPTS" -ge "$MAX_PHASE_ATTEMPTS" ]; then
        RESULT="$RESULT, \"should_skip_phase\": true, \"phase_reason\": \"max phase attempts ($PHASE_ATTEMPTS/$MAX_PHASE_ATTEMPTS) exceeded\""
      else
        RESULT="$RESULT, \"should_skip_phase\": false"
      fi
      RESULT="$RESULT, \"phase_attempts\": $PHASE_ATTEMPTS, \"max_phase_attempts\": $MAX_PHASE_ATTEMPTS"
    fi

    RESULT="$RESULT, \"issue_attempts\": $ISSUE_ATTEMPTS, \"max_issue_attempts\": $MAX_ISSUE_ATTEMPTS"
    RESULT="$RESULT, \"consecutive_failures\": $CONSECUTIVE_FAILURES, \"repeated_errors\": $REPEATED_ERRORS}"

    echo "$RESULT"
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
    echo "" >&2
    echo "Failure Tracking Commands:" >&2
    echo "  init-failure-tracking             - Initialize failure tracking structure" >&2
    echo "  increment-phase-attempt <id> <p>  - Increment phase attempt counter" >&2
    echo "  get-phase-attempts <id> <phase>   - Get current phase attempt count" >&2
    echo "  record-error <id> <phase> [msg]   - Record error with signature detection" >&2
    echo "  skip-phase <id> <phase> [reason]  - Mark phase as skipped" >&2
    echo "  skip-issue <id> [reason]          - Skip issue entirely" >&2
    echo "  reset-issue-tracking <id>         - Reset tracking for an issue" >&2
    echo "  reset-on-success                  - Reset global failure counters" >&2
    echo "  get-skipped-phases <id>           - Get list of skipped phases" >&2
    echo "  check-limits <id> [phase]         - Check if limits exceeded" >&2
    exit 1
    ;;
esac
