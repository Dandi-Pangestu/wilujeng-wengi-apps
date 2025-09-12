class CreateSleepRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :sleep_records do |t|
      t.bigint :user_id, null: false
      t.datetime :go_to_bed_at
      t.datetime :wake_up_at
      t.bigint :duration
      t.timestamps
    end

    # Index for getting sleep records by user and ordering by created_at desc
    # Important: Optimizes queries like "show user's sleep history in chronological order"
    # Without this index, database would scan all records then sort - very slow for large datasets
    # Query example: SELECT * FROM sleep_records WHERE user_id = ? ORDER BY created_at DESC
    add_index :sleep_records, [ :user_id, :created_at ]

    # Index for getting sleep records by users, from previous week, and sorting by duration
    # Important: Enables fast date range queries with duration sorting for analytics
    # Covers compound queries: user filtering + date range filtering + duration sorting
    # Query example: SELECT * FROM sleep_records WHERE user_id = ? AND go_to_bed_at >= ? AND go_to_bed_at < ? ORDER BY duration DESC
    # Performance: Converts O(n) table scan to O(log n) index lookup
    add_index :sleep_records, [ :user_id, :go_to_bed_at, :duration ]
  end
end
