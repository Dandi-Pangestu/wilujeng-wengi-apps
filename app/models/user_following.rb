class UserFollowing < ApplicationRecord
  # Associations
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"

  # Validations
  validates :follower_id, presence: true
  validates :followed_id, presence: true
  validates :follower_id, uniqueness: { scope: :followed_id }

  def self.clear_following_cache(user_id)
    cache_key = "user:#{user_id}:following_ids"
    $redis.del(cache_key) if defined?($redis) && $redis
  end
end
