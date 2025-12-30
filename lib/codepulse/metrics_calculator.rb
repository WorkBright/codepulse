# frozen_string_literal: true

module Codepulse
  # Calculates pickup time, merge time, and size metrics for pull requests.
  class MetricsCalculator
    include TimeHelpers

    # Bot accounts to ignore when calculating pickup time.
    IGNORED_ACTORS = [
      # GitHub Copilot
      "copilot-pull-request-reviewer",
      "copilot-pull-request-reviewer[bot]",
      "copilot",
      "copilot[bot]",
      "copilot-bot",
      "github-copilot",
      "github-copilot[bot]",

      # GitHub Actions
      "github-actions",
      "github-actions[bot]",

      # AI Coding Assistants
      "cursor[bot]",
      "cursor-bot",
      "codex[bot]",
      "openai-codex",
      "coderabbitai[bot]",
      "coderabbit",
      "sourcery-ai[bot]",
      "sourcery[bot]",
      "codeium[bot]",
      "tabnine[bot]",
      "sweep[bot]",
      "sweepai[bot]",
      "qodo-merge-pro[bot]",
      "codiumai[bot]",
      "amazon-q[bot]",
      "codewhisperer[bot]",
      "aider[bot]",
      "devin[bot]",
      "devin-ai[bot]",

      # Dependency Management
      "dependabot[bot]",
      "dependabot",
      "renovate[bot]",
      "renovate",

      # Security & Code Quality
      "snyk-bot",
      "snyk[bot]",
      "sonarcloud[bot]",
      "sonarqube[bot]",
      "codecov[bot]",
      "codecov",
      "coveralls[bot]",
      "deepsource-autofix[bot]",
      "deepsource[bot]",
      "codefactor[bot]",
      "lgtm-com[bot]",

      # Deployment & Merge Bots
      "vercel[bot]",
      "netlify[bot]",
      "mergify[bot]",
      "kodiakhq[bot]",
      "imgbot[bot]",
      "allstar[bot]"
    ].freeze

    def initialize
      # No client needed - data is pre-fetched via GraphQL
    end

    # Returns a hash of metrics for a single PR.
    # Expects pull_request to include :reviews, :review_comments, :issue_comments from GraphQL.
    def metrics_for_pull_request(pull_request)
      created_at = parse_time(pull_request["created_at"])
      merged_at = parse_time(pull_request["merged_at"])
      pickup_event = find_pickup_event(pull_request, created_at)
      pickup_seconds = pickup_event ? business_seconds_between(created_at, pickup_event.fetch(:timestamp)) : nil
      merge_seconds = merged_at && created_at ? business_seconds_between(created_at, merged_at) : nil

      {
        number: pull_request["number"],
        title: pull_request["title"],
        author: pull_request.dig("user", "login"),
        created_at: created_at,
        merged_at: merged_at,
        additions: pull_request["additions"].to_i,
        deletions: pull_request["deletions"].to_i,
        changed_files: pull_request["changed_files"].to_i,
        pickup_time_seconds: pickup_seconds,
        merge_time_seconds: merge_seconds,
        pickup_actor: pickup_event&.fetch(:actor, nil),
        pickup_at: pickup_event&.fetch(:timestamp, nil),
        pickup_source: pickup_event&.fetch(:source, nil)
      }
    end

    private

    # Finds the first non-author, non-bot response (review, comment, or issue comment).
    # Uses pre-fetched data from GraphQL query.
    def find_pickup_event(pull_request, created_at)
      author_login = pull_request.dig("user", "login")

      review_event = earliest_event(
        pull_request["reviews"] || [],
        author_login: author_login,
        time_key: "submitted_at",
        actor_path: %w[user login],
        source: "review"
      )

      review_comment_event = earliest_event(
        pull_request["review_comments"] || [],
        author_login: author_login,
        time_key: "created_at",
        actor_path: %w[user login],
        source: "review_comment"
      )

      issue_comment_event = earliest_event(
        pull_request["issue_comments"] || [],
        author_login: author_login,
        time_key: "created_at",
        actor_path: %w[user login],
        source: "issue_comment"
      )

      [review_event, review_comment_event, issue_comment_event]
        .compact
        .select { |event| event.fetch(:timestamp) && created_at }
        .min_by { |event| event.fetch(:timestamp) }
    end

    def earliest_event(events, author_login:, time_key:, actor_path:, source:)
      events
        .map { |event| build_event(event, author_login: author_login, time_key: time_key, actor_path: actor_path, source: source) }
        .compact
        .min_by { |event| event.fetch(:timestamp) }
    end

    def build_event(event, author_login:, time_key:, actor_path:, source:)
      actor_login = dig_path(event, actor_path)
      return nil if actor_login.nil?

      normalized_actor = normalize_actor(actor_login)
      normalized_author = normalize_actor(author_login)

      return nil if normalized_actor.nil?
      return nil if normalized_actor == normalized_author
      return nil if IGNORED_ACTORS.include?(normalized_actor)

      timestamp = parse_time(event[time_key])
      return nil unless timestamp

      {
        actor: actor_login,
        timestamp: timestamp,
        source: source
      }
    end

    def dig_path(hash, path)
      path.reduce(hash) { |value, key| value.is_a?(Hash) ? value[key] : nil }
    end

    def normalize_actor(value)
      value.to_s.downcase.strip
    end
  end
end
