# Ralph Loop System - Complete Implementation PRD

## Project Goal
Create a production-ready Ralph Loop system using JSON-based PRD structure, append-only progress logging, and fresh-context iterations with Claude Code auto-approval.

## Requirements Checklist

### Phase 1: Core Loop System
- [ ] Create `ralph.sh` - main bash loop with dangerously-skip-permissions
- [ ] Create `prompt.md` - template prompt given to Claude each iteration
- [ ] Create example `prd.json` with proper structure
- [ ] Create empty `progress.txt` file
- [ ] Create `.ralph-state` initialization
- [ ] Test basic loop functionality

### Phase 2: Helper Scripts
- [ ] Create `ralph-init.sh` - initialize Ralph in a project
- [ ] Create `ralph-status.sh` - show current progress
- [ ] Create `ralph-reset.sh` - reset state and progress
- [ ] Create `ralph-logs.sh` - view iteration logs
- [ ] Make all scripts executable

### Phase 3: PRD Management
- [ ] Create `ralph-prd.sh` - convert markdown PRD to JSON
- [ ] Create `prd-template.md` - markdown template for humans
- [ ] Create script to validate prd.json structure
- [ ] Add ability to list incomplete stories

### Phase 4: Installation & Distribution
- [ ] Create `install.sh` - install Ralph globally to ~/bin/
- [ ] Create `uninstall.sh` - clean removal
- [ ] Create comprehensive README.md
- [ ] Create example projects in `examples/`
- [ ] Add .gitignore for Ralph artifacts

### Phase 5: Testing & Quality
- [ ] Create `test-ralph.sh` - automated test suite
- [ ] Test with sample PRD (simple todo app)
- [ ] Verify all scripts work correctly
- [ ] Test installation/uninstallation
- [ ] Final commit and tag v1.0

## File Specifications

### ralph.sh - Main Loop
Bash script that:
- Accepts max_iterations as argument (default 50)
- Reads prd.json using jq
- Finds first story where "passes": false and priority is lowest number
- Generates prompt from prompt.md template
- Replaces placeholders: STORY_ID, STORY_TITLE, STORY_DESCRIPTION, ACCEPTANCE_CRITERIA, TEST_COMMANDS
- Runs: claude --dangerously-skip-permissions --output-format json -p "generated-prompt"
- Parses output for promise COMPLETE or promise CONTINUE tags
- Updates prd.json setting "passes": true if story complete
- Sets "completedAt" timestamp in ISO format
- Appends learnings to progress.txt with iteration number and timestamp
- Commits changes after successful iteration with message: feat(STORY_ID): STORY_TITLE
- Logs each iteration to .ralph-iteration-N.log
- Exits when all stories have "passes": true
- Shows colored progress output (green=complete, yellow=working, red=failed)
- Implements 2-second sleep between iterations

### prd.json - Task Definition
JSON structure with these exact fields:
- project (string): Project name
- branchName (string): Git branch to work on
- description (string): What we're building
- userStories (array): List of story objects

Each story object must have:
- id (string): Unique identifier like "S1", "S2"
- priority (number): Lower numbers run first
- title (string): Short story title
- description (string): Detailed description
- acceptance (array of strings): Acceptance criteria
- tests (array of strings): Test commands to run
- passes (boolean): Completion status, starts false
- completedAt (string or null): ISO timestamp when completed

Example prd.json to create as reference:
```json
{
  "project": "Todo API",
  "branchName": "main",
  "description": "Simple todo list REST API",
  "userStories": [
    {
      "id": "S1",
      "priority": 1,
      "title": "Setup project structure",
      "description": "Initialize Node.js project with Express",
      "acceptance": [
        "package.json exists with dependencies",
        "Express server starts on port 3000",
        "Basic GET / endpoint returns 200"
      ],
      "tests": ["npm test"],
      "passes": false,
      "completedAt": null
    }
  ]
}
```

