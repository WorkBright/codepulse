# frozen_string_literal: true

require "json"

module Codepulse
  # Shared GitHub API client utilities.
  module BaseClient
    private

    def parse_json(body)
      return {} if body.to_s.strip.empty?

      JSON.parse(body)
    rescue JSON::ParserError => error
      raise ApiError, "Failed to parse response: #{error.message}"
    end
  end
end
