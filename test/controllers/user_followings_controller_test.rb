require "test_helper"

class UserFollowingsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user1 = User.create!(name: "User One")
    @user2 = User.create!(name: "User Two")
    @user3 = User.create!(name: "User Three")
  end

  test "should follow another user successfully" do
    post "/users/#{@user1.id}/follow/#{@user2.id}"

    assert_response :created
    json_response = JSON.parse(response.body)

    assert_equal "Successfully followed user", json_response["message"]

    # Verify relationship was created in database
    assert UserFollowing.exists?(follower: @user1, followed: @user2)
  end

  test "should return error when trying to follow yourself" do
    post "/users/#{@user1.id}/follow/#{@user1.id}"

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_equal "You cannot follow yourself", json_response["error"]

    # Verify no relationship was created
    assert_not UserFollowing.exists?(follower: @user1, followed: @user1)
  end

  test "should return message when already following user" do
    # Create existing following relationship
    UserFollowing.create!(follower: @user1, followed: @user2)

    post "/users/#{@user1.id}/follow/#{@user2.id}"

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "Already following this user", json_response["message"]
  end

  test "should return error when follower user not found" do
    post "/users/99999/follow/#{@user2.id}"

    assert_response :not_found
    json_response = JSON.parse(response.body)

    assert_equal "Follower user not found", json_response["error"]
  end

  test "should return error when followed user not found" do
    post "/users/#{@user1.id}/follow/99999"

    assert_response :not_found
    json_response = JSON.parse(response.body)

    assert_equal "User to follow not found", json_response["error"]
  end

  test "should unfollow user successfully" do
    # Create existing following relationship
    UserFollowing.create!(follower: @user1, followed: @user2)

    delete "/users/#{@user1.id}/unfollow/#{@user2.id}"

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "Successfully unfollowed user", json_response["message"]

    # Verify relationship was removed from database
    assert_not UserFollowing.exists?(follower: @user1, followed: @user2)
  end

  test "should return error when trying to unfollow user not being followed" do
    delete "/users/#{@user1.id}/unfollow/#{@user2.id}"

    assert_response :not_found
    json_response = JSON.parse(response.body)

    assert_equal "You are not following this user", json_response["error"]
  end

  test "should return error when unfollowing with invalid follower user" do
    delete "/users/99999/unfollow/#{@user2.id}"

    assert_response :not_found
    json_response = JSON.parse(response.body)

    assert_equal "Follower user not found", json_response["error"]
  end

  test "should return error when unfollowing with invalid followed user" do
    delete "/users/#{@user1.id}/unfollow/99999"

    assert_response :not_found
    json_response = JSON.parse(response.body)

    assert_equal "User to follow not found", json_response["error"]
  end

  test "should clear cache when following user" do
    # Mock Redis if available
    if defined?($redis) && $redis
      cache_key = "user:#{@user1.id}:following_ids"

      # Set some cache data
      $redis.setex(cache_key, 1800, [].to_json)
      assert_equal 1, $redis.exists(cache_key)

      post "/users/#{@user1.id}/follow/#{@user2.id}"

      assert_response :created
      # Cache should be cleared after following
      assert_equal 0, $redis.exists(cache_key)
    end
  end

  test "should clear cache when unfollowing user" do
    # Create following relationship
    UserFollowing.create!(follower: @user1, followed: @user2)

    # Mock Redis if available
    if defined?($redis) && $redis
      cache_key = "user:#{@user1.id}:following_ids"

      # Set some cache data
      $redis.setex(cache_key, 1800, [@user2.id].to_json)
      assert_equal 1, $redis.exists(cache_key)

      delete "/users/#{@user1.id}/unfollow/#{@user2.id}"

      assert_response :ok
      # Cache should be cleared after unfollowing
      assert_equal 0, $redis.exists(cache_key)
    end
  end

  test "should maintain following relationships integrity" do
    # User1 follows User2
    post "/users/#{@user1.id}/follow/#{@user2.id}"
    assert_response :created

    # User2 follows User3
    post "/users/#{@user2.id}/follow/#{@user3.id}"
    assert_response :created

    # User3 follows User1 (circular following)
    post "/users/#{@user3.id}/follow/#{@user1.id}"
    assert_response :created

    # Verify all relationships exist
    assert UserFollowing.exists?(follower: @user1, followed: @user2)
    assert UserFollowing.exists?(follower: @user2, followed: @user3)
    assert UserFollowing.exists?(follower: @user3, followed: @user1)

    # Unfollow one relationship
    delete "/users/#{@user1.id}/unfollow/#{@user2.id}"
    assert_response :ok

    # Verify only the targeted relationship was removed
    assert_not UserFollowing.exists?(follower: @user1, followed: @user2)
    assert UserFollowing.exists?(follower: @user2, followed: @user3)
    assert UserFollowing.exists?(follower: @user3, followed: @user1)
  end
end
