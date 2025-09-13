class ClockController < ApplicationController
  def clock_in
    user = User.find_with_cache(params[:user_id])

    if user.nil?
      return render json: { error: "User not found" }, status: :not_found
    end

    # Check if user already has an active sleep session (no wake_up_at)
    active_session = SleepRecord.by_user(user.id).where(wake_up_at: nil).first

    if active_session.present?
      return render json: {
        error: "User already has an active sleep session",
        active_session: {
          id: active_session.id,
          go_to_bed_at: active_session.go_to_bed_at
        }
      }, status: :unprocessable_entity
    end

    # Get bedtime from params or use current time
    begin
      go_to_bed_time = if params[:go_to_bed_at].present?
                         parsed_time = Time.parse(params[:go_to_bed_at])
                         # Validate that bedtime is not in the future
                         if parsed_time > Time.current
                           return render json: {
                             error: "Invalid bedtime",
                             message: "Bedtime cannot be in the future"
                           }, status: :bad_request
                         end
                         # Validate that bedtime is not too old (e.g., more than 30 days ago)
                         if parsed_time < 30.days.ago
                           return render json: {
                             error: "Invalid bedtime",
                             message: "Bedtime cannot be more than 30 days ago"
                           }, status: :bad_request
                         end
                         parsed_time
      else
                         Time.current
      end
    rescue ArgumentError
      return render json: {
        error: "Invalid timestamp format",
        message: "Please use ISO 8601 format (e.g., 2025-09-13T22:30:00Z)"
      }, status: :bad_request
    end

    # Create new sleep record with clock in time
    sleep_record = SleepRecord.new(
      user_id: user.id,
      go_to_bed_at: go_to_bed_time
    )

    if sleep_record.save
      render json: {
        message: "Clock in successful",
        sleep_record: {
          id: sleep_record.id,
          user_id: sleep_record.user_id,
          go_to_bed_at: sleep_record.go_to_bed_at,
          wake_up_at: sleep_record.wake_up_at,
          duration: sleep_record.duration,
          created_at: sleep_record.created_at
        }
      }, status: :created
    else
      render json: {
        error: "Failed to clock in",
        details: sleep_record.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def clock_out
    user = User.find_with_cache(params[:user_id])

    if user.nil?
      return render json: { error: "User not found" }, status: :not_found
    end

    # Find active sleep session (no wake_up_at)
    active_session = SleepRecord.by_user(user.id).where(wake_up_at: nil).first

    if active_session.nil?
      return render json: { 
        error: "No active sleep session found",
        message: "User needs to clock in first"
      }, status: :unprocessable_entity
    end

    # Get wake up time from params or use current time
    begin
      wake_up_time = if params[:wake_up_at].present?
                       parsed_time = Time.parse(params[:wake_up_at])
                       # Validate that wake up time is not in the future
                       if parsed_time > Time.current
                         return render json: {
                           error: "Invalid wake up time",
                           message: "Wake up time cannot be in the future"
                         }, status: :bad_request
                       end
                       # Validate that wake up time is after bedtime
                       if parsed_time <= active_session.go_to_bed_at
                         return render json: {
                           error: "Invalid wake up time",
                           message: "Wake up time must be after bedtime (#{active_session.go_to_bed_at})"
                         }, status: :bad_request
                       end
                       # Validate reasonable sleep duration (not more than 24 hours)
                       duration_hours = (parsed_time - active_session.go_to_bed_at) / 1.hour
                       if duration_hours >= 24
                         return render json: {
                           error: "Invalid wake up time",
                           message: "Sleep duration cannot exceed 24 hours"
                         }, status: :bad_request
                       end
                       # Validate minimum sleep duration (at least 1 minute)
                       if duration_hours < (1.0/60)
                         return render json: {
                           error: "Invalid wake up time",
                           message: "Sleep duration must be at least 1 minute"
                         }, status: :bad_request
                       end
                       parsed_time
      else
                       Time.current
      end
    rescue ArgumentError
      return render json: {
        error: "Invalid timestamp format",
        message: "Please use ISO 8601 format (e.g., 2025-09-14T06:30:00Z)"
      }, status: :bad_request
    end

    # Calculate duration
    duration_seconds = (wake_up_time - active_session.go_to_bed_at).to_i

    # Update sleep record with clock out time
    active_session.wake_up_at = wake_up_time
    active_session.duration = duration_seconds

    if active_session.save
      render json: {
        message: "Clock out successful - woke up!",
        sleep_record: {
          id: active_session.id,
          user_id: active_session.user_id,
          go_to_bed_at: active_session.go_to_bed_at,
          wake_up_at: active_session.wake_up_at,
          duration: active_session.duration,
          duration_hours: (duration_seconds / 3600.0).round(2),
          created_at: active_session.created_at,
          updated_at: active_session.updated_at
        }
      }, status: :ok
    else
      render json: {
        error: "Failed to clock out",
        details: active_session.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
end
