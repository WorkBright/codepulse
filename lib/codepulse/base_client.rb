# frozen_string_literal: true

require "json"
require "uri"

module Codepulse
  module BaseClient
    REPO_FORMAT = %r{\A[^/]+/[^/]+\z}

    def pull_requests(repository, state:, limit:)
      ensure_repository_format(repository)
      per_page = [limit, 100].min
      page = 1
      collected = []

      while collected.length < limit
        response = api_get(
          "/repos/#{repository}/pulls",
          state: state,
          per_page: per_page,
          page: page
        )
        break if response.empty?

        collected.concat(response)
        break if response.length < per_page

        page += 1
      end

      limited = collected.first(limit)
      fetch_pull_request_details(repository, limited)
    end

    def pull_request_reviews(repository, number)
      ensure_repository_format(repository)
      api_get("/repos/#{repository}/pulls/#{number}/reviews", per_page: 100)
    end

    def pull_request_comments(repository, number)
      ensure_repository_format(repository)
      api_get("/repos/#{repository}/pulls/#{number}/comments", per_page: 100)
    end

    def issue_comments(repository, number)
      ensure_repository_format(repository)
      api_get("/repos/#{repository}/issues/#{number}/comments", per_page: 100)
    end

    private

    def api_get(_path, _query_params = {})
      raise NotImplementedError, "Subclasses must implement api_get"
    end

    def ensure_repository_format(repository)
      return if repository.to_s.match?(REPO_FORMAT)

      raise ConfigurationError, "Repository must be in the format owner/name"
    end

    def fetch_pull_request_details(repository, pull_requests)
      pull_requests.map do |pull_request|
        api_get("/repos/#{repository}/pulls/#{pull_request["number"]}")
      end
    end

    def parse_json(body)
      return {} if body.to_s.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError => error
      raise ApiError, "Failed to parse response: #{error.message}"
    end

    def encode_query(query_params)
      return "" if query_params.empty?

      "?#{URI.encode_www_form(query_params)}"
    end
  end
end
