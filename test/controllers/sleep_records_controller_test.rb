require "test_helper"

class SleepRecordsControllerTest < ActionController::TestCase
  def setup
    @user = users(:one) # Using fixtures
    @friend = users(:two)
  end

  test "should get index with traditional pagination" do
    get :index, params: { user_id: @user.id, page: 1, limit: 10 }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "traditional", json_response["pagination"]["type"]
    assert json_response["sleep_records"].is_a?(Array)
    assert json_response["pagination"]["current_page"].present?

    # Assert sleep records content and ordering (newest first by created_at)
    sleep_records = json_response["sleep_records"]
    assert_equal 2, sleep_records.size # User "one" has 2 sleep records (fixtures "one" and "two")

    # Verify ordering by created_at desc - "two" is newer than "one"
    first_record = sleep_records[0]
    second_record = sleep_records[1]

    assert_equal sleep_records(:two).id, first_record["id"]
    assert_equal sleep_records(:one).id, second_record["id"]

    # Verify sleep record data structure
    assert first_record.key?("go_to_bed_at")
    assert first_record.key?("wake_up_at")
    assert first_record.key?("duration")
    assert first_record.key?("user_id")
    assert_equal @user.id, first_record["user_id"]
  end

  test "should get index with cursor pagination" do
    get :index, params: { user_id: @user.id, cursor: "123", limit: 10 }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "cursor", json_response["pagination"]["type"]
    assert json_response["sleep_records"].is_a?(Array)
    assert json_response["pagination"].key?("has_more")

    # Assert sleep records content with cursor filtering
    sleep_records = json_response["sleep_records"]

    # All returned records should have id < 123 (cursor filter)
    sleep_records.each do |record|
      assert record["id"] < 123, "Record ID #{record["id"]} should be less than cursor 123"
      assert_equal @user.id, record["user_id"]

      # Verify record structure
      assert record.key?("go_to_bed_at")
      assert record.key?("wake_up_at")
      assert record.key?("duration")
    end
  end

  test "should return 404 when user not found" do
    get :index, params: { user_id: 99999 }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]

    # Should not contain sleep_records key when error occurs
    assert_not json_response.key?("sleep_records")
  end

  test "should use default pagination parameters" do
    get :index, params: { user_id: @user.id }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "traditional", json_response["pagination"]["type"]

    # Assert default pagination values
    assert_equal 1, json_response["pagination"]["current_page"]
    assert_equal 10, json_response["pagination"]["per_page"]

    # Assert sleep records are returned with proper user isolation
    sleep_records = json_response["sleep_records"]
    sleep_records.each do |record|
      assert_equal @user.id, record["user_id"]
    end
  end

  test "should return sleep records for user two" do
    user_two = users(:two)
    get :index, params: { user_id: user_two.id }

    assert_response :success
    json_response = JSON.parse(response.body)

    # User "two" has 4 sleep records total (one current + three previous week records)
    sleep_records = json_response["sleep_records"]
    assert_equal 4, sleep_records.size

    # Verify all records belong to user two
    sleep_records.each do |record|
      assert_equal user_two.id, record["user_id"]
    end

    # Verify the most recent record is first (ordered by created_at desc)
    first_record = sleep_records[0]
    assert_equal sleep_records(:three).id, first_record["id"]
  end

  test "should return empty array for user with no sleep records" do
    # Create a new user without any sleep records
    new_user = User.create!(name: "User Without Sleep Records")
    get :index, params: { user_id: new_user.id }

    assert_response :success
    json_response = JSON.parse(response.body)

    # Should return empty array
    sleep_records = json_response["sleep_records"]
    assert_equal 0, sleep_records.size
    assert_equal [], sleep_records

    # Pagination should still work with empty data
    assert_equal "traditional", json_response["pagination"]["type"]
    assert_equal 1, json_response["pagination"]["current_page"]
    assert_equal 0, json_response["pagination"]["total_count"]
  end

  # Friends Sleep Records Tests
  test "should get friends sleep records with fixture data" do
    get :friends_sleep_records, params: { user_id: @user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "Sleep records from friends in the previous week", json_response["message"]
    assert_equal 2, json_response["friends_sleep_records"].size
    assert_equal 2, json_response["following_count"] # User one follows user two, but fixture shows 2 relationships

    # Should be sorted by duration descending (9h then 6h)
    records = json_response["friends_sleep_records"]
    assert_equal 9.0, records[0]["duration_hours"]
    assert_equal 6.0, records[1]["duration_hours"]

    # Verify user information
    records.each do |record|
      assert_equal @friend.id, record["user"]["id"]
      assert_equal @friend.name, record["user"]["name"]
    end
  end

  test "should return empty array when user follows no one" do
    # Create a user with no following relationships
    isolated_user = User.create!(name: "Isolated User")

    # Ensure no UserFollowing records exist for this user
    UserFollowing.where(follower: isolated_user).delete_all

    # Clear any potential cache for this user
    cache_key = "user:#{isolated_user.id}:following_ids"
    $redis.del(cache_key) if defined?($redis) && $redis

    # Also set an empty cache to ensure the method returns empty array
    $redis.setex(cache_key, 1800, [].to_json) if defined?($redis) && $redis

    get :friends_sleep_records, params: { user_id: isolated_user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "User is not following anyone", json_response["message"]
    assert_equal [], json_response["friends_sleep_records"]
    # following_count is not included in the response when user follows no one
    assert_nil json_response["following_count"]

    # Verify pagination structure
    assert_equal 0, json_response["pagination"]["total_count"]
    assert_equal 1, json_response["pagination"]["current_page"]
    assert_equal 0, json_response["pagination"]["total_pages"]
  end

  test "should handle pagination for friends sleep records" do
    get :friends_sleep_records, params: { user_id: @user.id, page: 1, limit: 1 }

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return only 1 record per page
    assert_equal 1, json_response["friends_sleep_records"].size
    assert_equal 2, json_response["pagination"]["total_count"]
    assert_equal 2, json_response["pagination"]["total_pages"]
    assert_equal 1, json_response["pagination"]["current_page"]
    assert_equal 1, json_response["pagination"]["per_page"]

    # Should get the longest duration first (9h)
    assert_equal 9.0, json_response["friends_sleep_records"][0]["duration_hours"]
  end

  test "should only include completed sleep records from friends" do
    get :friends_sleep_records, params: { user_id: @user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should only include completed records (not the incomplete_previous_week fixture)
    assert_equal 2, json_response["friends_sleep_records"].size

    # Verify none of the returned records have nil wake_up_at or duration
    json_response["friends_sleep_records"].each do |record|
      assert_not_nil record["wake_up_at"]
      assert_not_nil record["duration"]
      assert record["duration"] > 0
    end
  end

  test "should format duration correctly in friends sleep records" do
    get :friends_sleep_records, params: { user_id: @user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    records = json_response["friends_sleep_records"]

    # Verify duration formatting
    long_record = records.find { |r| r["duration_hours"] == 9.0 }
    short_record = records.find { |r| r["duration_hours"] == 6.0 }

    assert_equal "9h 0m", long_record["duration_formatted"]
    assert_equal "6h 0m", short_record["duration_formatted"]
  end

  test "should return 404 when user not found for friends sleep records" do
    get :friends_sleep_records, params: { user_id: 99999 }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]
  end

  test "should handle friends with no previous week sleep records" do
    # Create a user and friend relationship but no previous week sleep records
    user = User.create!(name: "Test User")
    friend = User.create!(name: "Test Friend")
    following = UserFollowing.create!(follower: user, followed: friend)

    # Clear any existing cache and ensure the relationship is properly cached
    user.clear_cache if user.respond_to?(:clear_cache)

    # Manually cache the following IDs to ensure the test works with Redis cache
    cache_key = "user:#{user.id}:following_ids"
    $redis.setex(cache_key, 1800, [friend.id].to_json) if defined?($redis) && $redis

    # Create a sleep record but not from previous week (this week instead)
    SleepRecord.create!(
      user: friend,
      go_to_bed_at: 1.day.ago,
      wake_up_at: 1.day.ago + 8.hours,
      duration: 8.hours.to_i,
      created_at: 1.day.ago
    )

    get :friends_sleep_records, params: { user_id: user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    # When user has friends but no previous week records, still shows the main message
    assert_equal "Sleep records from friends in the previous week", json_response["message"]
    assert_equal [], json_response["friends_sleep_records"]
    assert_equal 1, json_response["following_count"]
    assert_equal 0, json_response["pagination"]["total_count"]
  end

  test "should sort friends sleep records by duration descending" do
    # Create additional test data to verify sorting
    user = User.create!(name: "Sorting Test User")
    friend1 = User.create!(name: "Friend 1")
    friend2 = User.create!(name: "Friend 2")

    UserFollowing.create!(follower: user, followed: friend1)
    UserFollowing.create!(follower: user, followed: friend2)

    # Ensure we're using the exact same previous week range as the controller
    previous_week_start = 1.week.ago.beginning_of_week
    previous_week_end = 1.week.ago.end_of_week

    # Create records within the previous week range with different durations
    # Record 1: 5 hours sleep (should be second in sorted order)
    go_to_bed_1 = previous_week_start + 1.day + 22.hours  # Tuesday 10 PM
    wake_up_1 = go_to_bed_1 + 5.hours  # Wednesday 3 AM
    SleepRecord.create!(
      user: friend1,
      go_to_bed_at: go_to_bed_1,
      wake_up_at: wake_up_1,
      duration: 5.hours.to_i,
      created_at: go_to_bed_1
    )

    # Record 2: 8 hours sleep (should be first in sorted order)
    go_to_bed_2 = previous_week_start + 2.days + 22.hours  # Wednesday 10 PM
    wake_up_2 = go_to_bed_2 + 8.hours  # Thursday 6 AM
    SleepRecord.create!(
      user: friend2,
      go_to_bed_at: go_to_bed_2,
      wake_up_at: wake_up_2,
      duration: 8.hours.to_i,
      created_at: go_to_bed_2
    )

    # Cache the following relationships for the new user
    cache_key = "user:#{user.id}:following_ids"
    $redis.setex(cache_key, 1800, [friend1.id, friend2.id].to_json) if defined?($redis) && $redis

    get :friends_sleep_records, params: { user_id: user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    records = json_response["friends_sleep_records"]
    assert_equal 2, records.size

    # Should be sorted by duration descending (8h then 5h)
    assert_equal 8.0, records[0]["duration_hours"]
    assert_equal 5.0, records[1]["duration_hours"]
  end

  test "should handle invalid pagination parameters for friends sleep records" do
    # Test with negative page number
    get :friends_sleep_records, params: { user_id: @user.id, page: -1, limit: 10 }

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should default to page 1
    assert_equal 1, json_response["pagination"]["current_page"]
    assert json_response["friends_sleep_records"].is_a?(Array)
  end
end
