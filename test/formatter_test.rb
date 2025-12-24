# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class FormatterTest < Minitest::Test
  def setup
    @formatter = Codepulse::Formatter.new
  end

  def test_output_with_empty_metrics_shows_no_prs_message
    output = capture_output do
      @formatter.output([], repo: "owner/repo")
    end

    assert_includes output, "No pull requests found"
  end

  def test_output_includes_repo_name_in_header
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "rails/rails", business_days: 14)
    end

    assert_includes output, "rails/rails"
  end

  def test_output_includes_business_days_in_header
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "14 business days"
  end

  def test_output_includes_summary_section
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "SUMMARY"
  end

  def test_output_shows_pickup_time_stats
    metrics = [sample_metric(pickup_time_seconds: 3600)]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "pickup time"
  end

  def test_output_with_details_shows_individual_prs
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14, detailed: true)
    end

    assert_includes output, "INDIVIDUAL PRs"
    assert_includes output, "#123"
  end

  private

  def sample_metric(overrides = {})
    {
      number: 123,
      title: "Fix bug in authentication",
      author: "testuser",
      created_at: Time.now - 86_400,
      merged_at: Time.now,
      additions: 50,
      deletions: 10,
      changed_files: 3,
      pickup_time_seconds: 7200,
      merge_time_seconds: 86_400,
      pickup_actor: "reviewer",
      pickup_at: Time.now - 3600,
      pickup_source: "review"
    }.merge(overrides)
  end

  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
