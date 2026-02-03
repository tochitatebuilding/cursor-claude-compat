#!/bin/bash
#
# Rate limit management script for GitHub Actions
# Manages API call rate limits using GitHub Actions cache
#
# Usage:
#   rate-limit.sh check [limit_type] [limit_count]
#   rate-limit.sh increment [limit_type]
#   rate-limit.sh reset [limit_type]
#
# limit_type: daily|hourly|issue
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${CACHE_DIR:-/tmp/rate-limit-cache}"
CACHE_KEY_PREFIX="rate-limit"

# Default limits
DAILY_LIMIT="${DAILY_LIMIT:-10}"
HOURLY_LIMIT="${HOURLY_LIMIT:-3}"
ISSUE_LIMIT="${ISSUE_LIMIT:-1}"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Get current timestamp
get_timestamp() {
    date -u +%s
}

# Get current date (YYYY-MM-DD) in UTC
get_current_date() {
    date -u +%Y-%m-%d
}

# Get current hour (YYYY-MM-DD-HH) in UTC
get_current_hour() {
    date -u +%Y-%m-%d-%H
}

# Get cache file path
get_cache_file() {
    local limit_type="$1"
    case "$limit_type" in
        daily)
            echo "$CACHE_DIR/${CACHE_KEY_PREFIX}-daily-$(get_current_date).json"
            ;;
        hourly)
            echo "$CACHE_DIR/${CACHE_KEY_PREFIX}-hourly-$(get_current_hour).json"
            ;;
        issue)
            local issue_number="${ISSUE_NUMBER:-}"
            if [ -z "$issue_number" ]; then
                echo "Error: ISSUE_NUMBER environment variable is required for issue limit" >&2
                exit 1
            fi
            echo "$CACHE_DIR/${CACHE_KEY_PREFIX}-issue-${issue_number}.json"
            ;;
        *)
            echo "Error: Invalid limit type: $limit_type" >&2
            echo "Valid types: daily, hourly, issue" >&2
            exit 1
            ;;
    esac
}

# Initialize cache file if it doesn't exist
init_cache_file() {
    local cache_file="$1"
    if [ ! -f "$cache_file" ]; then
        cat > "$cache_file" <<EOF
{
  "count": 0,
  "last_reset": $(get_timestamp),
  "limit": 0
}
EOF
    fi
}

# Read count from cache file
read_count() {
    local cache_file="$1"
    init_cache_file "$cache_file"
    
    if command -v jq >/dev/null 2>&1; then
        jq -r '.count' "$cache_file" 2>/dev/null || echo "0"
    else
        # Fallback: simple grep (less reliable)
        grep -o '"count"[[:space:]]*:[[:space:]]*[0-9]*' "$cache_file" | grep -o '[0-9]*' || echo "0"
    fi
}

# Write count to cache file
write_count() {
    local cache_file="$1"
    local count="$2"
    local limit="$3"
    
    init_cache_file "$cache_file"
    
    if command -v jq >/dev/null 2>&1; then
        jq --argjson count "$count" --argjson limit "$limit" \
           '.count = $count | .last_reset = '$(get_timestamp)' | .limit = $limit' \
           "$cache_file" > "${cache_file}.tmp" && mv "${cache_file}.tmp" "$cache_file"
    else
        # Fallback: simple sed (less reliable)
        sed -i "s/\"count\"[[:space:]]*:[[:space:]]*[0-9]*/\"count\": $count/" "$cache_file"
        sed -i "s/\"limit\"[[:space:]]*:[[:space:]]*[0-9]*/\"limit\": $limit/" "$cache_file"
    fi
}

# Check if limit is reached
check_limit() {
    local limit_type="$1"
    local limit_count="${2:-}"
    
    # Set default limit based on type
    case "$limit_type" in
        daily)
            limit_count="${limit_count:-$DAILY_LIMIT}"
            ;;
        hourly)
            limit_count="${limit_count:-$HOURLY_LIMIT}"
            ;;
        issue)
            limit_count="${limit_count:-$ISSUE_LIMIT}"
            ;;
    esac
    
    local cache_file
    cache_file="$(get_cache_file "$limit_type")"
    
    local current_count
    current_count="$(read_count "$cache_file")"
    
    # Check if limit is reached
    if [ "$current_count" -ge "$limit_count" ]; then
        echo "Rate limit reached: $limit_type ($current_count/$limit_count)" >&2
        return 1
    fi
    
    echo "Rate limit OK: $limit_type ($current_count/$limit_count)"
    return 0
}

# Increment count
increment_count() {
    local limit_type="$1"
    
    local limit_count
    case "$limit_type" in
        daily)
            limit_count="$DAILY_LIMIT"
            ;;
        hourly)
            limit_count="$HOURLY_LIMIT"
            ;;
        issue)
            limit_count="$ISSUE_LIMIT"
            ;;
    esac
    
    local cache_file
    cache_file="$(get_cache_file "$limit_type")"
    
    local current_count
    current_count="$(read_count "$cache_file")"
    
    local new_count=$((current_count + 1))
    write_count "$cache_file" "$new_count" "$limit_count"
    
    echo "Incremented $limit_type: $new_count/$limit_count"
}

# Reset count (for testing or manual reset)
reset_count() {
    local limit_type="$1"
    
    local limit_count
    case "$limit_type" in
        daily)
            limit_count="$DAILY_LIMIT"
            ;;
        hourly)
            limit_count="$HOURLY_LIMIT"
            ;;
        issue)
            limit_count="$ISSUE_LIMIT"
            ;;
    esac
    
    local cache_file
    cache_file="$(get_cache_file "$limit_type")"
    
    write_count "$cache_file" 0 "$limit_count"
    
    echo "Reset $limit_type: 0/$limit_count"
}

# Main command handling
main() {
    local command="${1:-}"
    
    case "$command" in
        check)
            local limit_type="${2:-}"
            local limit_count="${3:-}"
            
            if [ -z "$limit_type" ]; then
                echo "Error: limit_type is required" >&2
                echo "Usage: $0 check [daily|hourly|issue] [limit_count]" >&2
                exit 1
            fi
            
            check_limit "$limit_type" "$limit_count"
            ;;
        increment)
            local limit_type="${2:-}"
            
            if [ -z "$limit_type" ]; then
                echo "Error: limit_type is required" >&2
                echo "Usage: $0 increment [daily|hourly|issue]" >&2
                exit 1
            fi
            
            increment_count "$limit_type"
            ;;
        reset)
            local limit_type="${2:-}"
            
            if [ -z "$limit_type" ]; then
                echo "Error: limit_type is required" >&2
                echo "Usage: $0 reset [daily|hourly|issue]" >&2
                exit 1
            fi
            
            reset_count "$limit_type"
            ;;
        *)
            echo "Usage: $0 {check|increment|reset} [limit_type] [limit_count]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  check      Check if rate limit is reached" >&2
            echo "  increment  Increment the count for a limit type" >&2
            echo "  reset      Reset the count for a limit type" >&2
            echo "" >&2
            echo "Limit types: daily, hourly, issue" >&2
            echo "" >&2
            echo "Environment variables:" >&2
            echo "  DAILY_LIMIT    Daily limit (default: 10)" >&2
            echo "  HOURLY_LIMIT   Hourly limit (default: 3)" >&2
            echo "  ISSUE_LIMIT    Issue limit (default: 1)" >&2
            echo "  ISSUE_NUMBER   Issue number (required for issue limit)" >&2
            echo "  CACHE_DIR      Cache directory (default: /tmp/rate-limit-cache)" >&2
            exit 1
            ;;
    esac
}

main "$@"
