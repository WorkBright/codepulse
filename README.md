# Codepulse

Terminal tool to analyze GitHub pull request pickup times, merge times, and sizes using the `gh` CLI.

## Installation

### Prerequisites

1. **Ruby 3.0+**
2. **GitHub CLI** — [Install](https://cli.github.com) and authenticate:
   ```sh
   gh auth login
   ```

### Install from RubyGems

```sh
gem install codepulse
```

### Install from source

```sh
git clone https://github.com/WorkBright/codepulse.git
cd codepulse
bundle install
rake install
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
# Summary for current repo (last 7 business days)
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
  PR PICKUP TIME REPORT | Last 7 business days (Dec 16 - Dec 24)
  rails/rails
======================================================================================

  Pickup time:    Time from PR creation to first reviewer response (business days)
  Time to merge:  Time from PR creation to merge (business days)
  PR size:        Net lines changed (additions - deletions)
  Files changed:  Number of files modified in the PR

--------------------------------------------------------------------------------------
  SUMMARY (18 PRs with pickup, 3 awaiting pickup, 2 merged without pickup)
--------------------------------------------------------------------------------------

  Average pickup time:  4h 23m
  Median pickup time:   2h 15m
  Fastest pickup time:  8m
  Slowest pickup time:  2d 5h

  ...
```

## What is calculated

- **Pickup time**: Time from PR creation to first non-author response (business days, excludes US holidays)
- **Time to merge**: Time from PR creation to merge (business days, excludes US holidays)
- **PR size**: Net lines (additions − deletions) and files changed
- **Stats**: Average, median, p95 (when 50+ PRs), fastest, slowest

## Filters

- **Default 7 business days**: Only analyzes recent PRs
- **Closed unmerged PRs excluded**: Abandoned PRs are filtered out
- **Bots ignored**: Copilot, GitHub Actions, and other bot reviewers don't count as pickup
- **US holidays excluded**: Federal holidays are not counted as business days

## Development

```sh
# Run tests
rake test

# Lint
bundle exec rubocop

# Build and install locally
rake install

# Release new version (bumps tag, pushes to git and RubyGems)
rake release
```

## License

MIT
