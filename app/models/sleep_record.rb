class SleepRecord < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, presence: true
  validates :go_to_bed_at, presence: true
  validates :wake_up_at, presence: true, allow_nil: true
  validates :duration, presence: true, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :active_sessions, -> { where(wake_up_at: nil) }
  scope :completed, -> { where("duration > 0") }
  scope :in_period, ->(start_date, end_date) { where(go_to_bed_at: start_date..end_date) }

  class << self
    def calculate_statistics_for_user(user, period_days)
      # Get sleep records for the specified period
      # Use end of current day to include records from today
      start_date = period_days.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      sleep_records = by_user(user.id)
        .in_period(start_date, end_date)
        .completed
        .order(:go_to_bed_at)

      total_records = sleep_records.count

      if total_records == 0
        return {
          user_id: user.id,
          period: "last_#{period_days}_days",
          message: "No sleep records found for this period",
          statistics: nil
        }
      end

      # Basic calculations
      durations = sleep_records.pluck(:duration)
      total_sleep_seconds = durations.sum
      average_duration = total_sleep_seconds.to_f / total_records

      # Duration analysis
      shortest_record = sleep_records.order(:duration).first
      longest_record = sleep_records.order(:duration).last

      # Sleep pattern analysis
      bedtimes = sleep_records.pluck(:go_to_bed_at).map { |time| time.hour + time.min/60.0 }
      wake_times = sleep_records.pluck(:wake_up_at).map { |time| time.hour + time.min/60.0 }

      # Sleep consistency (standard deviation of durations)
      duration_hours = durations.map { |d| d / 3600.0 }
      mean_duration_hours = duration_hours.sum / duration_hours.size
      variance = duration_hours.map { |d| (d - mean_duration_hours) ** 2 }.sum / duration_hours.size
      consistency_score = [100 - (Math.sqrt(variance) * 20), 0].max.round(1)

      # Sleep quality score (based on duration optimality and consistency)
      optimal_duration = 8.0 # hours
      duration_score = [100 - (mean_duration_hours - optimal_duration).abs * 15, 0].max
      quality_score = ((duration_score * 0.7) + (consistency_score * 0.3)).round(1)

      # Sleep debt calculation
      recommended_total = optimal_duration * total_records * 3600
      sleep_debt_seconds = total_sleep_seconds - recommended_total
      sleep_debt_hours = sleep_debt_seconds / 3600.0

      # Duration range analysis
      duration_ranges = {
        "under_6h" => duration_hours.count { |d| d < 6 },
        "6_7h" => duration_hours.count { |d| d >= 6 && d < 7 },
        "7_8h" => duration_hours.count { |d| d >= 7 && d < 8 },
        "8_9h" => duration_hours.count { |d| d >= 8 && d < 9 },
        "over_9h" => duration_hours.count { |d| d >= 9 }
      }
      most_common_range = duration_ranges.max_by { |_, count| count }&.first

      {
        user_id: user.id,
        period: "last_#{period_days}_days",
        period_range: {
          start_date: start_date.strftime("%Y-%m-%d"),
          end_date: (end_date - 1.day).strftime("%Y-%m-%d")
        },
        statistics: {
          overview: {
            total_records: total_records,
            average_duration_hours: (average_duration / 3600.0).round(2),
            sleep_quality_score: quality_score,
            sleep_debt_hours: sleep_debt_hours.round(2),
            consistency_score: consistency_score
          },
          duration_analysis: {
            shortest_sleep: {
              duration_hours: (shortest_record.duration / 3600.0).round(2),
              date: shortest_record.go_to_bed_at.strftime("%Y-%m-%d"),
              formatted: format_duration(shortest_record.duration)
            },
            longest_sleep: {
              duration_hours: (longest_record.duration / 3600.0).round(2),
              date: longest_record.go_to_bed_at.strftime("%Y-%m-%d"),
              formatted: format_duration(longest_record.duration)
            },
            most_common_range: most_common_range&.humanize || "N/A",
            duration_distribution: duration_ranges
          },
          patterns: {
            average_bedtime: format_time_of_day(bedtimes.sum / bedtimes.size),
            average_wake_time: format_time_of_day(wake_times.sum / wake_times.size),
            bedtime_consistency: calculate_time_consistency(bedtimes),
            wake_time_consistency: calculate_time_consistency(wake_times)
          }
        },
        generated_at: Time.current.iso8601
      }
    end

    private

    def format_duration(duration_seconds)
      hours = duration_seconds / 3600
      minutes = (duration_seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end

    def format_time_of_day(hour_decimal)
      hour = hour_decimal.to_i
      minute = ((hour_decimal - hour) * 60).to_i
      sprintf("%02d:%02d", hour, minute)
    end

    def calculate_time_consistency(times)
      return 100 if times.size <= 1

      # Calculate standard deviation of times (accounting for 24-hour wrap-around)
      mean_time = times.sum / times.size
      variance = times.map { |t| (t - mean_time) ** 2 }.sum / times.size
      std_dev = Math.sqrt(variance)

      # Convert to consistency score (0-100, where 100 is most consistent)
      # 1 hour standard deviation = 50 points, 2 hours = 0 points
      consistency = [100 - (std_dev * 50), 0].max.round(1)
      consistency
    end
  end
end
