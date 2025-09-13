require "test_helper"

class ClockControllerTest < ActionController::TestCase
  def setup
    @user = users(:one)
  end

  # Clock In Tests
  test "should clock in successfully with automatic timestamp" do
    post :clock_in, params: { user_id: @user.id }

    assert_response :created
    json_response = JSON.parse(response.body)

    assert_equal "Clock in successful", json_response["message"]
    assert json_response["sleep_record"].present?

    sleep_record = json_response["sleep_record"]
    assert_equal @user.id, sleep_record["user_id"]
    assert sleep_record["go_to_bed_at"].present?
    assert_nil sleep_record["wake_up_at"]
    assert_nil sleep_record["duration"]
    assert sleep_record["created_at"].present?
  end

  test "should clock in successfully with manual timestamp" do
    manual_bedtime = 2.hours.ago.iso8601
    post :clock_in, params: { user_id: @user.id, go_to_bed_at: manual_bedtime }

    assert_response :created
    json_response = JSON.parse(response.body)

    assert_equal "Clock in successful", json_response["message"]
    sleep_record = json_response["sleep_record"]
    # Compare just the timestamp part, ignoring milliseconds
    assert_equal Time.parse(manual_bedtime).to_i, Time.parse(sleep_record["go_to_bed_at"]).to_i
  end

  test "should prevent duplicate clock in" do
    # Create an active session first
    SleepRecord.create!(user: @user, go_to_bed_at: 1.hour.ago)

    post :clock_in, params: { user_id: @user.id }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "User already has an active sleep session", json_response["error"]
    assert json_response["active_session"].present?
    assert json_response["active_session"]["id"].present?
    assert json_response["active_session"]["go_to_bed_at"].present?
  end

  test "should return 404 for clock in with non-existent user" do
    post :clock_in, params: { user_id: 99999 }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]
  end

  test "should reject future bedtime" do
    future_time = 1.hour.from_now.iso8601
    post :clock_in, params: { user_id: @user.id, go_to_bed_at: future_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid bedtime", json_response["error"]
    assert_equal "Bedtime cannot be in the future", json_response["message"]
  end

  test "should reject bedtime too old" do
    old_time = 31.days.ago.iso8601
    post :clock_in, params: { user_id: @user.id, go_to_bed_at: old_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid bedtime", json_response["error"]
    assert_equal "Bedtime cannot be more than 30 days ago", json_response["message"]
  end

  test "should reject invalid timestamp format for clock in" do
    post :clock_in, params: { user_id: @user.id, go_to_bed_at: "invalid-date" }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid timestamp format", json_response["error"]
    assert json_response["message"].include?("ISO 8601 format")
  end

  # Clock Out Tests
  test "should clock out successfully with automatic timestamp" do
    # Create an active session first
    active_session = SleepRecord.create!(user: @user, go_to_bed_at: 8.hours.ago)

    patch :clock_out, params: { user_id: @user.id }

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "Clock out successful - woke up!", json_response["message"]
    sleep_record = json_response["sleep_record"]
    assert_equal active_session.id, sleep_record["id"]
    assert_equal @user.id, sleep_record["user_id"]
    assert sleep_record["wake_up_at"].present?
    assert sleep_record["duration"].present?
    assert sleep_record["duration_hours"].present?
    assert sleep_record["updated_at"].present?
  end

  test "should clock out successfully with manual timestamp" do
    bedtime = 8.hours.ago
    wake_time = 1.hour.ago
    active_session = SleepRecord.create!(user: @user, go_to_bed_at: bedtime)

    patch :clock_out, params: { user_id: @user.id, wake_up_at: wake_time.iso8601 }

    assert_response :ok
    json_response = JSON.parse(response.body)

    sleep_record = json_response["sleep_record"]
    # Compare timestamps by converting to seconds to avoid millisecond precision issues
    assert_equal wake_time.to_i, Time.parse(sleep_record["wake_up_at"]).to_i
    assert sleep_record["duration"].present?
    assert sleep_record["duration_hours"].present?
  end

  test "should return error when no active session for clock out" do
    patch :clock_out, params: { user_id: @user.id }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "No active sleep session found", json_response["error"]
    assert_equal "User needs to clock in first", json_response["message"]
  end

  test "should return 404 for clock out with non-existent user" do
    patch :clock_out, params: { user_id: 99999 }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "User not found", json_response["error"]
  end

  test "should reject future wake up time" do
    SleepRecord.create!(user: @user, go_to_bed_at: 8.hours.ago)
    future_time = 1.hour.from_now.iso8601

    patch :clock_out, params: { user_id: @user.id, wake_up_at: future_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid wake up time", json_response["error"]
    assert_equal "Wake up time cannot be in the future", json_response["message"]
  end

  test "should reject wake up time before bedtime" do
    bedtime = 2.hours.ago
    SleepRecord.create!(user: @user, go_to_bed_at: bedtime)
    early_time = 3.hours.ago.iso8601

    patch :clock_out, params: { user_id: @user.id, wake_up_at: early_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid wake up time", json_response["error"]
    assert json_response["message"].include?("Wake up time must be after bedtime")
  end

  test "should reject sleep duration exceeding 24 hours" do
    bedtime = 25.hours.ago
    SleepRecord.create!(user: @user, go_to_bed_at: bedtime)
    wake_time = 30.minutes.ago.iso8601  # This will be exactly > 24 hours

    patch :clock_out, params: { user_id: @user.id, wake_up_at: wake_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid wake up time", json_response["error"]
    assert_equal "Sleep duration cannot exceed 24 hours", json_response["message"]
  end

  test "should reject sleep duration less than 1 minute" do
    bedtime = 30.seconds.ago
    SleepRecord.create!(user: @user, go_to_bed_at: bedtime)
    wake_time = Time.current.iso8601

    patch :clock_out, params: { user_id: @user.id, wake_up_at: wake_time }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid wake up time", json_response["error"]
    assert_equal "Sleep duration must be at least 1 minute", json_response["message"]
  end

  test "should reject invalid timestamp format for clock out" do
    SleepRecord.create!(user: @user, go_to_bed_at: 8.hours.ago)

    patch :clock_out, params: { user_id: @user.id, wake_up_at: "invalid-date" }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid timestamp format", json_response["error"]
    assert json_response["message"].include?("ISO 8601 format")
  end
end
