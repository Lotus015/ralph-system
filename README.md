# Ralph Loop System

An autonomous coding loop that uses Claude Code to complete user stories with fresh context per iteration.

## What is Ralph?

Ralph is an autonomous coding loop system that:

- **Fresh Context Per Iteration**: Each Claude Code invocation starts with a clean slate, reading current project state
- **JSON-Based Task Tracking**: User stories are defined in `prd.json` with acceptance criteria and tests
- **Append-Only Progress Log**: Learnings and status are logged to `progress.txt` for context sharing
- **Automatic Git Commits**: Commits are made after each successful story completion
- **Promise-Based Completion**: Claude signals completion with `<promise>COMPLETE</promise>` tags

```
┌─────────────────────────────────────────────────────────────┐
│                    Ralph Loop Flow                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌──────────┐    ┌──────────┐    ┌──────────────────────┐ │
│   │ prd.json │───>│ ralph.sh │───>│ Claude Code          │ │
│   │ (stories)│    │ (loop)   │    │ --dangerously-skip   │ │
│   └──────────┘    └────┬─────┘    └──────────┬───────────┘ │
│                        │                      │             │
│                        │                      ▼             │
│                        │         ┌────────────────────────┐ │
│                        │         │ <promise>COMPLETE</> ? │ │
│                        │         └────────────┬───────────┘ │
│                        │                      │             │
│                        │         ┌────────────┴───────────┐ │
│                        │         │                        │ │
│                        │     Complete              Continue │
│                        │         │                        │ │
│                        │         ▼                        ▼ │
│                        │  ┌─────────────┐    ┌───────────┐ │
│                        │  │ Update JSON │    │ Next iter │ │
│                        │  │ Git commit  │    │           │ │
│                        │  └─────────────┘    └───────────┘ │
│                        │         │                   │      │
│                        └─────────┴───────────────────┘      │
│                              (loop continues)               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/ralph-system.git
cd ralph-system

# Install globally
./install.sh
```

### Use in Any Project

```bash
cd my-project
ralph-init           # Initialize Ralph in this project
nano prd-template.md # Fill in your stories
ralph-prd prd-template.md  # Convert to prd.json
ralph                # Let it run!
```

## prd.json Structure

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

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `project` | string | Project name |
| `branchName` | string | Git branch to work on |
| `description` | string | Project description |
| `userStories` | array | List of story objects |
| `id` | string | Unique story identifier (S1, S2, etc.) |
| `priority` | number | Execution order (lower = first) |
| `title` | string | Short story title |
| `description` | string | Detailed description |
| `acceptance` | array | Acceptance criteria strings |
| `tests` | array | Test commands to run |
| `passes` | boolean | Completion status |
| `completedAt` | string/null | ISO timestamp when completed |

## Writing Good Stories

### Keep Stories Small

- Each story should be completable in 1-2 hours of work
- Break large features into multiple stories
- One clear objective per story

### Clear Acceptance Criteria

Good:
```
- User can click 'Add Todo' button
- New todo appears in the list
- Input field is cleared after adding
```

Bad:
```
- It works
- Everything is done
```

### Specific Test Commands

Good:
```json
"tests": ["npm test", "npm run lint"]
```

Bad:
```json
"tests": ["run tests"]
```

### Priority Ordering

- Set `priority: 1` for foundational work (setup, dependencies)
- Increment priority for dependent features
- Stories with lower priority numbers run first

## Commands Reference

### `ralph [max_iterations] [--auto-push]`

Run the Ralph loop to complete user stories.

```bash
ralph              # Run with default 50 iterations
ralph 10           # Run with max 10 iterations
ralph 20 --auto-push  # Run with auto-push enabled
```

**Options:**

| Flag | Description |
|------|-------------|
| `--auto-push` | Automatically push commits to origin after each successful iteration |

### `ralph-init`

Initialize Ralph in a new project.

