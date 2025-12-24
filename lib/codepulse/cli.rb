# frozen_string_literal: true

require "optparse"
require "open3"
require "json"

module Codepulse
  class CLI
    include TimeHelpers

    DEFAULT_STATE = "all"
    DEFAULT_BUSINESS_DAYS = 14
    PRS_PER_BUSINESS_DAY = 5
    MAX_AUTO_LIMIT = 200

    def self.start(argument_list = ARGV)
      new(argument_list).run
    end

    def initialize(argument_list)
      @argument_list = argument_list
      @options = {
        state: DEFAULT_STATE,
        limit: nil,
        gh_command: GhCliClient::DEFAULT_COMMAND,
        business_days_back: DEFAULT_BUSINESS_DAYS,
        details: false
      }
    end

    def run
      parse_options
      validate_required_options

      repo = @options.fetch(:repo)
      client = GhCliClient.new(command: @options.fetch(:gh_command))

      pull_requests = fetch_pull_requests(client, repo)
      pull_requests = apply_filters(pull_requests)
      metrics = calculate_metrics(client, repo, pull_requests)

      clear_status
      Formatter.new.output(
        metrics,
        repo: repo,
        detailed: @options.fetch(:details),
        business_days: @options.fetch(:business_days_back)
      )
    rescue OptionParser::ParseError => error
      $stderr.puts "Error: #{error.message}"
      $stderr.puts
      $stderr.puts option_parser
      exit 1
    rescue ConfigurationError => error
      $stderr.puts "Configuration error: #{error.message}"
      exit 1
    rescue ApiError => error
      $stderr.puts "GitHub API error: #{error.message}"
      exit 1
    end

    private

    def parse_options
      option_parser.parse!(@argument_list)
      @options[:repo] = @argument_list.shift if @argument_list.any?
      @options[:repo] ||= detect_repo_from_git
    end

    def option_parser
      @option_parser ||= OptionParser.new do |parser|
        parser.banner = "Usage: codepulse [options] [owner/repo]"

        parser.on("-s", "--state STATE", "Pull request state: open, closed, all (default: #{DEFAULT_STATE})") do |state|
          @options[:state] = state
        end

        parser.on("-l", "--limit COUNT", Integer, "Max PRs to fetch (default: auto based on business-days)") do |count|
          @options[:limit] = count
        end

        parser.on("--gh-command PATH", "Path to gh executable (default: #{GhCliClient::DEFAULT_COMMAND})") do |path|
          @options[:gh_command] = path
        end

        parser.on("--business-days DAYS", Integer, "PRs from last N business days (default: #{DEFAULT_BUSINESS_DAYS})") do |days|
          @options[:business_days_back] = days
        end

        parser.on("--details", "Show per-PR detail table instead of summary") do
          @options[:details] = true
        end

        parser.on("-h", "--help", "Show help") do
          puts parser
          exit
        end
      end
    end

    def validate_required_options
      raise OptionParser::MissingArgument, "owner/repo is required" unless @options[:repo]

      validate_state
      validate_positive_integer(:limit, "limit")
      validate_positive_integer(:business_days_back, "business-days")
    end

    def validate_state
      return if %w[open closed all].include?(@options[:state])

      raise OptionParser::InvalidArgument, "state must be open, closed, or all"
    end

    def validate_positive_integer(key, name)
      value = @options[key]
      return if value.nil?
      return if value.is_a?(Integer) && value.positive?

      raise OptionParser::InvalidArgument, "#{name} must be a positive integer"
    end

    def fetch_pull_requests(client, repo)
      limit = effective_limit
      status "Fetching pull requests from #{repo}..."
      client.pull_requests(repo, state: @options.fetch(:state), limit: limit)
    end

    def effective_limit
      return @options[:limit] if @options[:limit]

      business_days = @options.fetch(:business_days_back)
      calculated = business_days * PRS_PER_BUSINESS_DAY
      [calculated, MAX_AUTO_LIMIT].min
    end

    def apply_filters(pull_requests)
      status "Filtering #{pull_requests.length} pull requests..."
      pull_requests = exclude_closed_unmerged(pull_requests)

      cutoff_time = business_days_cutoff(@options[:business_days_back])
      pull_requests = filter_by_business_days(pull_requests, cutoff_time) if cutoff_time
      pull_requests
    end

    def calculate_metrics(client, repo, pull_requests)
      status "Calculating metrics for #{pull_requests.length} pull requests..."
      calculator = MetricsCalculator.new(client: client)

      pull_requests.each_with_index.map do |pull_request, index|
        status "  Analyzing PR ##{pull_request["number"]} (#{index + 1}/#{pull_requests.length})..."
        calculator.metrics_for_pull_request(repo, pull_request)
      end
    end

    def exclude_closed_unmerged(pull_requests)
      pull_requests.reject do |pull_request|
        pull_request["state"] == "closed" && pull_request["merged_at"].nil?
      end
    end

    def filter_by_business_days(pull_requests, cutoff_time)
      pull_requests.select do |pull_request|
        created_at = parse_time(pull_request["created_at"])
        created_at && created_at >= cutoff_time
      end
    end

    def detect_repo_from_git
      stdout, _stderr, status = Open3.capture3(@options[:gh_command], "repo", "view", "--json", "nameWithOwner")
      return nil unless status.success?

      data = JSON.parse(stdout)
      data["nameWithOwner"]
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end

    def status(message)
      $stderr.print "\r\e[K#{message}"
    end

    def clear_status
      $stderr.print "\r\e[K"
    end
  end
end
