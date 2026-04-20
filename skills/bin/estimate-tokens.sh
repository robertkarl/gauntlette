#!/usr/bin/env bash
# estimate-tokens.sh - Extract or estimate token usage from Claude Code or Codex JSONL session files.
#
# Usage:
#   ./estimate-tokens.sh <path-to-session.jsonl>
#   ./estimate-tokens.sh --session <session-id>
#   ./estimate-tokens.sh --latest
#   ./estimate-tokens.sh --summary <directory>
#
# Output formats:
#   Default: human-readable summary
#   --json:  machine-parseable JSON

set -uo pipefail

CLAUDE_ROOT="$HOME/.claude/projects"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
CODEX_SESSION_ROOT="$CODEX_ROOT/sessions"
CODEX_ARCHIVE_ROOT="$CODEX_ROOT/archived_sessions"

usage() {
    echo "Usage: $0 [OPTIONS] <jsonl-file>"
    echo ""
    echo "Options:"
    echo "  --json           Output as JSON instead of human-readable"
    echo "  --latest         Analyze the most recently modified JSONL from Claude Code or Codex"
    echo "  --session ID     Find and analyze a specific session by ID"
    echo "  --summary DIR    Summarize all JSONL files in a directory"
    echo "  -h, --help       Show this help"
    exit 1
}

for cmd in jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed" >&2
        exit 1
    fi
done

