#!/usr/bin/env bash
# Ralph Loop System - Main execution loop
# Runs Claude Code iterations to complete user stories

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============================================================
# Spinner Functions (S1)
# ============================================================

# Global variable to track spinner PID
SPINNER_PID=""

# Show animated spinner while Claude works
# Usage: show_spinner "S1" &
# Shows: '⠋ Working on S1... (0m 15s)'
# Must be killed with stop_spinner when done
show_spinner() {
    local story_id="$1"
    local spinner_frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local frame_count=${#spinner_frames[@]}
    local start_time
    start_time=$(date +%s)
    local i=0

    # Hide cursor
    tput civis 2>/dev/null || true

    while true; do
        local now elapsed minutes seconds
        now=$(date +%s)
        elapsed=$((now - start_time))
        minutes=$((elapsed / 60))
        seconds=$((elapsed % 60))

        # Print spinner with elapsed time (overwrite previous line)
        printf "\r${YELLOW}%s${NC} Working on %s... ${GRAY}(%dm %02ds)${NC}  " \
            "${spinner_frames[$i]}" "$story_id" "$minutes" "$seconds"

        # Advance to next frame
        i=$(( (i + 1) % frame_count ))

        sleep 0.1
    done
}

# Stop the spinner and clean up
# Usage: stop_spinner
stop_spinner() {
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
    fi
    SPINNER_PID=""

    # Show cursor again
    tput cnorm 2>/dev/null || true

    # Clear the spinner line
    printf "\r\033[K"
}

# Cleanup function for trap
cleanup_spinner() {
    stop_spinner
}

# ============================================================
# Story Summary Functions (S2)
# ============================================================

# Show mini summary after each story completes
# Usage: show_story_summary story_id duration_secs test_cmd test_result push_status commit_before
# Displays compact summary of what was accomplished
show_story_summary() {
    local story_id="$1"
    local duration_secs="$2"
    local test_cmd="$3"
    local test_passed="$4"
    local push_status="$5"
    local commit_before="$6"

    # Get files created and modified using git diff --name-status
    local created_files=()
    local modified_files=()
    local untracked_files=()

    # Compare current state to commit before story started
    if [[ -n "$commit_before" ]]; then
        # We have a valid commit to compare against
        while IFS=$'\t' read -r status file; do
            [[ -z "$file" ]] && continue
            case "$status" in
                A) created_files+=("$file") ;;
                M) modified_files+=("$file") ;;
            esac
        done < <(git diff --name-status "$commit_before" HEAD 2>/dev/null)
    else
        # First commit scenario - use git diff --name-status against empty tree
        # The empty tree hash is a well-known constant in git
        local empty_tree="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
        while IFS=$'\t' read -r status file; do
            [[ -z "$file" ]] && continue
            case "$status" in
                A) created_files+=("$file") ;;
                M) modified_files+=("$file") ;;
            esac
        done < <(git diff --name-status "$empty_tree" HEAD 2>/dev/null)
    fi

    # Also count untracked files (not yet committed)
    while IFS= read -r file; do
        [[ -n "$file" ]] && untracked_files+=("$file")
    done < <(git ls-files --others --exclude-standard 2>/dev/null)

    local created_count=${#created_files[@]}
    local modified_count=${#modified_files[@]}
    local untracked_count=${#untracked_files[@]}

    # Get commit message from most recent commit
    local commit_msg
    commit_msg=$(git log -1 --format="%s" 2>/dev/null || echo "No commit")

    # Format duration
    local duration_formatted
    duration_formatted=$(format_duration "$duration_secs")

    # Build compact summary (max 10 lines)
    echo ""
    echo -e "${CYAN}┌─ Summary: ${story_id} ────────────────────────────────────${NC}"

    # Files created (1-2 lines)
    if [[ $created_count -gt 0 ]]; then
        local created_names
        created_names=$(IFS=', '; echo "${created_files[*]}")
        if [[ ${#created_names} -gt 45 ]]; then
            created_names="${created_names:0:42}..."
        fi
        echo -e "${CYAN}│${NC} ${GREEN}+${NC} Created: ${created_count} file(s): ${created_names}"
    fi

    # Files modified (1-2 lines)
    if [[ $modified_count -gt 0 ]]; then
        local modified_names
        modified_names=$(IFS=', '; echo "${modified_files[*]}")
        if [[ ${#modified_names} -gt 45 ]]; then
            modified_names="${modified_names:0:42}..."
        fi
        echo -e "${CYAN}│${NC} ${YELLOW}~${NC} Modified: ${modified_count} file(s): ${modified_names}"
    fi

    # Untracked files (1-2 lines)
    if [[ $untracked_count -gt 0 ]]; then
        local untracked_names
        untracked_names=$(IFS=', '; echo "${untracked_files[*]}")
        if [[ ${#untracked_names} -gt 45 ]]; then
            untracked_names="${untracked_names:0:42}..."
        fi
        echo -e "${CYAN}│${NC} ${GRAY}?${NC} Untracked: ${untracked_count} file(s): ${untracked_names}"
    fi

    # Test results (1 line)
    local test_icon test_color
    if [[ "$test_passed" == "true" ]]; then
        test_icon="✓"
        test_color="${GREEN}"
    else
        test_icon="✗"
        test_color="${RED}"
    fi
    echo -e "${CYAN}│${NC} ${test_color}${test_icon}${NC} Tests: ${test_cmd}"

    # Commit message (1 line, truncate if needed)
    local display_msg="$commit_msg"
    if [[ ${#display_msg} -gt 50 ]]; then
        display_msg="${display_msg:0:47}..."
    fi
    echo -e "${CYAN}│${NC} 📝 Commit: ${display_msg}"

    # Push status (1 line)
    local push_icon
    case "$push_status" in
        "SUCCESS") push_icon="${GREEN}✓ Pushed${NC}" ;;
        "FAILED")  push_icon="${RED}✗ Failed${NC}" ;;
        *)         push_icon="${GRAY}- Skipped${NC}" ;;
    esac
    echo -e "${CYAN}│${NC} 🚀 Push: ${push_icon}"

    # Duration (1 line)
    echo -e "${CYAN}│${NC} ⏱️  Duration: ${duration_formatted}"

    echo -e "${CYAN}└──────────────────────────────────────────────────────${NC}"
}

# ============================================================
# Iteration Output Formatting Functions (S4)
# ============================================================

# Show clear separator line before iteration starts
show_separator() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
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
    echo -e "${CYAN}>${NC} ${message}"
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

# Mark story as complete in prd.json with timing information
mark_story_complete() {
    local story_id="$1"
    local story_start_time="$2"
    local timestamp duration_secs
    timestamp=$(get_timestamp)

    # Calculate duration in seconds
    duration_secs=$(($(date +%s) - story_start_time))

    jq --arg id "$story_id" --arg ts "$timestamp" --argjson dur "$duration_secs" \
        '(.userStories[] | select(.id == $id)) |= . + {passes: true, completedAt: $ts, durationSecs: $dur}' \
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

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Ralph Loop System - Progress${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
# Usage: show_header iteration_number
# Shows: 🎯 Project name, 🔄 Iteration X/Y, ⏱️ Total elapsed
# Uses Unicode box drawing: ┌─┐ │ └─┘
# Width adjusts to content (min 50 chars)
show_header() {
    local iteration="$1"
    local project_name elapsed_time total_stories
    project_name=$(jq -r '.project' prd.json)
    elapsed_time=$(get_elapsed_time)
    total_stories=$(count_stories)

    # Build content lines
    local line1="🎯 ${project_name}"
    local line2="🔄 Iteration ${iteration}/${total_stories}"
    local line3="⏱️  Total elapsed: ${elapsed_time}"

    # Calculate max content width (min 50 chars)
    local max_len=50
    local len1=${#line1}
    local len2=${#line2}
    local len3=${#line3}
    [[ $len1 -gt $max_len ]] && max_len=$len1
    [[ $len2 -gt $max_len ]] && max_len=$len2
    [[ $len3 -gt $max_len ]] && max_len=$len3

    # Add padding for box (2 spaces each side)
    local box_width=$((max_len + 4))

    # Build horizontal border
    local border=""
    for ((i=0; i<box_width; i++)); do
        border+="─"
    done

    # Pad content lines to box width
    local pad1 pad2 pad3
    pad1=$((box_width - len1 - 2))
    pad2=$((box_width - len2 - 2))
    pad3=$((box_width - len3 - 2))

    # Print the box
    echo -e "${CYAN}┌${border}┐${NC}"
    printf "${CYAN}│${NC} ${GREEN}%s${NC}%*s ${CYAN}│${NC}\n" "$line1" "$pad1" ""
    printf "${CYAN}│${NC} ${YELLOW}%s${NC}%*s ${CYAN}│${NC}\n" "$line2" "$pad2" ""
    printf "${CYAN}│${NC} %s%*s ${CYAN}│${NC}\n" "$line3" "$pad3" ""
    echo -e "${CYAN}└${border}┘${NC}"
}

# Show progress bar
# Format: Progress: ████████░░░░░░░░ 40% (2/5 stories)
# Width: 20 characters for bar
# Updates after each story completion
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

    # Fixed bar width of 20 characters as per acceptance criteria
    local bar_width=20

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

    # Display the progress bar with format: Progress: ████████░░░░░░░░ 40% (2/5 stories)
    printf "Progress: ${GREEN}%s${GRAY}%s${NC} %3d%% (%d/%d stories)\n" "$filled_bar" "$empty_bar" "$percentage" "$completed" "$total"
}

# Show final completion summary when all stories complete
# Shows: 🎉 All Stories Complete!, total stories, total time, total commits, average time per story
# Stats: total commits, files created/modified
# Box around summary, links to GitHub repo if pushed
# Includes timing statistics from recorded story durations
show_completion_summary() {
    local total_stories total_time_secs total_commits avg_time_secs
    local minutes seconds avg_minutes avg_seconds
    local github_url=""
    local fastest_secs slowest_secs total_recorded_secs stories_with_timing

    # Get total stories
    total_stories=$(count_stories)

    # Calculate total time
    total_time_secs=$(($(date +%s) - START_TIME))
    minutes=$((total_time_secs / 60))
    seconds=$((total_time_secs % 60))

    # Get timing statistics from recorded durations
    stories_with_timing=$(jq '[.userStories[] | select(.durationSecs != null and .durationSecs > 0)] | length' prd.json)
    if [[ "$stories_with_timing" -gt 0 ]]; then
        total_recorded_secs=$(jq '[.userStories[] | select(.durationSecs != null) | .durationSecs] | add // 0' prd.json)
        fastest_secs=$(jq '[.userStories[] | select(.durationSecs != null and .durationSecs > 0) | .durationSecs] | min // 0' prd.json)
        slowest_secs=$(jq '[.userStories[] | select(.durationSecs != null and .durationSecs > 0) | .durationSecs] | max // 0' prd.json)
        avg_time_secs=$((total_recorded_secs / stories_with_timing))
    else
        # Fallback to calculating from total time
        total_recorded_secs=$total_time_secs
        fastest_secs=0
        slowest_secs=0
        if [[ $total_stories -gt 0 ]]; then
            avg_time_secs=$((total_time_secs / total_stories))
        else
            avg_time_secs=0
        fi
    fi

    avg_minutes=$((avg_time_secs / 60))
    avg_seconds=$((avg_time_secs % 60))

    # Count total commits during this session (commits since START_TIME)
    total_commits=$(git rev-list --count --since="@$START_TIME" HEAD 2>/dev/null || echo "0")

    # Count files created and modified during this session
    local files_created=0 files_modified=0
    local first_commit_in_session
    first_commit_in_session=$(git rev-list --since="@$START_TIME" HEAD 2>/dev/null | tail -1)
    if [[ -n "$first_commit_in_session" ]]; then
        # Get the parent of the first commit to compare from before session started
        local parent_commit
        parent_commit=$(git rev-parse "${first_commit_in_session}^" 2>/dev/null || echo "")
        if [[ -n "$parent_commit" ]]; then
            # Normal case: compare parent commit to HEAD
            files_created=$(git diff --name-status "$parent_commit" HEAD 2>/dev/null | grep -c "^A" || echo "0")
            files_modified=$(git diff --name-status "$parent_commit" HEAD 2>/dev/null | grep -c "^M" || echo "0")
        else
            # First commit scenario: compare against empty tree
            local empty_tree="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
            files_created=$(git diff --name-status "$empty_tree" HEAD 2>/dev/null | grep -c "^A" || echo "0")
            files_modified=$(git diff --name-status "$empty_tree" HEAD 2>/dev/null | grep -c "^M" || echo "0")
        fi
    fi

    # Also count untracked files
    local untracked_count=0
    untracked_count=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

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
    printf "${GREEN}║${NC}  Total Time:        %-28s${GREEN}║${NC}\n" "$(format_duration $total_time_secs)"
    printf "${GREEN}║${NC}  Total Commits:     %-28s${GREEN}║${NC}\n" "$total_commits"
    printf "${GREEN}║${NC}  Files Created:     %-28s${GREEN}║${NC}\n" "$files_created"
    printf "${GREEN}║${NC}  Files Modified:    %-28s${GREEN}║${NC}\n" "$files_modified"
    if [[ "$untracked_count" -gt 0 ]]; then
        printf "${GREEN}║${NC}  Untracked Files:   %-28s${GREEN}║${NC}\n" "$untracked_count"
    fi
    echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}║${NC}  Avg Time/Story:    %-28s${GREEN}║${NC}\n" "$(format_duration $avg_time_secs)"
    if [[ "$fastest_secs" -gt 0 ]]; then
        printf "${GREEN}║${NC}  Fastest Story:     %-28s${GREEN}║${NC}\n" "$(format_duration $fastest_secs)"
        printf "${GREEN}║${NC}  Slowest Story:     %-28s${GREEN}║${NC}\n" "$(format_duration $slowest_secs)"
    fi
    if [[ -n "$github_url" ]]; then
        echo -e "${GREEN}╠══════════════════════════════════════════════════╣${NC}"
        printf "${GREEN}║${NC}  GitHub: %-40s${GREEN}║${NC}\n" "$github_url"
    fi
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Format seconds to Xm Ys format
format_duration() {
    local secs="$1"
    local mins=$((secs / 60))
    local remaining_secs=$((secs % 60))
    printf "%dm %02ds" "$mins" "$remaining_secs"
}

# Show story list with status icons
# Icons: ✅ complete, 🔄 in-progress, ⏸️ pending
# Color coded: green=done, yellow=current, gray=pending
# Shows duration in MM:SS format for completed stories
show_story_list() {
    local current_story_id="${1:-}"

    echo -e "${CYAN}Stories:${NC}"

    # Read stories and display with appropriate icons and colors
    jq -r '.userStories[] | "\(.id)|\(.title)|\(.passes)|\(.durationSecs // 0)"' prd.json | while IFS='|' read -r id title passes duration_secs; do
        if [[ "$passes" == "true" ]]; then
            # Completed story - green with checkmark
            local time_display=""
            if [[ "$duration_secs" -gt 0 ]]; then
                # Format duration in MM:SS
                time_display=" ($(format_duration "$duration_secs"))"
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

    echo -e "${CYAN}Ralph Loop System v1.0${NC}"
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
            show_completion_summary
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

        # Record story start time for duration tracking
        local story_start_time
        story_start_time=$(date +%s)

        # Capture commit hash before story starts (for summary diff)
        local commit_before_story
        commit_before_story=$(git rev-parse HEAD 2>/dev/null || echo "")

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

        # Run Claude Code with spinner
        log_progress "Running Claude Code..."

        # Start spinner in background
        show_spinner "$story_id" &
        SPINNER_PID=$!

        # Ensure spinner is cleaned up on exit
        trap cleanup_spinner EXIT INT TERM

        local output
        local exit_code=0

        if output=$(claude --dangerously-skip-permissions --output-format json -p "$prompt" 2>&1); then
            echo "$output" > "$log_file"
        else
            exit_code=$?
            echo "$output" > "$log_file"
        fi

        # Stop spinner now that Claude is done
        stop_spinner

        if [[ $exit_code -ne 0 ]]; then
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
            mark_story_complete "$story_id" "$story_start_time"

            # Track push status for summary
            local push_status="SKIPPED"

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
                            push_status="SUCCESS"
                        else
                            push_exit_code=$?
                            log_error "Push failed (exit code $push_exit_code), continuing..."
                            echo "Push status: FAILED - Exit code $push_exit_code" >> "$log_file"
                            push_status="FAILED"
                        fi
                    else
                        echo "Push status: SKIPPED - No remote configured" >> "$log_file"
                    fi
                fi
            fi

            # Calculate story duration
            local story_duration_secs
            story_duration_secs=$(($(date +%s) - story_start_time))

            # Show mini summary after successful story completion
            show_story_summary "$story_id" "$story_duration_secs" "$test_commands" "true" "$push_status" "$commit_before_story"

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
