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
      wday = time_value.wday
      wday.between?(1, 5)
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
