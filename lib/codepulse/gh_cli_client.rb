# frozen_string_literal: true

require "open3"

module Codepulse
  class GhCliClient
    include BaseClient

    DEFAULT_COMMAND = "gh"

    def initialize(command: DEFAULT_COMMAND)
      @command = command
      verify_cli_available
    end

    private

    def api_get(path, query_params = {})
      full_path = "#{path}#{encode_query(query_params)}"
      stdout, stderr, status = Open3.capture3(@command, "api", full_path)

      unless status.success?
        message = stderr.to_s.strip.empty? ? stdout.to_s.strip : stderr.to_s.strip
        raise ApiError, "gh api #{full_path} failed: #{message}"
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
