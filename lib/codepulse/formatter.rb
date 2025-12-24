# frozen_string_literal: true

module Codepulse
  class Formatter
    REPORT_WIDTH = 86
    TITLE_LIMIT = 50

    def output(metrics, repo:, detailed: true, business_days: nil)
      if metrics.empty?
        puts "No pull requests found for #{repo}."
        return
      end

      with_pickup = metrics.select { |metric| metric[:pickup_time_seconds] }
      without_pickup = metrics.reject { |metric| metric[:pickup_time_seconds] }

      output_report(
        with_pickup,
        excluded: without_pickup,
        repo: repo,
        business_days: business_days,
        detailed: detailed
      )
    end

    private

    def output_report(metrics, excluded:, repo:, business_days:, detailed:)
      print_report_header(repo, business_days)
      puts
      print_summary(metrics, excluded_count: excluded.count)
      print_details(metrics, excluded: excluded) if detailed
    end

    def print_summary(metrics, excluded_count:)
      print_section_title("SUMMARY (#{metrics.count} PRs with pickup, #{excluded_count} pending)")
      puts

      print_duration_stats("Pickup time", metrics.map { |m| m[:pickup_time_seconds] })
      puts

      print_duration_stats("Time to merge", metrics.map { |m| m[:merge_time_seconds] }.compact)
      puts

      print_number_stats("PR size (net lines)", metrics.map { |m| m[:additions].to_i - m[:deletions].to_i })
      puts

      print_number_stats("Files changed", metrics.map { |m| m[:changed_files].to_i })
    end

    def print_details(metrics, excluded:)
      if metrics.any?
        sorted = metrics.sort_by { |m| -(m[:pickup_time_seconds] || 0) }
        puts
        print_section_title("INDIVIDUAL PRs (slowest pickup first)")
        puts
        output_individual_prs(sorted)
      end

      return unless excluded.any?

      puts
      print_section_title("EXCLUDED PRs (no pickup yet)")
      puts
      output_excluded_prs(excluded)
    end

    def print_report_header(repo, business_days)
      time_period = build_time_period(business_days)
      puts "=" * REPORT_WIDTH
      puts "  PR PICKUP TIME REPORT | #{time_period}"
      puts "  #{repo}"
      puts "=" * REPORT_WIDTH
    end

    def build_time_period(business_days)
      return "all time" unless business_days

      end_date = Time.now
      start_date = calculate_start_date(business_days)
      "Last #{business_days} business days (#{format_date(start_date)} - #{format_date(end_date)})"
    end

    def calculate_start_date(business_days)
      current = Time.now
      remaining = business_days

      while remaining.positive?
        current -= 86_400
        remaining -= 1 if weekday?(current)
      end

      current
    end

    def weekday?(time_value)
      time_value.wday.between?(1, 5)
    end

    def format_date(time_value)
      time_value.strftime("%b %-d")
    end

    def print_section_title(title)
      puts "-" * REPORT_WIDTH
      puts "  #{title}"
      puts "-" * REPORT_WIDTH
    end

    def output_individual_prs(metrics)
      pr_width = 8
      pickup_width = 12
      merge_width = 12
      lines_width = 10
      author_width = 16

      header = [
        "PR".ljust(pr_width),
        "PICKUP".ljust(pickup_width),
        "MERGE".ljust(merge_width),
        "LINES".ljust(lines_width),
        "AUTHOR".ljust(author_width),
        "TITLE"
      ].join("  ")
      puts "  #{header}"

      metrics.each do |metric|
        net_lines = metric[:additions].to_i - metric[:deletions].to_i
        merge_time = metric[:merge_time_seconds] ? format_duration_compact(metric[:merge_time_seconds]) : "—"

        row = [
          "##{metric.fetch(:number)}".ljust(pr_width),
          format_duration_compact(metric[:pickup_time_seconds]).ljust(pickup_width),
          merge_time.ljust(merge_width),
          size_string(net_lines).ljust(lines_width),
          metric.fetch(:author, "unknown").to_s.ljust(author_width),
          truncate(metric.fetch(:title).to_s, 40)
        ].join("  ")
        puts "  #{row}"
      end
    end

    def output_excluded_prs(metrics)
      pr_width = 10
      age_width = 14
      author_width = 20

      header = [
        "PR".ljust(pr_width),
        "AGE".ljust(age_width),
        "AUTHOR".ljust(author_width),
        "TITLE"
      ].join("  ")
      puts "  #{header}"

      metrics.each do |metric|
        age = metric[:created_at] ? time_ago(metric[:created_at]) : "unknown"
        row = [
          "##{metric.fetch(:number)}".ljust(pr_width),
          age.ljust(age_width),
          metric.fetch(:author, "unknown").to_s.ljust(author_width),
          truncate(metric.fetch(:title).to_s, 50)
        ].join("  ")
        puts "  #{row}"
      end
    end

    def print_duration_stats(label, values)
      return puts("  #{label}: none") if values.empty?

      sorted = values.sort
      average_seconds = (values.sum / values.length.to_f).round

      puts "  Average #{label.downcase}:  #{format_duration_compact(average_seconds)}"
      puts "  Median #{label.downcase}:   #{format_duration_compact(percentile_value(sorted, 50))}"
      puts "  p95 #{label.downcase}:      #{format_duration_compact(percentile_value(sorted, 95))}"
      puts "  Fastest #{label.downcase}: #{format_duration_compact(sorted.first)}"
      puts "  Slowest #{label.downcase}: #{format_duration_compact(sorted.last)}"
    end

    def print_number_stats(label, values)
      return puts("  #{label}: none") if values.empty?

      sorted = values.sort
      average_value = (values.sum / values.length.to_f).round(1)

      puts "  Average #{label.downcase}:  #{format_number_compact(average_value)}"
      puts "  Median #{label.downcase}:   #{format_number_compact(percentile_value(sorted, 50))}"
      puts "  p95 #{label.downcase}:      #{format_number_compact(percentile_value(sorted, 95))}"
      puts "  Min #{label.downcase}:      #{format_number_compact(sorted.first)}"
      puts "  Max #{label.downcase}:      #{format_number_compact(sorted.last)}"
    end

    def truncate(value, length)
      return value if value.length <= length

      "#{value[0, length - 1]}…"
    end

    def format_duration_compact(seconds)
      seconds = seconds.to_i
      return "0m" if seconds <= 0

      total_minutes = (seconds / 60.0).round
      minutes = total_minutes % 60
      total_hours = total_minutes / 60
      hours = total_hours % 24
      days = total_hours / 24

      if days.positive?
        hours_part = hours.positive? ? " #{hours}h" : ""
        "#{days}d#{hours_part}"
      elsif total_hours.positive?
        minutes_part = minutes.positive? ? " #{minutes}m" : ""
        "#{total_hours}h#{minutes_part}"
      else
        "#{minutes}m"
      end
    end

    def time_ago(time_value)
      seconds = Time.now - time_value
      return "#{seconds.to_i}s ago" if seconds < 60

      minutes = seconds / 60
      return "#{minutes.round}m ago" if minutes < 60

      hours = minutes / 60
      return "#{hours.round}h ago" if hours < 48

      days = hours / 24
      "#{days.round}d ago"
    end

    def percentile_value(sorted_values, percentile)
      count = sorted_values.length
      rank = (percentile / 100.0 * count).ceil
      index = [rank - 1, count - 1].min
      sorted_values[index]
    end

    def format_number_compact(value)
      return "0" if value.nil?

      if value.is_a?(Float) && value % 1 != 0
        value.round(1).to_s
      else
        value.to_i.to_s
      end
    end
  end
end
