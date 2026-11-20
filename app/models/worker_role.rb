# frozen_string_literal: true

# == Schema Information
#
# Table name: worker_roles
#
#  id          :bigint           not null, primary key
#  acquired_at :datetime
#  role        :string(255)
#  worker      :string(255)
#
# Indexes
#
#  index_worker_roles_on_role  (role) UNIQUE
#
class WorkerRole < ApplicationRecord

  STALE_AFTER = 5.minutes

  class << self

    # Acquire or renew a lock for the given role.
    #
    # @param role [String] The name of the role to acquire
    # @param worker [String] The worker identity that should own the lock
    # @return [Symbol, false] True if the lock was acquired or renewed, false otherwise
    def acquire(role, worker: Postal.locker_name)
      # update our existing lock if we already have one
      updates = where(role: role, worker: worker).update_all(acquired_at: Time.current)
      return :renewed if updates.positive?

      # attempt to steal a role from another worker
      updates = where(role: role).where("acquired_at is null OR acquired_at < ?", STALE_AFTER.ago)
                                 .update_all(acquired_at: Time.current, worker: worker)
      return :stolen if updates.positive?

      # attempt to create a new role for this worker
      begin
        create!(role: role, worker: worker, acquired_at: Time.current)
        :created
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        false
      end
    rescue ActiveRecord::StatementInvalid
      false
    end

    # Refresh acquired_at so a long-running holder is not treated as stale.
    #
    # @param role [String]
    # @param worker [String]
    # @return [Boolean]
    def renew(role, worker: Postal.locker_name)
      where(role: role, worker: worker).update_all(acquired_at: Time.current).positive?
    rescue ActiveRecord::StatementInvalid
      false
    end

    # Release a lock for the given role for the current process.
    #
    # @param role [String] The name of the role to release
    # @param worker [String] The worker identity that owns the lock
    # @return [Boolean] True if the lock was released, false otherwise
    def release(role, worker: Postal.locker_name)
      updates = where(role: role, worker: worker).delete_all
      updates.positive?
    rescue ActiveRecord::StatementInvalid
      false
    end

  end

end
