class AddMissingIndexesToSleepRecords < ActiveRecord::Migration[7.2]
  def change
    # Partial index for finding active sleep sessions (clock_in/clock_out operations)
    # Important: Optimizes queries like "find user's active session where wake_up_at is NULL"
    # Query example: SELECT * FROM sleep_records WHERE user_id = ? AND wake_up_at IS NULL LIMIT 1
    # This is used in both clock_in and clock_out endpoints to check for active sessions
    # Partial index is much smaller and faster since it only indexes records where wake_up_at IS NULL
    add_index :sleep_records, :user_id, where: "wake_up_at IS NULL", name: "index_sleep_records_on_user_id_where_active"
  end
end
