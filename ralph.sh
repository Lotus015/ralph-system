#!/usr/bin/env bash
# Ralph Loop System - Main execution loop
# Runs Claude Code iterations to complete user stories

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============================================================
# Iteration Output Formatting Functions (S4)
# ============================================================

# Show clear separator line before iteration starts
show_separator() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Show iteration header with ⚡ prefix
# Usage: show_iteration_header iteration_number story_id story_title
show_iteration_header() {
    local iteration="$1"
    local story_id="$2"
    local story_title="$3"
    echo -e "${YELLOW}⚡ Iteration ${iteration}: Working on ${story_id} - ${story_title}${NC}"
}

# Log progress message with > prefix (during work)
log_progress() {
    local message="$1"
    echo -e "${BLUE}>${NC} ${message}"
}

# Log success message with ✓ prefix (on completion)
log_success() {
    local message="$1"
    echo -e "${GREEN}✓${NC} ${message}"
}

# Log error message with ✗ prefix (on errors)
log_error() {
    local message="$1"
    echo -e "${RED}✗${NC} ${message}"
}

# Show usage
show_usage() {
    echo "Usage: ralph [max_iterations] [options]"
    echo ""
    echo "Run the Ralph Loop System to complete user stories from prd.json"
    echo ""
    echo "Arguments:"
    echo "  max_iterations  Maximum number of iterations (default: 50)"
    echo ""
    echo "Options:"
    echo "  --auto-push  Automatically push commits after each successful iteration"
    echo ""
    echo "Examples:"
    echo "  ralph        # Run with default 50 iterations"
    echo "  ralph 10     # Run with max 10 iterations"
    echo "  ralph 20 --auto-push  # Run with auto-push enabled"
    exit 0
}

# Handle help flag
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    show_usage
fi

# Configuration defaults
AUTO_PUSH=false
MAX_ITERATIONS=50
SLEEP_BETWEEN_ITERATIONS=2

# Parse arguments
for arg in "$@"; do
    case $arg in
        --auto-push)
            AUTO_PUSH=true
            ;;
        [0-9]*)
            MAX_ITERATIONS=$arg
            ;;
    esac
done

# Validate max_iterations is a number
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: max_iterations must be a positive number${NC}"
    show_usage
fi

# Check dependencies
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed${NC}"
        echo "Install with: brew install jq (macOS) or apt install jq (Linux)"
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        echo -e "${RED}Error: Claude Code CLI is not installed${NC}"
        exit 1
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${RED}Error: git is not installed${NC}"
        exit 1
    fi
}

# Check if git remote origin exists
check_git_remote() {
    if git remote get-url origin &> /dev/null; then
        return 0
    else
        echo -e "${YELLOW}Warning: No git remote 'origin' configured. Skipping push.${NC}"
        return 1
    fi
}

# Check required files exist
check_files() {
    if [[ ! -f "prd.json" ]]; then
        echo -e "${RED}Error: prd.json not found${NC}"
        echo "Run ralph-init to set up a new project or create prd.json manually"
        exit 1
    fi

    if ! jq empty prd.json 2>/dev/null; then
        echo -e "${RED}Error: prd.json is not valid JSON${NC}"
        exit 1
    fi

    if [[ ! -f "prompt.md" ]]; then
        echo -e "${RED}Error: prompt.md not found${NC}"
        exit 1
    fi

    # Create progress.txt if it doesn't exist
    if [[ ! -f "progress.txt" ]]; then
        touch progress.txt
    fi

    # Create .ralph-state if it doesn't exist
    if [[ ! -f ".ralph-state" ]]; then
        echo "0" > .ralph-state
    fi
}

# Get timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get current iteration number
get_iteration() {
    cat .ralph-state
}

# Increment iteration counter
increment_iteration() {
    local current
    current=$(get_iteration)
    echo $((current + 1)) > .ralph-state
}

# Find next story to work on (first with passes: false, lowest priority)
get_next_story() {
    jq -r '.userStories | map(select(.passes == false)) | sort_by(.priority) | .[0] // empty' prd.json
}

# Get story field by id
get_story_field() {
    local story_id="$1"
    local field="$2"
    jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .'"$field" prd.json
}

