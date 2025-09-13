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
end