### prompt.md - Claude Instructions Template
Create this exact template with placeholders:
```
You are working on story STORY_ID: STORY_TITLE

PROJECT CONTEXT:
Read prd.json for full project details
Read progress.txt for learnings from previous iterations

CURRENT STORY:
STORY_DESCRIPTION

ACCEPTANCE CRITERIA:
ACCEPTANCE_CRITERIA

INSTRUCTIONS:
1. Read the current codebase to understand existing structure
2. Implement ONLY this story - stay focused
3. Keep changes minimal and atomic
4. Write or update tests as specified
5. Run all tests: TEST_COMMANDS
6. If tests pass, commit: git add . && git commit -m "feat(STORY_ID): STORY_TITLE"
7. Update progress.txt with learnings

COMPLETION SIGNALS:
When story is 100% complete and all tests pass:
<promise>COMPLETE</promise>

If you need to continue working or are blocked:
<promise>CONTINUE</promise>

PROGRESS LOGGING:
Append to progress.txt in this format:
=== Iteration N - STORY_ID - TIMESTAMP ===
Status: COMPLETE or IN_PROGRESS or BLOCKED
Learnings:
- What worked well
- What was challenging  
- Gotchas for future stories
- Test results
```

### progress.txt - Append-only Log
Initialize as empty file
Ralph appends entries in this format:
```
=== Iteration 1 - S1 - 2026-01-18T14:30:00Z ===
Status: COMPLETE
Learnings:
- Successfully set up Express server
- package.json configured with nodemon
- Basic tests passing with 100% coverage

=== Iteration 2 - S2 - 2026-01-18T14:35:00Z ===
Status: IN_PROGRESS
Learnings:
- Working on database connection
- PostgreSQL configured locally
```

### ralph-init.sh - Initialize Ralph in Project
Script that:
- Checks if prd.json already exists, warn and exit if yes
- Copies prd-template.md from ~/.ralph-templates/ to current directory
- Opens editor for user to fill in template
- Offers to convert markdown to JSON using ralph-prd.sh
- Creates empty progress.txt
- Creates .ralph-state with "0"
- Initializes git if not exists
- Creates or appends to .gitignore: .ralph-state, .ralph-iteration-*.log
- Shows welcome message and next steps

### ralph-status.sh - Show Progress
Script that:
- Reads prd.json and counts total vs completed stories
- Displays story list with status icons: ✓ complete, ○ pending, ✗ failed
- Shows current iteration number from .ralph-state
- Displays last 10 lines from progress.txt
- Shows last 5 git commits with --oneline
- Displays next story to be worked on (first with passes: false)

### ralph-reset.sh - Reset State
Script that:
- Shows current progress summary
- Asks "Are you sure? This will reset all progress (y/n)"
- If yes:
  - Updates prd.json: sets all "passes" to false, "completedAt" to null
  - Archives progress.txt to progress-YYYYMMDD-HHMMSS.txt
  - Creates fresh empty progress.txt
  - Resets .ralph-state to "0"
  - Removes all .ralph-iteration-*.log files
- Shows confirmation: "Reset complete. Run ./ralph.sh to start fresh"

### ralph-logs.sh - View Logs
Script that:
- Lists all .ralph-iteration-*.log files with iteration numbers
- If argument N provided: displays .ralph-iteration-N.log
- If no argument: displays latest iteration log
- Supports -f flag for tail -f on current/latest log
- Shows last 50 lines by default

### ralph-prd.sh - Convert Markdown to JSON
Script that:
- Takes markdown file path as argument
- Validates markdown file exists
- Uses Claude to convert to prd.json structure
- Command: claude --dangerously-skip-permissions -p "Convert this markdown PRD to JSON format matching prd.json spec. Output only valid JSON."
- Validates output is valid JSON using jq
- Shows preview of generated JSON
- Asks "Save as prd.json? (y/n)"
- If yes: saves to prd.json
- If no: saves to prd-draft.json

### prd-template.md - Human-Friendly Template
Create markdown template:
```markdown
# Project: [Your Project Name]

Branch: main
Description: What you're building and why

## User Stories

### Story 1: [Title]
Priority: 1
Description: Detailed description of what to build
Acceptance Criteria:
- Criterion 1
- Criterion 2
- Criterion 3
Tests: npm test
Status: pending

### Story 2: [Title]  
Priority: 2
Description: Next story description
Acceptance Criteria:
- Criterion 1
Tests: npm test
Status: pending
```

### install.sh - Global Installation
Script that:
- Creates ~/bin directory if not exists
- Copies ralph.sh to ~/bin/ralph
- Copies ralph-init.sh to ~/bin/ralph-init
- Copies ralph-status.sh to ~/bin/ralph-status
- Copies ralph-reset.sh to ~/bin/ralph-reset
- Copies ralph-logs.sh to ~/bin/ralph-logs
- Copies ralph-prd.sh to ~/bin/ralph-prd
- Makes all executables: chmod +x ~/bin/ralph*
- Creates ~/.ralph-templates/ directory
- Copies prd-template.md and prompt.md to templates
- Checks if ~/bin is in PATH, if not adds to ~/.bashrc
- Sources ~/.bashrc
- Shows success message with usage instructions

