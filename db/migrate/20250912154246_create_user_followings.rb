class CreateUserFollowings < ActiveRecord::Migration[7.2]
  def change
    create_table :user_followings do |t|
      t.bigint :follower_id, null: false
      t.bigint :followed_id, null: false
      t.timestamps
    end

    # Index for finding who a user is following
    # Important: Optimizes queries like "show all users that John is following"
    # Query example: SELECT * FROM user_followings WHERE follower_id = ?
    add_index :user_followings, :follower_id

    # Index for finding who is following a user
    # Important: Optimizes queries like "show all users who follow John"
    # Query example: SELECT * FROM user_followings WHERE followed_id = ?
    add_index :user_followings, :followed_id

    # Unique compound index to prevent duplicate follows
    # Important: Ensures a user can't follow the same person multiple times
    # Also optimizes queries that check if user A follows user B
    # Query example: SELECT * FROM user_followings WHERE follower_id = ? AND followed_id = ?
    add_index :user_followings, [ :follower_id, :followed_id ], unique: true

    # Index for getting recent follows by follower with timestamp ordering
    # Important: Optimizes queries like "show recent people John started following"
    # Query example: SELECT * FROM user_followings WHERE follower_id = ? ORDER BY created_at DESC
    add_index :user_followings, [ :follower_id, :created_at ]
  end
end
