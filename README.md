# Codepulse

Terminal tool to analyze GitHub pull request pickup times, merge times, and sizes using the `gh` CLI.

## Installation

### Prerequisites

1. Ruby 3.0+
2. Install GitHub CLI: https://cli.github.com
3. Authenticate:
   ```sh
   gh auth login
   ```

### Install the gem

```sh
gem build codepulse.gemspec
gem install codepulse-0.1.0.gem
```

## Usage

```sh
# In a git repo (auto-detects owner/repo)
codepulse

# Or specify explicitly
codepulse owner/repo
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-s`, `--state STATE` | `open`, `closed`, or `all` | `all` |
| `-l`, `--limit COUNT` | Max PRs to fetch | auto (5 × business-days) |
| `--business-days DAYS` | PRs from last N business days | `7` |
| `--details` | Show individual PR table (sorted by slowest pickup) | off |
| `--gh-command PATH` | Custom `gh` executable path | `gh` |

### Examples

```sh
# Summary for current repo (last 14 business days)
codepulse

# Summary for specific repo
codepulse rails/rails

# With individual PR details
codepulse rails/rails --details

# Last 30 business days, limit 50 PRs
codepulse rails/rails --business-days 30 --limit 50
```

## Output

```
======================================================================================
  PR PICKUP TIME REPORT | Last 14 business days (Dec 4 - Dec 24)
  rails/rails
======================================================================================

--------------------------------------------------------------------------------------
  SUMMARY (18 PRs with pickup, 5 pending)
--------------------------------------------------------------------------------------

  Average pickup time:  4h 23m
  Median pickup time:   2h 15m
  p95 pickup time:      1d 8h
  Fastest pickup time:  8m
  Slowest pickup time:  2d 5h

  Average time to merge:  1d 2h
  Median time to merge:   18h 30m
  p95 time to merge:      3d 4h
  Fastest time to merge:  45m
  Slowest time to merge:  5d 12h

  ...
```

## What is calculated

- **Pickup time**: Time from PR creation to first non-author response (business days only, Mon–Fri)
- **Time to merge**: Time from PR creation to merge
- **PR size**: Net lines (additions − deletions) and files changed
- **Stats**: Average, median, p95, fastest, slowest

## Filters

- **Default 14 business days**: Only analyzes recent PRs
- **Closed unmerged PRs excluded**: Abandoned PRs are filtered out
- **Bots ignored**: Copilot, GitHub Actions, and other bot reviewers don't count as pickup

## Development

```sh
# Run tests
rake test

# Lint (requires: gem install rubocop)
rubocop

# Rebuild and install
gem build codepulse.gemspec
gem install codepulse-0.1.0.gem
```
