class UserFollowingsController < ApplicationController
  before_action :find_follower_user, only: [ :follow, :unfollow ]
  before_action :find_followed_user, only: [ :follow, :unfollow ]

  # POST /users/:user_id/follow/:followed_user_id
  def follow
    if @follower_user.id == @followed_user.id
      render json: { error: "You cannot follow yourself" }, status: :unprocessable_entity
      return
    end

    # Check if already following
    existing_following = UserFollowing.find_by(follower_id: @follower_user.id, followed_id: @followed_user.id)
    if existing_following
      render json: { message: "Already following this user" }, status: :ok
      return
    end

    # Create new following relationship
    user_following = UserFollowing.new(follower_id: @follower_user.id, followed_id: @followed_user.id)

    if user_following.save
      # Clear cache for following user IDs
      UserFollowing.clear_following_cache(@follower_user.id)

      render json: { message: "Successfully followed user" }, status: :created
    else
      render json: {
        error: "Failed to follow user",
        details: user_following.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /users/:user_id/unfollow/:followed_user_id
  def unfollow
    user_following = UserFollowing.find_by(follower_id: @follower_user.id, followed_id: @followed_user.id)

    if user_following.nil?
      render json: { error: "You are not following this user" }, status: :not_found
      return
    end

    if user_following.destroy
      # Clear cache for following user IDs
      UserFollowing.clear_following_cache(@follower_user.id)

      render json: { message: "Successfully unfollowed user" }, status: :ok
    else
      render json: {
        error: "Failed to unfollow user",
        details: user_following.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def find_follower_user
    @follower_user = User.find_with_cache(params[:user_id])
    if @follower_user.nil?
      render json: { error: "Follower user not found" }, status: :not_found
      nil
    end
  end

  def find_followed_user
    @followed_user = User.find_with_cache(params[:followed_user_id])
    if @followed_user.nil?
      render json: { error: "User to follow not found" }, status: :not_found
      nil
    end
  end
end
