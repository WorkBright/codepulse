# frozen_string_literal: true

require_relative "test_helper"

class TimeHelpersTest < Minitest::Test
  include Codepulse::TimeHelpers

  def test_weekday_returns_true_for_monday_through_friday
    monday = Time.new(2024, 12, 23, 12, 0, 0)    # Monday
    friday = Time.new(2024, 12, 27, 12, 0, 0)    # Friday

    assert weekday?(monday)
    assert weekday?(friday)
  end

  def test_weekday_returns_false_for_saturday_and_sunday
    saturday = Time.new(2024, 12, 21, 12, 0, 0)  # Saturday
    sunday = Time.new(2024, 12, 22, 12, 0, 0)    # Sunday

    refute weekday?(saturday)
    refute weekday?(sunday)
  end

  def test_us_holiday_detects_christmas
    christmas_this_year = Time.new(2024, 12, 25, 12, 0, 0)
    christmas_next_year = Time.new(2025, 12, 25, 12, 0, 0)

    assert us_holiday?(christmas_this_year)
    assert us_holiday?(christmas_next_year)
  end

  def test_us_holiday_detects_thanksgiving
    thanksgiving_this_year = Time.new(2024, 11, 28, 12, 0, 0)
    thanksgiving_next_year = Time.new(2025, 11, 27, 12, 0, 0)

    assert us_holiday?(thanksgiving_this_year)
    assert us_holiday?(thanksgiving_next_year)
  end

  def test_us_holiday_detects_independence_day
    july_4th = Time.new(2024, 7, 4, 12, 0, 0)

    assert us_holiday?(july_4th)
  end

  def test_us_holiday_returns_false_for_regular_day
    regular_day = Time.new(2024, 12, 23, 12, 0, 0) # Monday before Christmas

    refute us_holiday?(regular_day)
  end

  def test_business_day_returns_false_for_weekend
    saturday = Time.new(2024, 12, 21, 12, 0, 0)

    refute business_day?(saturday)
  end

  def test_business_day_returns_false_for_holiday
    christmas = Time.new(2024, 12, 25, 12, 0, 0)

    refute business_day?(christmas)
  end

  def test_business_day_returns_true_for_regular_weekday
    monday = Time.new(2024, 12, 23, 12, 0, 0)

    assert business_day?(monday)
  end

  def test_business_seconds_between_same_day
    start_time = Time.new(2024, 12, 23, 9, 0, 0)   # Monday 9am
    end_time = Time.new(2024, 12, 23, 17, 0, 0)    # Monday 5pm

    result = business_seconds_between(start_time, end_time)

    assert_equal 8 * 3600, result # 8 hours
  end

  def test_business_seconds_between_skips_weekend
    friday_5pm = Time.new(2024, 12, 20, 17, 0, 0)
    monday_9am = Time.new(2024, 12, 23, 9, 0, 0)

    result = business_seconds_between(friday_5pm, monday_9am)

    # Friday 5pm to end of day + Monday start to 9am, weekend skipped
    # Allow 1 second tolerance for end_of_day calculation
    expected = (7 * 3600) + (9 * 3600)
    assert_in_delta expected, result, 1
  end

  def test_business_seconds_between_returns_zero_for_reversed_times
    later = Time.new(2024, 12, 23, 17, 0, 0)
    earlier = Time.new(2024, 12, 23, 9, 0, 0)

    result = business_seconds_between(later, earlier)

    assert_equal 0, result
  end

  def test_parse_time_handles_valid_iso_string
    result = parse_time("2024-12-23T09:00:00Z")

    assert_instance_of Time, result
    assert_equal 2024, result.year
    assert_equal 12, result.month
    assert_equal 23, result.day
  end

  def test_parse_time_returns_nil_for_invalid_string
    result = parse_time("not a date")

    assert_nil result
  end

  def test_parse_time_returns_nil_for_nil_input
    result = parse_time(nil)

    assert_nil result
  end
end
