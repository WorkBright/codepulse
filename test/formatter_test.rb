# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

describe Codepulse::Formatter do
  before do
    @formatter = Codepulse::Formatter.new
  end

  it "shows no prs message with empty metrics" do
    output = capture_output do
      @formatter.output([], repo: "owner/repo")
    end

    assert_includes output, "No pull requests found"
  end

  it "includes repo name in header" do
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "rails/rails", business_days: 14)
    end

    assert_includes output, "rails/rails"
  end

  it "includes business days in header" do
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "14 business days"
  end

  it "includes summary section" do
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "SUMMARY"
  end

  it "shows pickup time stats" do
    metrics = [sample_metric(pickup_time_seconds: 3600)]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14)
    end

    assert_includes output, "pickup time"
  end

  it "shows individual prs when details enabled" do
    metrics = [sample_metric]

    output = capture_output do
      @formatter.output(metrics, repo: "owner/repo", business_days: 14, detailed: true)
    end

    assert_includes output, "INDIVIDUAL PRs"
    assert_includes output, "#123"
  end

  describe "median_value" do
    it "returns middle value for odd count" do
      result = @formatter.send(:median_value, [1, 2, 3])
      assert_equal 2, result
    end

    it "returns average of two middle values for even count" do
      result = @formatter.send(:median_value, [1, 2, 3, 4])
      assert_equal 2.5, result
    end

    it "returns the single value for count of one" do
      result = @formatter.send(:median_value, [42])
      assert_equal 42, result
    end

    it "returns nil for empty array" do
      result = @formatter.send(:median_value, [])
      assert_nil result
    end

    it "handles larger odd arrays" do
      result = @formatter.send(:median_value, [10, 20, 30, 40, 50])
      assert_equal 30, result
    end

    it "handles larger even arrays" do
      result = @formatter.send(:median_value, [10, 20, 30, 40])
      assert_equal 25.0, result
    end
  end

  private

  def sample_metric(overrides = {})
    base_time = Time.utc(2024, 12, 23, 12, 0, 0)
    {
      number: 123,
      title: "Fix bug in authentication",
      author: "testuser",
      created_at: base_time - 86_400,
      merged_at: base_time,
      additions: 50,
      deletions: 10,
      changed_files: 3,
      pickup_time_seconds: 7200,
      merge_time_seconds: 86_400,
      pickup_actor: "reviewer",
      pickup_at: base_time - 3600,
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
