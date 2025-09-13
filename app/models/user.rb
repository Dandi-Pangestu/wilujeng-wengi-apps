class User < ApplicationRecord
  # Associations
  has_many :sleep_records, dependent: :destroy
  has_many :follower_relationships, class_name: "UserFollowing", foreign_key: "followed_id", dependent: :destroy
  has_many :following_relationships, class_name: "UserFollowing", foreign_key: "follower_id", dependent: :destroy
  has_many :followers, through: :follower_relationships, source: :follower
  has_many :following, through: :following_relationships, source: :followed

  # Validations
  validates :name, presence: true

  def self.find_with_cache(id)
    cache_key = "user:#{id}"
    cached_user = $redis.get(cache_key)

    if cached_user
      user_data = JSON.parse(cached_user)
      user = User.new(user_data)
      user.id = user_data["id"]
      user
    else
      user = find_by(id: id)
      if user
        $redis.setex(cache_key, 3600, user.to_json) # Cache for 1 hour
      end
      user
    end
  end

  def cache_user
    cache_key = "user:#{id}"
    $redis.setex(cache_key, 3600, self.to_json)
  end

  def clear_cache
    cache_key = "user:#{id}"
    $redis.del(cache_key)
  end

  # Cache following user IDs for performance
  def following_user_ids_with_cache
    cache_key = "user:#{id}:following_ids"
    cached_ids = $redis.get(cache_key)

    if cached_ids
      JSON.parse(cached_ids)
    else
      ids = UserFollowing.where(follower_id: id).pluck(:followed_id)
      $redis.setex(cache_key, 1800, ids.to_json) # Cache for 30 minutes
      ids
    end
  end

  # Callbacks to maintain cache
  after_update :cache_user
  after_destroy :clear_cache
end
