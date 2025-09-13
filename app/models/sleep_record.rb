class SleepRecord < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :user_id, presence: true
  validates :go_to_bed_at, presence: true
  validates :wake_up_at, presence: true, allow_nil: true
  validates :duration, presence: true, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :active_sessions, -> { where(wake_up_at: nil) }
end
