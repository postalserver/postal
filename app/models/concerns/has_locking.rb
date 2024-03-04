# frozen_string_literal: true

# This concern provides functionality for locking items along with additional functionality to handle
# the concept of retrying items after a certain period of time. The following database columns are
# required on the model
#
# * locked_by - A string column to store the name of the process that has locked the item
# * locked_at - A datetime column to store the time the item was locked
# * retry_after - A datetime column to store the time after which the item should be retried
# * attempts - An integer column to store the number of attempts that have been made to process the item
#
# 'ready' means that it's ready to be processed.
module HasLocking

  extend ActiveSupport::Concern

  included do
    scope :unlocked, -> { where(locked_at: nil) }
    scope :ready, -> { where("retry_after IS NULL OR retry_after < ?", Time.now) }
  end

  def ready?
    retry_after.nil? || retry_after < Time.now
  end

  def unlock
    self.locked_by = nil
    self.locked_at = nil
    update_columns(locked_by: nil, locked_at: nil)
  end

  def locked?
    locked_at.present?
  end

  def retry_later(time = nil)
    retry_time = time || calculate_retry_time(attempts, 5.minutes)
    self.locked_by = nil
    self.locked_at = nil
    update_columns(locked_by: nil, locked_at: nil, retry_after: Time.now + retry_time, attempts: attempts + 1)
  end

  def calculate_retry_time(attempts, initial_period)
    (1.3**attempts) * initial_period
  end

end