### uninstall.sh - Clean Removal
Script that:
- Lists what will be removed
- Asks for confirmation
- Removes ~/bin/ralph*
- Removes ~/.ralph-templates/
- Removes PATH entry from ~/.bashrc if added
- Shows "Ralph uninstalled successfully"

### README.md - Documentation
Must include these sections:

**What is Ralph?**
- Autonomous coding loop concept
- Fresh context per iteration
- JSON-based task tracking
- Append-only progress log

**Quick Start:**
```bash
# Install once
cd ralph-system && ./install.sh

# Use in any project
cd my-project
ralph-init
nano prd-template.md  # fill in your stories
ralph-prd prd-template.md
ralph  # let it run
```

**prd.json Structure:**
- Explain each field
- Show example
- Best practices for story sizing

**Writing Good Stories:**
- Keep stories small (1-2 hour tasks)
- Clear acceptance criteria
- Specific test commands
- Priority ordering

**Commands Reference:**
- ralph [max_iterations] - run the loop
- ralph-init - setup in new project
- ralph-status - check progress
- ralph-reset - start over
- ralph-logs [N] - view logs
- ralph-prd file.md - convert markdown

**Examples:**
- Link to examples/ directory
- Simple todo app
- REST API
- Frontend component

**Troubleshooting:**
- jq not found - install jq
- prd.json invalid - validate JSON
- Tests failing - check test commands
- Stuck in loop - check max iterations

**How It Works:**
- Diagram of loop flow
- Explain fresh context
- Explain progress tracking

### test-ralph.sh - Test Suite
Script that:
- Creates temp directory in /tmp/ralph-test-RANDOM
- Generates simple prd.json with one story: "Create hello.txt with content 'Hello Ralph'"
- Creates minimal prompt.md
- Creates empty progress.txt
- Initializes .ralph-state with "0"
- Runs ralph.sh with max 3 iterations
- Verifies hello.txt exists with correct content
- Verifies prd.json has passes: true for story
- Verifies progress.txt has at least one entry
- Verifies git commit exists
- Cleans up temp directory
- Prints PASS or FAIL with details

### .gitignore
Add these patterns:
```
.ralph-state
.ralph-iteration-*.log
progress.txt
prd.json
```

### examples/ - Example Projects
Create examples/todo-api/ with:
- prd.json for simple todo REST API
- README explaining the example
- Expected file structure

Create examples/react-component/ with:
- prd.json for React button component
- README explaining the example

## Exit Criteria

ALL of the following must be true:
1. All Phase 1-5 items are checked [x]
2. All scripts are created and executable
3. prd.json structure matches specification exactly
4. test-ralph.sh passes completely
5. README.md is comprehensive and clear
6. Example projects are working
7. Installation/uninstallation tested
8. All files committed to git
9. Git history is clean with conventional commits

When complete, output exactly:
<promise>COMPLETE</promise>

## Implementation Notes

**Dependencies:**
- Bash 4.0+
- jq (JSON processor) - CHECK if installed, exit with error if not
- git
- Claude Code CLI

**JSON Operations:**
- Use jq for all JSON reading/writing
- Always validate JSON before saving
- Use jq -r for raw string output
- Use jq -c for compact JSON

**Error Handling:**
- Check if prd.json exists before running ralph.sh
- Validate prd.json structure with jq
- Check if userStories array is empty
- Catch Claude Code errors and log them
- Exit gracefully on errors with helpful messages

**Logging:**
- Timestamp format: date -u +"%Y-%m-%dT%H:%M:%SZ"
- Always append to progress.txt, never overwrite
- Include delimiter between entries
- Log both successes and failures

**Git Integration:**
- Check if git repo initialized, warn if not
- Use conventional commit format: feat(ID): description
- Commit after each successful story completion
- Don't commit on failures

**Colors:**
```bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
```

**Best Practices:**
- Quote all variables: "$VAR" not $VAR
- Use functions for repeated logic
- Use set -e at script start
- Add comments for complex sections
- Test incrementally
- Commit after each phase

## Constraints

- Pure bash (no Python, Node, or other languages)
- Must work on Linux and macOS
- Require jq - check and error if missing
- Work incrementally - one phase at a time
- Test each component before moving to next
- Keep commits atomic and well-messaged
- Document as you go