# Get acceptance criteria as bullet list
get_acceptance_criteria() {
    local story_id="$1"
    jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .acceptance | map("- " + .) | join("\n")' prd.json
}

# Get test commands as single string
get_test_commands() {
    local story_id="$1"
    jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .tests | join(" && ")' prd.json
}

# Generate prompt from template
generate_prompt() {
    local story_id="$1"
    local story_title="$2"
    local story_description="$3"
    local acceptance_criteria="$4"
    local test_commands="$5"
    local iteration="$6"

    local prompt
    prompt=$(cat prompt.md)

    # Replace placeholders
    prompt="${prompt//STORY_ID/$story_id}"
    prompt="${prompt//STORY_TITLE/$story_title}"
    prompt="${prompt//STORY_DESCRIPTION/$story_description}"
    prompt="${prompt//ACCEPTANCE_CRITERIA/$acceptance_criteria}"
    prompt="${prompt//TEST_COMMANDS/$test_commands}"
    prompt="${prompt//Iteration N/Iteration $iteration}"

    echo "$prompt"
}

# Mark story as complete in prd.json
mark_story_complete() {
    local story_id="$1"
    local timestamp
    timestamp=$(get_timestamp)

    jq --arg id "$story_id" --arg ts "$timestamp" \
        '(.userStories[] | select(.id == $id)) |= . + {passes: true, completedAt: $ts}' \
        prd.json > prd.json.tmp && mv prd.json.tmp prd.json
}

# Count stories
count_stories() {
    jq '.userStories | length' prd.json
}

# Count completed stories
count_completed() {
    jq '[.userStories[] | select(.passes == true)] | length' prd.json
}

