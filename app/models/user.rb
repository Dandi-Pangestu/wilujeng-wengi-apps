class User < ApplicationRecord
  # Associations
  has_many :sleep_records, dependent: :destroy
  has_many :follower_relationships, class_name: "UserFollowing", foreign_key: "followed_id", dependent: :destroy
  has_many :following_relationships, class_name: "UserFollowing", foreign_key: "follower_id", dependent: :destroy
  has_many :followers, through: :follower_relationships, source: :follower
  has_many :following, through: :following_relationships, source: :followed

  # Validations
  validates :name, presence: true
end
