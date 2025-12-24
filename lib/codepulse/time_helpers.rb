# frozen_string_literal: true

require "time"

module Codepulse
  module TimeHelpers
    SECONDS_PER_DAY = 86_400

    def parse_time(value)
      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def business_day?(time_value)
      return false unless weekday?(time_value)
      return false if us_holiday?(time_value)

      true
    end

    def weekday?(time_value)
      time_value.wday.between?(1, 5)
    end

    def us_holiday?(time_value)
      us_holidays(time_value.year).include?(date_key(time_value))
    end

    def date_key(time_value)
      [time_value.year, time_value.month, time_value.day]
    end

    def us_holidays(year)
      @us_holidays_cache ||= {}
      @us_holidays_cache[year] ||= build_us_holidays(year)
    end

    def build_us_holidays(year)
      holidays = []

      # New Year's Day (Jan 1)
      holidays << [year, 1, 1]

      # MLK Day (3rd Monday in January)
      holidays << nth_weekday(year, 1, 1, 3)

      # Presidents Day (3rd Monday in February)
      holidays << nth_weekday(year, 2, 1, 3)

      # Memorial Day (last Monday in May)
      holidays << last_weekday(year, 5, 1)

      # Juneteenth (June 19)
      holidays << [year, 6, 19]

      # Independence Day (July 4)
      holidays << [year, 7, 4]

      # Labor Day (1st Monday in September)
      holidays << nth_weekday(year, 9, 1, 1)

      # Columbus Day (2nd Monday in October)
      holidays << nth_weekday(year, 10, 1, 2)

      # Veterans Day (Nov 11)
      holidays << [year, 11, 11]

      # Thanksgiving (4th Thursday in November)
      holidays << nth_weekday(year, 11, 4, 4)

      # Christmas Day (Dec 25)
      holidays << [year, 12, 25]

      holidays
    end

    def nth_weekday(year, month, target_wday, occurrence)
      first_day = Time.new(year, month, 1)
      days_until = (target_wday - first_day.wday + 7) % 7
      day = 1 + days_until + (7 * (occurrence - 1))
      [year, month, day]
    end

    def last_weekday(year, month, target_wday)
      next_month = month == 12 ? Time.new(year + 1, 1, 1) : Time.new(year, month + 1, 1)
      last_day = next_month - SECONDS_PER_DAY
      days_back = (last_day.wday - target_wday + 7) % 7
      [year, month, last_day.day - days_back]
    end

    def start_of_day(time_value)
      Time.new(time_value.year, time_value.month, time_value.day, 0, 0, 0, time_value.utc_offset)
    end

    def end_of_day(time_value)
      Time.new(time_value.year, time_value.month, time_value.day, 23, 59, 59, time_value.utc_offset)
    end

    def business_seconds_between(start_time, end_time)
      return nil unless start_time && end_time
      return 0 if end_time <= start_time

      total = 0
      current_start = start_time

      while current_start < end_time
        day_end = end_of_day(current_start)
        segment_end = [day_end, end_time].min

        total += (segment_end - current_start) if business_day?(current_start)

        current_start = start_of_day(current_start + SECONDS_PER_DAY)
      end

      total.to_i
    end

    def business_days_cutoff(business_days)
      return nil unless business_days

      current_time = Time.now
      remaining_days = business_days

      while remaining_days.positive?
        current_time -= SECONDS_PER_DAY
        remaining_days -= 1 if business_day?(current_time)
      end

      start_of_day(current_time)
    end
  end
end