# Display progress
show_progress() {
    local total completed
    total=$(count_stories)
    completed=$(count_completed)

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Ralph Loop System - Progress${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Show each story status
    jq -r '.userStories[] | "\(.id)|\(.title)|\(.passes)"' prd.json | while IFS='|' read -r id title passes; do
        if [[ "$passes" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $id: $title"
        else
            echo -e "  ${YELLOW}○${NC} $id: $title"
        fi
    done

    echo ""
    echo -e "Progress: ${GREEN}$completed${NC}/${total} stories complete"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Calculate elapsed time since START_TIME
get_elapsed_time() {
    local now elapsed minutes seconds
    now=$(date +%s)
    elapsed=$((now - START_TIME))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    printf "%02d:%02d" "$minutes" "$seconds"
}

# Show header box with project info
show_header() {
    local iteration="$1"
    local project_name elapsed_time
    project_name=$(jq -r '.project' prd.json)
    elapsed_time=$(get_elapsed_time)

    echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}${project_name}${NC}"
    echo -e "${BLUE}║${NC}  Iteration: ${YELLOW}${iteration}${NC} / ${MAX_ITERATIONS}"
    echo -e "${BLUE}║${NC}  Elapsed: ${YELLOW}${elapsed_time}${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
}

# Show progress bar
# Shows percentage: ████████░░░░ 40%
# Width adjusts to terminal width (max 50 chars)
show_progress_bar() {
    local total completed percentage
    total=$(count_stories)
    completed=$(count_completed)

    # Calculate percentage
    if [[ $total -eq 0 ]]; then
        percentage=0
    else
        percentage=$((completed * 100 / total))
    fi

    # Get terminal width and calculate bar width (max 50)
    local term_width bar_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    # Reserve space for percentage display " 100%" = 5 chars, plus some padding
    bar_width=$((term_width - 10))
    if [[ $bar_width -gt 50 ]]; then
        bar_width=50
    fi
    if [[ $bar_width -lt 10 ]]; then
        bar_width=10
    fi

    # Calculate filled and empty portions
    local filled_width empty_width
    filled_width=$((bar_width * percentage / 100))
    empty_width=$((bar_width - filled_width))

    # Build the progress bar
    local filled_bar="" empty_bar=""
    for ((i=0; i<filled_width; i++)); do
        filled_bar+="█"
    done
    for ((i=0; i<empty_width; i++)); do
        empty_bar+="░"
    done

    # Display the progress bar
    printf "${GREEN}%s${GRAY}%s${NC} %3d%%\n" "$filled_bar" "$empty_bar" "$percentage"
}

# Show final summary when all stories complete
# Shows: 🎉 All Stories Complete!, total stories, total time, total commits, average time per story
# Box around summary, links to GitHub repo if pushed
show_summary() {
    local total_stories total_time_secs total_commits avg_time_secs
    local minutes seconds avg_minutes avg_seconds
    local github_url=""

    # Get total stories
    total_stories=$(count_stories)

    # Calculate total time
    total_time_secs=$(($(date +%s) - START_TIME))
    minutes=$((total_time_secs / 60))
    seconds=$((total_time_secs % 60))

    # Calculate average time per story
    if [[ $total_stories -gt 0 ]]; then
        avg_time_secs=$((total_time_secs / total_stories))
        avg_minutes=$((avg_time_secs / 60))
        avg_seconds=$((avg_time_secs % 60))
    else
        avg_minutes=0
        avg_seconds=0
    fi

    # Count total commits during this session (commits since START_TIME)
    total_commits=$(git rev-list --count --since="@$START_TIME" HEAD 2>/dev/null || echo "0")

    # Get GitHub repo URL if available
    if git remote get-url origin &> /dev/null; then
        github_url=$(git remote get-url origin)
        # Convert SSH URL to HTTPS if needed
        if [[ "$github_url" == git@github.com:* ]]; then
            github_url="https://github.com/${github_url#git@github.com:}"
            github_url="${github_url%.git}"
        elif [[ "$github_url" == *.git ]]; then
            github_url="${github_url%.git}"
        fi
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                                                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}       ${YELLOW}🎉 All Stories Complete!${NC}                   ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}║${NC}  Total Stories:     %-28s${GREEN}║${NC}\n" "$total_stories"
    printf "${GREEN}║${NC}  Total Time:        %-28s${GREEN}║${NC}\n" "$(printf '%02d:%02d' $minutes $seconds)"
    printf "${GREEN}║${NC}  Total Commits:     %-28s${GREEN}║${NC}\n" "$total_commits"
    printf "${GREEN}║${NC}  Avg Time/Story:    %-28s${GREEN}║${NC}\n" "$(printf '%02d:%02d' $avg_minutes $avg_seconds)"
    if [[ -n "$github_url" ]]; then
        echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
        printf "${GREEN}║${NC}  GitHub: %-40s${GREEN}║${NC}\n" "$github_url"
    fi
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show story list with status icons
# Icons: ✅ complete, 🔄 in-progress, ⏸️ pending
# Color coded: green=done, yellow=current, gray=pending
show_story_list() {
    local current_story_id="${1:-}"

    echo -e "${BLUE}Stories:${NC}"

    # Read stories and display with appropriate icons and colors
    jq -r '.userStories[] | "\(.id)|\(.title)|\(.passes)|\(.completedAt // "")"' prd.json | while IFS='|' read -r id title passes completed_at; do
        if [[ "$passes" == "true" ]]; then
            # Completed story - green with checkmark
            local time_display=""
            if [[ -n "$completed_at" ]]; then
                # Extract time portion (HH:MM:SS) from ISO timestamp
                time_display=" (${completed_at:11:8})"
            fi
            echo -e "  ${GREEN}✅ ${id}: ${title}${time_display}${NC}"
        elif [[ "$id" == "$current_story_id" ]]; then
            # Current story being worked on - yellow with spinner
            echo -e "  ${YELLOW}🔄 ${id}: ${title}${NC}"
        else
            # Pending story - gray with pause icon
            echo -e "  ${GRAY}⏸️  ${id}: ${title}${NC}"
        fi
    done
}

# Main loop
main() {
    check_dependencies
    check_files

    # Capture start time for elapsed time calculation
    START_TIME=$(date +%s)

    echo -e "${BLUE}Ralph Loop System v1.0${NC}"
    echo -e "Max iterations: ${MAX_ITERATIONS}"
    echo ""

    show_progress
    echo ""

    local iteration
    iteration=$(get_iteration)

    while [[ $iteration -lt $MAX_ITERATIONS ]]; do
        # Check if all stories are complete
        local next_story
        next_story=$(get_next_story)

        if [[ -z "$next_story" ]]; then
            show_summary
            exit 0
        fi

        # Extract story details
        local story_id story_title story_description acceptance_criteria test_commands
        story_id=$(echo "$next_story" | jq -r '.id')
        story_title=$(echo "$next_story" | jq -r '.title')
        story_description=$(echo "$next_story" | jq -r '.description')
        acceptance_criteria=$(echo "$next_story" | jq -r '.acceptance | map("- " + .) | join("\n")')
        test_commands=$(echo "$next_story" | jq -r '.tests | join(" && ")')

        increment_iteration
        iteration=$(get_iteration)

        # Show header with project info at start of each iteration
        show_header "$iteration"
        echo ""

        # Show story list with current story highlighted
        show_story_list "$story_id"
        show_progress_bar
        echo ""

        # Clear separator before iteration work begins
        show_separator

        # Show iteration header with ⚡ prefix
        show_iteration_header "$iteration" "$story_id" "$story_title"

        # Generate prompt
        local prompt
        prompt=$(generate_prompt "$story_id" "$story_title" "$story_description" "$acceptance_criteria" "$test_commands" "$iteration")

        # Log file for this iteration
        local log_file=".ralph-iteration-${iteration}.log"

        # Run Claude Code
        log_progress "Running Claude Code..."
        local output
        local exit_code=0

        if output=$(claude --dangerously-skip-permissions --output-format json -p "$prompt" 2>&1); then
            echo "$output" > "$log_file"
        else
            exit_code=$?
            echo "$output" > "$log_file"
            log_error "Claude Code exited with error code $exit_code"
        fi

        # Parse output for promise tags
        # Claude --output-format json returns: {"result": "...", ...}
        # We need to extract .result field if output is valid JSON
        local result_text

        # Check if output is valid JSON and has a result field
        if echo "$output" | jq -e '.result' > /dev/null 2>&1; then
            # Output is JSON with .result field - extract it
            result_text=$(echo "$output" | jq -r '.result')
            log_progress "Parsed JSON output, extracted .result field"
        elif echo "$output" | jq -e '.' > /dev/null 2>&1; then
            # Output is valid JSON but no .result field - try .message or use whole output
            result_text=$(echo "$output" | jq -r '.message // .')
            log_progress "Parsed JSON output (no .result field)"
        else
            # Output is plain text - use directly
            result_text="$output"
            log_progress "Using plain text output"
        fi

        if echo "$result_text" | grep -q "<promise>COMPLETE</promise>"; then
            log_success "Story $story_id completed!"
            mark_story_complete "$story_id"

            # Note: Claude Code already commits changes per prompt instructions
            # Ralph only needs to commit prd.json update and handle auto-push
            if git rev-parse --git-dir > /dev/null 2>&1; then
                # Only commit prd.json if it was modified (story marked complete)
                if ! git diff --quiet prd.json 2>/dev/null; then
                    git add prd.json
                    git commit -m "chore: mark $story_id as complete" 2>/dev/null || true
                fi

                # Auto-push if enabled
                if [[ "$AUTO_PUSH" == "true" ]]; then
                    if check_git_remote; then
                        local current_branch
                        current_branch=$(git branch --show-current)
                        local push_exit_code=0
                        if git push origin "$current_branch" 2>&1; then
                            log_success "Pushed to origin"
                            echo "Push status: SUCCESS - Pushed to origin/$current_branch" >> "$log_file"
                        else
                            push_exit_code=$?
                            log_error "Push failed (exit code $push_exit_code), continuing..."
                            echo "Push status: FAILED - Exit code $push_exit_code" >> "$log_file"
                        fi
                    else
                        echo "Push status: SKIPPED - No remote configured" >> "$log_file"
                    fi
                fi
            fi

            # Show updated story list and progress bar after completion
            show_story_list
            show_progress_bar
        elif echo "$result_text" | grep -q "<promise>CONTINUE</promise>"; then
            log_progress "Story $story_id needs more work, continuing..."
        else
            log_progress "No completion signal found, continuing..."
        fi

        echo ""
        log_progress "Log saved to: $log_file"
        echo ""

        # Sleep between iterations
        if [[ $iteration -lt $MAX_ITERATIONS ]]; then
            echo -e "Sleeping ${SLEEP_BETWEEN_ITERATIONS}s before next iteration..."
            sleep $SLEEP_BETWEEN_ITERATIONS
        fi
    done

    log_error "Max iterations ($MAX_ITERATIONS) reached"
    show_progress
    exit 1
}

main "$@"
