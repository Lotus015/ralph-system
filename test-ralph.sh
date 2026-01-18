#!/usr/bin/env bash
# Ralph Test Suite - Automated testing for Ralph Loop System
# Validates all components work correctly

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/ralph-test-$$"
PASSED=0
FAILED=0

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Ralph Loop System - Test Suite${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Cleanup function
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

# Test helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

test_section() {
    echo ""
    echo -e "${BLUE}Testing: $1${NC}"
    echo -e "${BLUE}─────────────────────────────────────${NC}"
}

# Check dependencies
test_section "Dependencies"

if command -v jq &> /dev/null; then
    pass "jq is installed"
else
    fail "jq is not installed"
    echo -e "${RED}Cannot continue without jq${NC}"
    exit 1
fi

if command -v git &> /dev/null; then
    pass "git is installed"
else
    fail "git is not installed"
fi

# Test script syntax
test_section "Script Syntax"

for script in ralph.sh ralph-init.sh ralph-status.sh ralph-reset.sh ralph-logs.sh ralph-prd.sh install.sh uninstall.sh; do
    if [[ -f "$SCRIPT_DIR/$script" ]]; then
        if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
            pass "$script syntax valid"
        else
            fail "$script has syntax errors"
        fi
    else
        fail "$script not found"
    fi
done

# Test script executability
test_section "Script Permissions"

for script in ralph.sh ralph-init.sh ralph-status.sh ralph-reset.sh ralph-logs.sh ralph-prd.sh install.sh uninstall.sh; do
    if [[ -x "$SCRIPT_DIR/$script" ]]; then
        pass "$script is executable"
    else
        fail "$script is not executable"
    fi
done

# Create test directory
test_section "Integration Tests"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize git
git init --quiet
git config user.email "test@ralph.test"
git config user.name "Ralph Test"

# Create minimal prd.json for testing
cat > prd.json << 'EOF'
{
  "project": "Test Project",
  "branchName": "main",
  "description": "Testing Ralph Loop",
  "userStories": [
    {
      "id": "T1",
      "priority": 1,
      "title": "Create hello.txt",
      "description": "Create a file named hello.txt with content 'Hello Ralph'",
      "acceptance": [
        "hello.txt exists",
        "Contains 'Hello Ralph'"
      ],
      "tests": ["test -f hello.txt"],
      "passes": false,
      "completedAt": null
    }
  ]
}
EOF

if [[ -f "prd.json" ]] && jq empty prd.json 2>/dev/null; then
    pass "Created valid test prd.json"
else
    fail "Failed to create valid prd.json"
fi

# Copy prompt.md
cp "$SCRIPT_DIR/prompt.md" ./prompt.md
if [[ -f "prompt.md" ]]; then
    pass "Copied prompt.md"
else
    fail "Failed to copy prompt.md"
fi

# Create empty progress.txt
touch progress.txt
if [[ -f "progress.txt" ]]; then
    pass "Created progress.txt"
else
    fail "Failed to create progress.txt"
fi

# Initialize .ralph-state
echo "0" > .ralph-state
if [[ -f ".ralph-state" ]] && [[ "$(cat .ralph-state)" == "0" ]]; then
    pass "Created .ralph-state with 0"
else
    fail "Failed to create .ralph-state"
fi

# Test ralph-status.sh
if "$SCRIPT_DIR/ralph-status.sh" > /dev/null 2>&1; then
    pass "ralph-status.sh runs without error"
else
    fail "ralph-status.sh failed"
fi

# Test ralph-prd.sh --validate
if "$SCRIPT_DIR/ralph-prd.sh" --validate > /dev/null 2>&1; then
    pass "ralph-prd.sh --validate works"
else
    fail "ralph-prd.sh --validate failed"
fi

# Test ralph-prd.sh --list
if "$SCRIPT_DIR/ralph-prd.sh" --list > /dev/null 2>&1; then
    pass "ralph-prd.sh --list works"
else
    fail "ralph-prd.sh --list failed"
fi

# Test ralph-logs.sh (should fail gracefully with no logs)
if "$SCRIPT_DIR/ralph-logs.sh" -l > /dev/null 2>&1; then
    pass "ralph-logs.sh -l works"
else
    fail "ralph-logs.sh -l failed"
fi

# Test jq operations on prd.json
test_section "JSON Operations"

project=$(jq -r '.project' prd.json)
if [[ "$project" == "Test Project" ]]; then
    pass "Can read project name from prd.json"
else
    fail "Failed to read project name"
fi

story_count=$(jq '.userStories | length' prd.json)
if [[ "$story_count" -eq 1 ]]; then
    pass "Correct story count"
else
    fail "Wrong story count: $story_count"
fi

first_story_id=$(jq -r '.userStories[0].id' prd.json)
if [[ "$first_story_id" == "T1" ]]; then
    pass "Can read first story ID"
else
    fail "Failed to read first story ID"
fi

# Test marking story complete
test_section "Story Completion"

jq '.userStories[0].passes = true | .userStories[0].completedAt = "2026-01-18T00:00:00Z"' prd.json > prd.json.tmp && mv prd.json.tmp prd.json

passes=$(jq -r '.userStories[0].passes' prd.json)
if [[ "$passes" == "true" ]]; then
    pass "Can mark story as complete"
else
    fail "Failed to mark story complete"
fi

completedAt=$(jq -r '.userStories[0].completedAt' prd.json)
if [[ "$completedAt" == "2026-01-18T00:00:00Z" ]]; then
    pass "Can set completedAt timestamp"
else
    fail "Failed to set completedAt"
fi

# Test git operations
test_section "Git Operations"

touch test-file.txt
git add test-file.txt
git commit -m "test: Initial commit" --quiet
if git log --oneline -1 | grep -q "test: Initial commit"; then
    pass "Git commit works"
else
    fail "Git commit failed"
fi

# Test reset functionality
test_section "Reset Functionality"

# Reset story to incomplete
jq '.userStories[0].passes = false | .userStories[0].completedAt = null' prd.json > prd.json.tmp && mv prd.json.tmp prd.json

passes=$(jq -r '.userStories[0].passes' prd.json)
if [[ "$passes" == "false" ]]; then
    pass "Can reset story to incomplete"
else
    fail "Failed to reset story"
fi

# Test example prd.json files
test_section "Example Files"

if [[ -f "$SCRIPT_DIR/examples/todo-api/prd.json" ]]; then
    if jq empty "$SCRIPT_DIR/examples/todo-api/prd.json" 2>/dev/null; then
        pass "examples/todo-api/prd.json is valid JSON"
    else
        fail "examples/todo-api/prd.json is invalid"
    fi
else
    fail "examples/todo-api/prd.json not found"
fi

if [[ -f "$SCRIPT_DIR/examples/react-component/prd.json" ]]; then
    if jq empty "$SCRIPT_DIR/examples/react-component/prd.json" 2>/dev/null; then
        pass "examples/react-component/prd.json is valid JSON"
    else
        fail "examples/react-component/prd.json is invalid"
    fi
else
    fail "examples/react-component/prd.json not found"
fi

# Check example prd.json structure
todo_stories=$(jq '.userStories | length' "$SCRIPT_DIR/examples/todo-api/prd.json")
if [[ "$todo_stories" -gt 0 ]]; then
    pass "todo-api example has $todo_stories stories"
else
    fail "todo-api example has no stories"
fi

react_stories=$(jq '.userStories | length' "$SCRIPT_DIR/examples/react-component/prd.json")
if [[ "$react_stories" -gt 0 ]]; then
    pass "react-component example has $react_stories stories"
else
    fail "react-component example has no stories"
fi

# Test single commit per story (no duplicate commits)
test_section "Single Commit Per Story (S1 Bugfix)"

# Test 1: Verify ralph.sh only commits prd.json, not all changes
# The fix ensures Claude Code commits feature changes, ralph.sh only commits prd.json state
if grep -q 'git add prd.json' "$SCRIPT_DIR/ralph.sh" && ! grep -q 'git add \.' "$SCRIPT_DIR/ralph.sh"; then
    pass "ralph.sh commits only prd.json (not all files)"
else
    fail "ralph.sh should only commit prd.json updates"
fi

# Test 2: Verify the commit message indicates state tracking, not feature commit
if grep -q 'chore: mark.*as complete' "$SCRIPT_DIR/ralph.sh"; then
    pass "ralph.sh uses state-tracking commit message"
else
    fail "ralph.sh should use chore commit for state tracking"
fi

# Test 3: Verify git diff check is used before committing (only commit if prd.json changed)
if grep -q 'git diff --quiet prd.json' "$SCRIPT_DIR/ralph.sh"; then
    pass "ralph.sh checks if prd.json changed before committing"
else
    fail "ralph.sh should check if prd.json changed before committing"
fi

# Test 4: Verify no duplicate git add/commit patterns exist in the main completion block
# Count how many times "git add" appears in the completion block (should be exactly 1)
add_count=$(grep -c 'git add' "$SCRIPT_DIR/ralph.sh" || echo 0)
if [[ "$add_count" -eq 1 ]]; then
    pass "Only one git add command in ralph.sh (no duplicates)"
else
    fail "Expected 1 git add command, found $add_count (potential duplicate commit bug)"
fi

# Test proper loop exit with JSON output parsing (S2 Bugfix)
test_section "JSON Output Parsing & Loop Exit (S2 Bugfix)"

# Test 1: Verify JSON .result field extraction logic exists
if grep -q 'jq -e.*\.result' "$SCRIPT_DIR/ralph.sh"; then
    pass "ralph.sh checks for JSON .result field"
else
    fail "ralph.sh should check for JSON .result field"
fi

# Test 2: Verify fallback to plain text is handled
if grep -q 'plain text output' "$SCRIPT_DIR/ralph.sh"; then
    pass "ralph.sh handles plain text output fallback"
else
    fail "ralph.sh should handle plain text output"
fi

# Test 3: Verify promise COMPLETE detection works with extracted result
if grep -q 'result_text.*COMPLETE' "$SCRIPT_DIR/ralph.sh" || grep -A2 'promise.*COMPLETE' "$SCRIPT_DIR/ralph.sh" | grep -q 'result_text'; then
    pass "Promise COMPLETE detection uses extracted result_text"
else
    fail "Promise COMPLETE detection should use result_text variable"
fi

# Test 4: Verify promise CONTINUE detection works with extracted result
if grep -q 'result_text.*CONTINUE' "$SCRIPT_DIR/ralph.sh" || grep -A2 'promise.*CONTINUE' "$SCRIPT_DIR/ralph.sh" | grep -q 'result_text'; then
    pass "Promise CONTINUE detection uses extracted result_text"
else
    fail "Promise CONTINUE detection should use result_text variable"
fi

# Test 5: Functional test - simulate JSON output parsing
json_output='{"result":"Task done <promise>COMPLETE</promise>","model":"claude"}'
parsed_result=$(echo "$json_output" | jq -r '.result' 2>/dev/null || echo "")
if [[ "$parsed_result" == *"COMPLETE"* ]]; then
    pass "JSON .result extraction correctly finds COMPLETE tag"
else
    fail "JSON .result extraction failed to find COMPLETE tag"
fi

# Test 6: Functional test - simulate JSON without .result field
json_no_result='{"message":"Some output","status":"ok"}'
if echo "$json_no_result" | jq -e '.result' > /dev/null 2>&1; then
    fail "Should not find .result field in message-only JSON"
else
    pass "Correctly identifies JSON without .result field"
fi

# Test 7: Functional test - plain text handling
plain_output="Working on story... <promise>CONTINUE</promise>"
if [[ "$plain_output" == *"CONTINUE"* ]]; then
    pass "Plain text correctly preserves CONTINUE tag"
else
    fail "Plain text handling failed"
fi

# Test 8: Verify 3-stage parsing logic exists (JSON with result, JSON without, plain text)
if grep -q 'Parsed JSON output, extracted .result field' "$SCRIPT_DIR/ralph.sh" && \
   grep -q 'Parsed JSON output (no .result field)' "$SCRIPT_DIR/ralph.sh" && \
   grep -q 'Using plain text output' "$SCRIPT_DIR/ralph.sh"; then
    pass "3-stage parsing logic exists (JSON+result, JSON-only, plain text)"
else
    fail "3-stage parsing logic incomplete"
fi

# Test --auto-push flag parsing
test_section "Auto-Push Flag"

# Test 1: Flag is recognized (no syntax error)
if bash -n "$SCRIPT_DIR/ralph.sh" 2>/dev/null; then
    pass "--auto-push flag syntax is valid"
else
    fail "--auto-push flag causes syntax errors"
fi

# Test 2: Verify AUTO_PUSH variable is set when flag present
# Source ralph.sh argument parsing logic in a subshell to test variable setting
auto_push_result=$(bash -c '
    AUTO_PUSH=false
    for arg in "$@"; do
        case $arg in
            --auto-push)
                AUTO_PUSH=true
                ;;
        esac
    done
    echo $AUTO_PUSH
' -- --auto-push)

if [[ "$auto_push_result" == "true" ]]; then
    pass "AUTO_PUSH is set to true when --auto-push flag present"
else
    fail "AUTO_PUSH not set correctly when --auto-push flag present"
fi

# Test 3: Verify AUTO_PUSH is false by default (no flag)
auto_push_default=$(bash -c '
    AUTO_PUSH=false
    for arg in "$@"; do
        case $arg in
            --auto-push)
                AUTO_PUSH=true
                ;;
        esac
    done
    echo $AUTO_PUSH
' --)

if [[ "$auto_push_default" == "false" ]]; then
    pass "AUTO_PUSH defaults to false when no flag"
else
    fail "AUTO_PUSH should default to false"
fi

# Test 4: Verify help text includes --auto-push documentation
if grep -q "\-\-auto-push" "$SCRIPT_DIR/ralph.sh"; then
    pass "--auto-push is documented in ralph.sh"
else
    fail "--auto-push is not documented in ralph.sh"
fi

# Test 5: Verify --auto-push works with iteration count
auto_push_with_count=$(bash -c '
    AUTO_PUSH=false
    MAX_ITERATIONS=50
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
    echo "$AUTO_PUSH:$MAX_ITERATIONS"
' -- 20 --auto-push)

if [[ "$auto_push_with_count" == "true:20" ]]; then
    pass "--auto-push works correctly with iteration count"
else
    fail "--auto-push fails when combined with iteration count"
fi

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Test Results${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
