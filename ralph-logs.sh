#!/usr/bin/env bash
# Ralph Logs - View iteration logs
# Displays logs from Ralph Loop iterations

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default lines to show
LINES=50

# Parse arguments
FOLLOW=false
ITERATION=""

show_usage() {
    echo "Usage: ralph-logs [options] [iteration]"
    echo ""
    echo "View Ralph Loop iteration logs"
    echo ""
    echo "Options:"
    echo "  -f          Follow log output (like tail -f)"
    echo "  -n LINES    Show last N lines (default: 50)"
    echo "  -l          List all available log files"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "Arguments:"
    echo "  iteration   Specific iteration number to view"
    echo ""
    echo "Examples:"
    echo "  ralph-logs          # View latest log"
    echo "  ralph-logs 5        # View iteration 5 log"
    echo "  ralph-logs -f       # Follow latest log"
    echo "  ralph-logs -l       # List all logs"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f)
            FOLLOW=true
            shift
            ;;
        -n)
            LINES="$2"
            shift 2
            ;;
        -l)
            # List all log files
            echo -e "${BLUE}Ralph Loop - Available Logs${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

            if ls .ralph-iteration-*.log 1>/dev/null 2>&1; then
                for log in .ralph-iteration-*.log; do
                    # Extract iteration number
                    iter=$(echo "$log" | sed 's/.ralph-iteration-\([0-9]*\).log/\1/')
                    size=$(ls -lh "$log" | awk '{print $5}')
                    modified=$(ls -lh "$log" | awk '{print $6, $7, $8}')
                    echo -e "  Iteration ${YELLOW}$iter${NC}: $size ($modified)"
                done
            else
                echo "  No log files found"
            fi
            exit 0
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                ITERATION="$1"
            else
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

# Find the log file to display
if [[ -n "$ITERATION" ]]; then
    LOG_FILE=".ralph-iteration-${ITERATION}.log"
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${RED}Error: Log file for iteration $ITERATION not found${NC}"
        echo ""
        echo "Available iterations:"
        ls .ralph-iteration-*.log 2>/dev/null | sed 's/.ralph-iteration-\([0-9]*\).log/  \1/' || echo "  None"
        exit 1
    fi
else
    # Find latest log file
    LOG_FILE=$(ls -t .ralph-iteration-*.log 2>/dev/null | head -1)
    if [[ -z "$LOG_FILE" ]]; then
        echo -e "${RED}Error: No log files found${NC}"
        echo "Run ralph to create iteration logs"
        exit 1
    fi
    ITERATION=$(echo "$LOG_FILE" | sed 's/.ralph-iteration-\([0-9]*\).log/\1/')
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop - Iteration $ITERATION Log${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ "$FOLLOW" == true ]]; then
    echo -e "${YELLOW}Following $LOG_FILE (Ctrl+C to stop)...${NC}"
    echo ""
    tail -f "$LOG_FILE"
else
    tail -n "$LINES" "$LOG_FILE"
fi
