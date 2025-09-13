class SleepRecordsController < ApplicationController
  def index
    # Cache user lookup in Redis for performance
    user = User.find_with_cache(params[:user_id])

    if user.nil?
      return render json: { error: "User not found" }, status: :not_found
    end

    # Define all parameters
    page = params[:page]&.to_i || 1
    limit = params[:limit]&.to_i || 10
    cursor = params[:cursor]

    if cursor.present?
      # Pointer/Cursor-based pagination (recommended for large datasets)
      cursor_based_pagination(user, cursor, limit)
    else
      # Traditional pagination (simple but less efficient for large datasets)
      traditional_pagination(user, page, limit)
    end
  end

  def friends_sleep_records
    user = User.find_with_cache(params[:user_id])

    if user.nil?
      return render json: { error: "User not found" }, status: :not_found
    end

    # Get the user's following list with Redis cache
    following_user_ids = user.following_user_ids_with_cache

    if following_user_ids.empty?
      return render json: {
        message: "User is not following anyone",
        friends_sleep_records: [],
        week_range: {
          start_date: 1.week.ago.beginning_of_week.strftime("%Y-%m-%d"),
          end_date: 1.week.ago.end_of_week.strftime("%Y-%m-%d")
        },
        pagination: {
          current_page: 1,
          total_pages: 0,
          total_count: 0,
          per_page: params[:limit]&.to_i || 10
        }
      }
    end

    # Define pagination parameters
    page = params[:page]&.to_i || 1
    limit = params[:limit]&.to_i || 10

    # Note: We use traditional pagination instead of cursor pagination for this endpoint because:
    # 1. Limited dataset: Only fetches data from one specific week (previous week)
    # 2. Small, bounded data: The dataset is finite and won't grow infinitely
    # 3. Better UX for small datasets: Users can see total pages and jump to specific pages
    # 4. Simpler implementation: No need for complex cursor logic for such a small dataset
    # 5. Sorting by duration: Traditional pagination works well when sorting by non-unique fields

    # Define the previous week range
    previous_week_start = 1.week.ago.beginning_of_week
    previous_week_end = 1.week.ago.end_of_week

    # Get sleep records from followed users in the previous week with pagination
    friends_sleep_records = SleepRecord
      .joins(:user)
      .where(user_id: following_user_ids)
      .where(go_to_bed_at: previous_week_start..previous_week_end)
      .where("duration > 0")
      .order(duration: :desc)
      .includes(:user)
      .page(page).per(limit)

    # Format the response with user information
    formatted_records = friends_sleep_records.map do |record|
      {
        id: record.id,
        user: {
          id: record.user.id,
          name: record.user.name
        },
        go_to_bed_at: record.go_to_bed_at,
        wake_up_at: record.wake_up_at,
        duration: record.duration,
        duration_hours: (record.duration / 3600.0).round(2),
        duration_formatted: format_duration(record.duration),
        created_at: record.created_at
      }
    end

    render json: {
      message: "Sleep records from friends in the previous week",
      friends_sleep_records: formatted_records,
      week_range: {
        start_date: previous_week_start.strftime("%Y-%m-%d"),
        end_date: previous_week_end.strftime("%Y-%m-%d")
      },
      pagination: {
        type: "traditional",
        current_page: friends_sleep_records.current_page,
        total_pages: friends_sleep_records.total_pages,
        total_count: friends_sleep_records.total_count,
        per_page: friends_sleep_records.limit_value
      },
      following_count: following_user_ids.size
    }
  end

  private

  def cursor_based_pagination(user, cursor, limit)
    query = SleepRecord.by_user(user).order(created_at: :desc)

    # Filter by cursor using id (since cursor is based on id of sleep records)
    if cursor.present?
      query = query.where("id < ?", cursor)
    end

    sleep_records = query.limit(limit + 1) # +1 to check if there are more records

    # Check if there are more records
    has_more = sleep_records.size > limit
    sleep_records = sleep_records.first(limit) if has_more

    # Next cursor is the id of the last record (pointer based on id)
    next_cursor = sleep_records.last&.id

    render json: {
      sleep_records: sleep_records,
      pagination: {
        type: "cursor",
        has_more: has_more,
        next_cursor: next_cursor,
        limit: limit
      }
    }
  end

  def traditional_pagination(user, page, limit)
    sleep_records = SleepRecord.by_user(user).order(created_at: :desc).page(page).per(limit)

    render json: {
      sleep_records: sleep_records,
      pagination: {
        type: "traditional",
        current_page: sleep_records.current_page,
        total_pages: sleep_records.total_pages,
        total_count: sleep_records.total_count,
        per_page: sleep_records.limit_value
      }
    }
  end

  def format_duration(duration_seconds)
    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    "#{hours}h #{minutes}m"
  end
end
