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

  class << self

    # Acquire or renew a lock for the given role.
    #
    # @param role [String] The name of the role to acquire
    # @return [Symbol, false] True if the lock was acquired or renewed, false otherwise
    def acquire(role)
      # update our existing lock if we already have one
      updates = where(role: role, worker: Postal.locker_name).update_all(acquired_at: Time.current)
      return :renewed if updates.positive?

      # attempt to steal a role from another worker
      updates = where(role: role).where("acquired_at is null OR acquired_at < ?", 5.minutes.ago)
                                 .update_all(acquired_at: Time.current, worker: Postal.locker_name)
      return :stolen if updates.positive?

      # attempt to create a new role for this worker
      begin
        create!(role: role, worker: Postal.locker_name, acquired_at: Time.current)
        :created
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        false
      end
    end

    # Release a lock for the given role for the current process.
    #
    # @param role [String] The name of the role to release
    # @return [Boolean] True if the lock was released, false otherwise
    def release(role)
      updates = where(role: role, worker: Postal.locker_name).delete_all
      updates.positive?
    end

  end

end
