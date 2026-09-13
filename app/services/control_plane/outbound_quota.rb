# frozen_string_literal: true

module ControlPlane
  class OutboundQuota

    Decision = Struct.new(:action, :limit, :used, :requested, keyword_init: true) do
      def allow?
        action == :allow
      end

      def hold?
        action == :hold
      end

      def suspend?
        action == :suspend
      end
    end

    METRIC = "outbound_accepted"

    class << self

      def reserve!(server, count: 1)
        new(server, count).reserve!
      end

    end

    def initialize(server, count)
      @server = server
      @organization = server.organization
      @count = count.to_i
    end

    def reserve!
      raise ArgumentError, "count must be positive" unless @count.positive?

      @organization.with_lock do
        rollup = UsageRollup.lock.find_or_create_by!(organization: @organization, server_id: 0,
                                                     period_start: Time.current.utc.to_date.beginning_of_month,
                                                     granularity: "monthly", metric: METRIC)
        used = rollup.value
        limit = @organization.monthly_outbound_limit
        unless limit && used + @count > limit
          rollup.update!(value: used + @count)
          next Decision.new(action: :allow, limit: limit, used: used + @count, requested: @count)
        end

        case @organization.quota_action
        when "hold"
          rollup.update!(value: used + @count)
          Decision.new(action: :hold, limit: limit, used: used + @count, requested: @count)
        when "suspend"
          @organization.suspend("Monthly outbound quota of #{limit} reached") unless @organization.suspended?
          Decision.new(action: :suspend, limit: limit, used: used, requested: @count)
        else
          rollup.update!(value: used + @count)
          Decision.new(action: :allow, limit: limit, used: used + @count, requested: @count)
        end
      end
    end

  end
end
