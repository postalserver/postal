# frozen_string_literal: true

# This initializer will wait for all pending migrations to be applied before
# continuing to start the application. This is useful when running the application
# in a cluster where migrations are run in a separate job which runs at the same
# time as the other processes.

class MigrationWaiter

  ATTEMPTS = Postal::Config.migration_waiter.attempts
  SLEEP_TIME = Postal::Config.migration_waiter.sleep_time

  class << self

    def wait
      attempts_remaining = ATTEMPTS
      loop do
        pending_migrations = ActiveRecord::Base.connection.migration_context.open.pending_migrations.size
        if pending_migrations.zero?
          Postal.logger.info "no pending migrations, continuing"
          return
        end

        attempts_remaining -= 1

        if attempts_remaining.zero?
          Postal.logger.info "#{pending_migrations} migration(s) are still pending after #{ATTEMPTS} attempts, exiting"
          Process.exit(1)
        else
          Postal.logger.info "waiting for #{pending_migrations} migration(s) to be applied (#{attempts_remaining} remaining)"
          sleep SLEEP_TIME
        end
      end
    end

    def wait_if_appropriate
      # Don't wait if not configured
      return unless Postal::Config.migration_waiter.enabled?

      # Don't wait in the console, rake tasks or rails commands
      return if console? || rake_task? || rails_command?

      wait
    end

    def console?
      Rails.const_defined?("Console")
    end

    def rake_task?
      Rake.application.top_level_tasks.any?
    end

    def rails_command?
      caller.any? { |c| c =~ /rails\/commands/ }
    end

  end

end
