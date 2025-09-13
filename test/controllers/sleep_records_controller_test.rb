require "test_helper"

class SleepRecordsControllerTest < ActionController::TestCase
  def setup
    @user = users(:one) # Using fixtures
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

    # User "two" has only 1 sleep record (fixture "three")
    sleep_records = json_response["sleep_records"]
    assert_equal 1, sleep_records.size
    assert_equal sleep_records(:three).id, sleep_records[0]["id"]
    assert_equal user_two.id, sleep_records[0]["user_id"]
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
end