JSON_OUTPUT=false
MODE="file"
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --latest)
            MODE="latest"
            shift
            ;;
        --session)
            [[ $# -lt 2 ]] && usage
            MODE="session"
            TARGET="$2"
            shift 2
            ;;
        --summary)
            [[ $# -lt 2 ]] && usage
            MODE="summary"
            TARGET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

SEARCH_ROOTS=()

add_search_root() {
    local root="$1"
    if [[ -d "$root" ]]; then
        SEARCH_ROOTS+=("$root")
    fi
}

add_search_root "$CLAUDE_ROOT"
add_search_root "$CODEX_SESSION_ROOT"
add_search_root "$CODEX_ARCHIVE_ROOT"

find_latest_jsonl() {
    [[ ${#SEARCH_ROOTS[@]} -eq 0 ]] && return 1

    find "${SEARCH_ROOTS[@]}" -name "*.jsonl" -type f -exec stat -f '%m %N' {} + 2>/dev/null \
        | sort -rn | head -1 | sed 's/^[0-9]* //'
}

find_session_jsonl() {
    local session_id="$1"
    local candidate=""

    candidate=$(find "$CODEX_SESSION_ROOT" "$CODEX_ARCHIVE_ROOT" -name "*${session_id}*.jsonl" -type f 2>/dev/null | head -1)
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    candidate=$(grep -rl "\"id\":\"${session_id}\"" "$CODEX_SESSION_ROOT" "$CODEX_ARCHIVE_ROOT" --include="*.jsonl" 2>/dev/null | head -1)
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    candidate=$(grep -rl "\"sessionId\":\"${session_id}\"" "$CLAUDE_ROOT" --include="*.jsonl" 2>/dev/null | head -1)
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    return 1
}

detect_format() {
    local file="$1"
    local first_type

    first_type=$(jq -r '.type // empty' "$file" 2>/dev/null | head -1)
    case "$first_type" in
        session_meta|event_msg|response_item)
            echo "codex"
            ;;
        *)
            echo "claude"
            ;;
    esac
}

analyze_claude_jsonl() {
    local file="$1"

    jq -c '.' "$file" 2>/dev/null | jq -s '
    def estimate_from_content:
        (tostring | length) / 4 | floor;

    [.[] | select(.type == "assistant" and .message.usage != null)] as $with_usage |
    [.[] | select(.type == "assistant" and .message.usage == null)] as $without_usage |
    [.[] | select(.type == "user")] as $user_msgs |

    ($with_usage | map(.message.usage.input_tokens // 0) | add // 0) as $native_input |
    ($with_usage | map(.message.usage.output_tokens // 0) | add // 0) as $native_output |
    ($with_usage | map(.message.usage.cache_read_input_tokens // 0) | add // 0) as $native_cache_read |
    ($with_usage | map(.message.usage.cache_creation_input_tokens // 0) | add // 0) as $native_cache_create |

    ($without_usage | map(.message.content | estimate_from_content) | add // 0) as $est_output |
    ($user_msgs | map(.message.content | estimate_from_content) | add // 0) as $est_input |

    ([.[] | select(.type == "system" and .subtype == "turn_duration") | .durationMs // 0] | add // 0) as $total_duration_ms |

    ($with_usage | length) as $native_count |
    ($without_usage | length) as $estimated_count |
    ($user_msgs | length) as $user_count |

    ($with_usage | map(.message.model // "unknown") | unique) as $models |

    {
        native_input_tokens: $native_input,
        native_output_tokens: $native_output,
        cache_read_tokens: $native_cache_read,
        cache_creation_tokens: $native_cache_create,
        reasoning_output_tokens: 0,
        estimated_input_tokens: $est_input,
        estimated_output_tokens: $est_output,
        total_native_tokens: ($native_input + $native_output + $native_cache_read + $native_cache_create),
        total_estimated_tokens: ($est_input + $est_output),
        total_tokens: ($native_input + $native_output + $native_cache_read + $native_cache_create + $est_input + $est_output),
        assistant_messages_with_usage: $native_count,
        assistant_messages_without_usage: $estimated_count,
        user_messages: $user_count,
        total_duration_ms: $total_duration_ms,
        models: $models,
        source: (if $native_count > 0 then "native" elif $estimated_count > 0 then "estimated" else "empty" end),
        format: "claude"
    }
    '
}

analyze_codex_jsonl() {
    local file="$1"

    jq -c '.' "$file" 2>/dev/null | jq -s '
    def estimate_from_text:
        (tostring | length) / 4 | floor;

    (([.[] | select(.type == "event_msg" and .payload.type == "token_count") | .payload.info.total_token_usage] | last) // {}) as $usage |
    ([.[] | select(.type == "session_meta") | (.payload.model_provider // .payload.originator // empty)] | unique) as $model_candidates |
    ([.[] | select(.type == "event_msg" and .payload.type == "user_message")] | length) as $user_count |
    ([.[] | select(.type == "response_item" and .payload.type == "message" and .payload.role == "assistant")] | length) as $assistant_count |
    ([.[] | select(.type == "event_msg" and .payload.type == "task_started") | .payload.started_at] | first) as $started |
    ([.[] | select(.type == "event_msg" and .payload.type == "task_complete") | .payload.completed_at] | last) as $completed |
    ([.[] | select(.type == "event_msg" and .payload.type == "user_message") | .payload.message] | map(estimate_from_text) | add // 0) as $est_input |
    ([.[] | select(.type == "response_item" and .payload.type == "message" and .payload.role == "assistant") | .payload.content[]? | select(.type == "output_text") | .text] | map(estimate_from_text) | add // 0) as $est_output |
    ($usage.input_tokens // 0) as $input |
    ($usage.cached_input_tokens // 0) as $cached |
    ($usage.output_tokens // 0) as $output |
    ($usage.reasoning_output_tokens // 0) as $reasoning |
    ($input + $cached + $output + $reasoning) as $native_total |
    ($est_input + $est_output) as $estimated_total |
    {
        native_input_tokens: $input,
        native_output_tokens: $output,
        cache_read_tokens: $cached,
        cache_creation_tokens: 0,
        reasoning_output_tokens: $reasoning,
        estimated_input_tokens: (if $native_total > 0 then 0 else $est_input end),
        estimated_output_tokens: (if $native_total > 0 then 0 else $est_output end),
        total_native_tokens: $native_total,
        total_estimated_tokens: (if $native_total > 0 then 0 else $estimated_total end),
        total_tokens: (if $native_total > 0 then $native_total else $estimated_total end),
        assistant_messages_with_usage: (if $native_total > 0 then $assistant_count else 0 end),
        assistant_messages_without_usage: (if $native_total > 0 then 0 else $assistant_count end),
        user_messages: $user_count,
        total_duration_ms: (if (($started // null) != null and ($completed // null) != null) then (($completed - $started) * 1000) else 0 end),
        models: (if ($model_candidates | length) > 0 then $model_candidates else ["codex"] end),
        source: (if $native_total > 0 then "native" elif $estimated_total > 0 then "estimated" else "empty" end),
        format: "codex"
    }
    '
}

analyze_jsonl() {
    local file="$1"
    local format

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    format=$(detect_format "$file")
    case "$format" in
        codex)
            analyze_codex_jsonl "$file"
            ;;
        *)
            analyze_claude_jsonl "$file"
            ;;
    esac
}

format_human() {
    local json="$1"
    local file="$2"

    local total
    total=$(echo "$json" | jq -r '.total_tokens')
    local native
    native=$(echo "$json" | jq -r '.total_native_tokens')
    local estimated
    estimated=$(echo "$json" | jq -r '.total_estimated_tokens')
    local source
    source=$(echo "$json" | jq -r '.source')
    local format
    format=$(echo "$json" | jq -r '.format // "unknown"')
    local input
    input=$(echo "$json" | jq -r '.native_input_tokens')
    local output
    output=$(echo "$json" | jq -r '.native_output_tokens')
    local reasoning
    reasoning=$(echo "$json" | jq -r '.reasoning_output_tokens // 0')
    local cache_read
    cache_read=$(echo "$json" | jq -r '.cache_read_tokens')
    local cache_create
    cache_create=$(echo "$json" | jq -r '.cache_creation_tokens')
    local duration
    duration=$(echo "$json" | jq -r '.total_duration_ms')
    local models
    models=$(echo "$json" | jq -r '.models | join(", ")')
    local user_msgs
    user_msgs=$(echo "$json" | jq -r '.user_messages')
    local assist_native
    assist_native=$(echo "$json" | jq -r '.assistant_messages_with_usage')
    local assist_est
    assist_est=$(echo "$json" | jq -r '.assistant_messages_without_usage')

    echo "=== Token Usage Report ==="
    echo "File: $file"
    echo "Format: $format"
    echo "Source: $source token counts"
    echo "Models: $models"
    echo ""
    echo "--- Native Token Counts ---"
    printf "  Input tokens:          %'d\n" "$input"
    printf "  Output tokens:         %'d\n" "$output"
    if [[ "$reasoning" -gt 0 ]]; then
        printf "  Reasoning tokens:      %'d\n" "$reasoning"
    fi
    printf "  Cache read tokens:     %'d\n" "$cache_read"
    printf "  Cache creation tokens: %'d\n" "$cache_create"
    printf "  Subtotal (native):     %'d\n" "$native"
    echo ""
    if [[ "$estimated" -gt 0 ]]; then
        echo "--- Estimated Tokens (no usage data) ---"
        printf "  Estimated input:       %'d\n" "$(echo "$json" | jq -r '.estimated_input_tokens')"
        printf "  Estimated output:      %'d\n" "$(echo "$json" | jq -r '.estimated_output_tokens')"
        printf "  Subtotal (estimated):  %'d\n" "$estimated"
        echo ""
    fi
    printf "TOTAL TOKENS:            %'d\n" "$total"
    echo ""
    echo "--- Session Info ---"
    echo "  User messages:    $user_msgs"
    echo "  Assistant (native): $assist_native"
    echo "  Assistant (est.):   $assist_est"
    if [[ "$duration" -gt 0 ]]; then
        printf "  Total duration:   %d seconds\n" "$((duration / 1000))"
    fi
}

case "$MODE" in
    file)
        [[ -z "$TARGET" ]] && usage
        result=$(analyze_jsonl "$TARGET")
        if $JSON_OUTPUT; then
            echo "$result"
        else
            format_human "$result" "$TARGET"
        fi
        ;;
    latest)
        file=$(find_latest_jsonl)
        if [[ -z "$file" ]]; then
            echo "Error: No JSONL files found in Claude Code or Codex session storage" >&2
            exit 1
        fi
        result=$(analyze_jsonl "$file")
        if $JSON_OUTPUT; then
            echo "$result"
        else
            format_human "$result" "$file"
        fi
        ;;
    session)
        [[ -z "$TARGET" ]] && usage
        file=$(find_session_jsonl "$TARGET")
        if [[ -z "$file" ]]; then
            echo "Error: No JSONL file found for session $TARGET" >&2
            exit 1
        fi
        result=$(analyze_jsonl "$file")
        if $JSON_OUTPUT; then
            echo "$result"
        else
            format_human "$result" "$file"
        fi
        ;;
    summary)
        [[ -z "$TARGET" ]] && usage
        if [[ ! -d "$TARGET" ]]; then
            echo "Error: Directory not found: $TARGET" >&2
            exit 1
        fi
        echo "=== Token Usage Summary ==="
        echo "Directory: $TARGET"
        echo ""
        printf "%-60s %12s %12s %12s\n" "FILE" "NATIVE" "ESTIMATED" "TOTAL"
        printf "%-60s %12s %12s %12s\n" "----" "------" "---------" "-----"
        find "$TARGET" -name "*.jsonl" -type f | sort | while read -r f; do
            result=$(analyze_jsonl "$f" 2>/dev/null || echo '{"total_native_tokens":0,"total_estimated_tokens":0,"total_tokens":0}')
            native=$(echo "$result" | jq -r '.total_native_tokens')
            estimated=$(echo "$result" | jq -r '.total_estimated_tokens')
            total=$(echo "$result" | jq -r '.total_tokens')
            basename=$(basename "$f")
            printf "%-60s %'12d %'12d %'12d\n" "$basename" "$native" "$estimated" "$total"
        done
        ;;
esac