```bash
cd my-project
ralph-init
```

Creates:
- `prd-template.md` - Template for your stories
- `prompt.md` - Claude instruction template
- `progress.txt` - Empty progress log
- `.ralph-state` - Iteration counter
- Updates `.gitignore`

### `ralph-status`

Check current progress.

```bash
ralph-status
```

Shows:
- Project info
- Story completion status
- Current iteration
- Recent progress entries
- Recent git commits

### `ralph-reset`

Reset all progress and start fresh.

```bash
ralph-reset
```

Does:
- Resets all stories to `passes: false`
- Archives `progress.txt`
- Resets iteration counter
- Removes log files

### `ralph-logs [options] [iteration]`

View iteration logs.

```bash
ralph-logs          # View latest log
ralph-logs 5        # View iteration 5
ralph-logs -f       # Follow latest log
ralph-logs -l       # List all logs
```

### `ralph-prd <file.md>`

Convert markdown PRD to JSON.

```bash
ralph-prd prd-template.md    # Convert markdown
ralph-prd -v                 # Validate prd.json
ralph-prd -l                 # List incomplete stories
```

## Examples

See the `examples/` directory for sample projects:

- `examples/todo-api/` - Simple REST API example
- `examples/react-component/` - React component example

## Troubleshooting

### jq not found

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Windows (WSL)
sudo apt install jq
```

### prd.json invalid

Validate with:
```bash
ralph-prd -v
```

Or check JSON syntax:
```bash
jq empty prd.json
```

### Tests failing

Check the test commands in your `prd.json`:
```bash
ralph-prd -l  # List stories with their test commands
```

Run tests manually to debug:
```bash
npm test
```

### Stuck in loop

- Check `ralph-logs` for the latest error
- Increase `max_iterations` if needed
- Review acceptance criteria for clarity

### Claude not responding correctly

Ensure your `prompt.md` template is clear and includes:
- The `<promise>COMPLETE</promise>` signal instructions
- Clear acceptance criteria
- Specific test commands

## How It Works

1. **Read State**: Ralph reads `prd.json` to find the first incomplete story (by priority)

2. **Generate Prompt**: Fills `prompt.md` template with story details

3. **Run Claude**: Executes Claude Code with `--dangerously-skip-permissions`

4. **Parse Result**: Looks for `<promise>COMPLETE</promise>` or `<promise>CONTINUE</promise>`

5. **Update State**:
   - If COMPLETE: Updates `prd.json`, commits changes
   - If CONTINUE: Loops to next iteration

6. **Log Progress**: Appends to `progress.txt` and `.ralph-iteration-N.log`

7. **Repeat**: Continues until all stories pass or max iterations reached

## Auto-Push Feature

The `--auto-push` flag enables automatic pushing of commits to the remote repository after each successful iteration.

### When to Use

Use `--auto-push` when you want to:
- Keep a remote backup of progress as work happens
- Enable team visibility into autonomous work
- Trigger CI/CD pipelines on each iteration

### Example Usage

```bash
ralph 20 --auto-push
```

This runs up to 20 iterations, pushing each successful commit to origin.

### Remote Configuration

**Important:** Ensure your git remote is configured before using `--auto-push`:

```bash
# Check if remote exists
git remote get-url origin

# Add remote if missing
git remote add origin git@github.com:your-org/your-repo.git
```

### Behavior When Remote is Missing

If no remote is configured, Ralph will:
1. Print a yellow warning: `⚠ No git remote 'origin' configured. Skipping push.`
2. Skip the push operation
3. Continue to the next iteration normally

The loop will not fail or exit - it simply skips the push step and continues working.

## Requirements

- Bash 4.0+
- [jq](https://stedolan.github.io/jq/) - JSON processor
- [git](https://git-scm.com/)
- [Claude Code CLI](https://claude.ai/code)

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./test-ralph.sh`
5. Submit a pull request
