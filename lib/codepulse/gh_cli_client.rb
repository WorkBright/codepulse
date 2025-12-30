# frozen_string_literal: true

require "open3"
require "json"

module Codepulse
  class GhCliClient
    include BaseClient

    DEFAULT_COMMAND = "gh"
    GRAPHQL_PAGE_SIZE = 50
    ACTIVITY_PAGE_SIZE = 50

    def initialize(command: DEFAULT_COMMAND)
      @command = command
      verify_cli_available
    end

    # Fetches PRs with reviews and comments in a single GraphQL query.
    # Returns array of PR hashes with embedded :reviews, :review_comments, :issue_comments.
    def pull_requests_with_activity(repository, state:, limit:)
      owner, name = repository.split("/", 2)
      raise ConfigurationError, "Repository must be in the format owner/name" unless owner && name

      fetch_all_pull_requests(owner, name, graphql_states(state), limit)
    end

    private

    def fetch_all_pull_requests(owner, name, states, limit)
      pull_requests = []
      cursor = nil

      loop do
        batch_size = [GRAPHQL_PAGE_SIZE, limit - pull_requests.length].min
        response = graphql_query(build_query(owner, name, states, batch_size, cursor))
        nodes, page_info = extract_pr_data(response)
        break if nodes.empty?

        pull_requests.concat(nodes.map { |node| transform_graphql_pr(node) })
        break if pull_requests.length >= limit || !page_info["hasNextPage"]

        cursor = page_info["endCursor"]
      end

      pull_requests.first(limit)
    end

    def extract_pr_data(response)
      pr_data = response.dig("data", "repository", "pullRequests") || {}
      nodes = pr_data["nodes"] || []
      page_info = pr_data["pageInfo"] || {}
      [nodes, page_info]
    end

    def graphql_states(state)
      case state
      when "open" then %w[OPEN]
      when "closed" then %w[CLOSED MERGED]
      else %w[OPEN CLOSED MERGED]
      end
    end

    def build_query(owner, name, states, batch_size, cursor)
      after_clause = cursor ? ", after: \"#{cursor}\"" : ""
      states_clause = states.join(", ")

      <<~GRAPHQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            pullRequests(first: #{batch_size}, states: [#{states_clause}], orderBy: {field: CREATED_AT, direction: DESC}#{after_clause}) {
              pageInfo { hasNextPage endCursor }
              nodes {
                number title state createdAt mergedAt additions deletions changedFiles
                author { login }
                reviews(first: #{ACTIVITY_PAGE_SIZE}) { nodes { submittedAt author { login } } }
                reviewThreads(first: #{ACTIVITY_PAGE_SIZE}) { nodes { comments(first: #{ACTIVITY_PAGE_SIZE}) { nodes { createdAt author { login } } } } }
                comments(first: #{ACTIVITY_PAGE_SIZE}) { nodes { createdAt author { login } } }
              }
            }
          }
        }
      GRAPHQL
    end

    def transform_graphql_pr(node)
      {
        "number" => node["number"],
        "title" => node["title"],
        "state" => node["state"]&.downcase,
        "created_at" => node["createdAt"],
        "merged_at" => node["mergedAt"],
        "additions" => node["additions"],
        "deletions" => node["deletions"],
        "changed_files" => node["changedFiles"],
        "user" => { "login" => node.dig("author", "login") },
        "reviews" => transform_reviews(node),
        "review_comments" => transform_review_comments(node),
        "issue_comments" => transform_issue_comments(node)
      }
    end

    def transform_reviews(node)
      (node.dig("reviews", "nodes") || []).map do |review|
        { "submitted_at" => review["submittedAt"], "user" => { "login" => review.dig("author", "login") } }
      end
    end

    def transform_review_comments(node)
      (node.dig("reviewThreads", "nodes") || []).flat_map do |thread|
        (thread.dig("comments", "nodes") || []).map do |comment|
          { "created_at" => comment["createdAt"], "user" => { "login" => comment.dig("author", "login") } }
        end
      end
    end

    def transform_issue_comments(node)
      (node.dig("comments", "nodes") || []).map do |comment|
        { "created_at" => comment["createdAt"], "user" => { "login" => comment.dig("author", "login") } }
      end
    end

    def graphql_query(query)
      stdout, stderr, status = Open3.capture3(@command, "api", "graphql", "-f", "query=#{query}")

      unless status.success?
        message = stderr.to_s.strip.empty? ? stdout.to_s.strip : stderr.to_s.strip
        raise ApiError, "GraphQL query failed: #{message}"
      end

      parse_json(stdout)
    rescue Errno::ENOENT
      raise ConfigurationError, "gh CLI not found. Install it from https://cli.github.com and run `gh auth login`."
    end

    def verify_cli_available
      _stdout, _stderr, status = Open3.capture3(@command, "auth", "status")
      return if status.success?

      raise ConfigurationError, "gh CLI not authenticated. Run `gh auth login` first."
    rescue Errno::ENOENT
      raise ConfigurationError, "gh CLI not found. Install it from https://cli.github.com and run `gh auth login`."
    end
  end
end
