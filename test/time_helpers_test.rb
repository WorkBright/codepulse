# frozen_string_literal: true

require_relative "test_helper"

describe Codepulse::TimeHelpers do
  include Codepulse::TimeHelpers

  describe "weekday?" do
    it "returns true for Monday through Friday" do
      monday = Time.utc(2024, 12, 23, 12, 0, 0)
      friday = Time.utc(2024, 12, 27, 12, 0, 0)

      assert weekday?(monday)
      assert weekday?(friday)
    end

    it "returns false for Saturday and Sunday" do
      saturday = Time.utc(2024, 12, 21, 12, 0, 0)
      sunday = Time.utc(2024, 12, 22, 12, 0, 0)

      refute weekday?(saturday)
      refute weekday?(sunday)
    end
  end

  describe "us_holiday?" do
    it "detects Christmas" do
      christmas_this_year = Time.utc(2024, 12, 25, 12, 0, 0)
      christmas_next_year = Time.utc(2025, 12, 25, 12, 0, 0)

      assert us_holiday?(christmas_this_year)
      assert us_holiday?(christmas_next_year)
    end

    it "detects Thanksgiving" do
      thanksgiving_this_year = Time.utc(2024, 11, 28, 12, 0, 0)
      thanksgiving_next_year = Time.utc(2025, 11, 27, 12, 0, 0)

      assert us_holiday?(thanksgiving_this_year)
      assert us_holiday?(thanksgiving_next_year)
    end

    it "detects Independence Day" do
      july_4th = Time.utc(2024, 7, 4, 12, 0, 0)

      assert us_holiday?(july_4th)
    end

    it "returns false for regular day" do
      regular_day = Time.utc(2024, 12, 23, 12, 0, 0)

      refute us_holiday?(regular_day)
    end
  end

  describe "business_day?" do
    it "returns false for weekend" do
      saturday = Time.utc(2024, 12, 21, 12, 0, 0)

      refute business_day?(saturday)
    end

    it "returns false for holiday" do
      christmas = Time.utc(2024, 12, 25, 12, 0, 0)

      refute business_day?(christmas)
    end

    it "returns true for regular weekday" do
      monday = Time.utc(2024, 12, 23, 12, 0, 0)

      assert business_day?(monday)
    end
  end

  describe "business_seconds_between" do
    it "calculates seconds within same day" do
      start_time = Time.utc(2024, 12, 23, 9, 0, 0)
      end_time = Time.utc(2024, 12, 23, 17, 0, 0)

      result = business_seconds_between(start_time, end_time)

      assert_equal 8 * 3600, result
    end

    it "skips weekend" do
      friday_5pm = Time.utc(2024, 12, 20, 17, 0, 0)
      monday_9am = Time.utc(2024, 12, 23, 9, 0, 0)

      result = business_seconds_between(friday_5pm, monday_9am)

      expected = (7 * 3600) + (9 * 3600)
      assert_in_delta expected, result, 1
    end

    it "returns zero for reversed times" do
      later = Time.utc(2024, 12, 23, 17, 0, 0)
      earlier = Time.utc(2024, 12, 23, 9, 0, 0)

      result = business_seconds_between(later, earlier)

      assert_equal 0, result
    end
  end

  describe "parse_time" do
    it "handles valid ISO string" do
      result = parse_time("2024-12-23T09:00:00Z")

      assert_instance_of Time, result
      assert_equal 2024, result.year
      assert_equal 12, result.month
      assert_equal 23, result.day
    end

    it "returns nil for invalid string" do
      result = parse_time("not a date")

      assert_nil result
    end

    it "returns nil for nil input" do
      result = parse_time(nil)

      assert_nil result
    end
  end
end
