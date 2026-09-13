# frozen_string_literal: true

module API
  module V2
    class UsageController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid] || params[:uuid]) }
      before_action do
        @server = @organization&.servers&.present&.find_by!(uuid: params[:uuid]) if action_name == "server"
      end

      rescue_from ArgumentError do |exception|
        render_error("invalid_date_range", exception.message, status: :unprocessable_content)
      end

      def organization
        report
      end

      def server
        report
      end

      private

      def report
        require_scope!("usage:read")
        return if performed? || @organization.nil? || (action_name == "server" && @server.nil?)

        servers = @server ? [@server] : @organization.servers.present.where(suspended_at: nil).to_a
        data = ControlPlane::UsageReport.new(servers: servers,
                                             from: parse_time(:from, 30.days.ago), to: parse_time(:to, Time.current),
                                             granularity: params.fetch(:granularity, "daily")).call
        data[:bounce_rate] = data[:totals][:outgoing].positive? ? (data[:totals][:bounces] / data[:totals][:outgoing].to_f * 100).round(2) : 0
        data[:queue_size] = servers.sum(&:queue_size)
        data[:domains] = domain_health(servers)
        data[:quota] = quota_status
        render_data(data)
      end

      def parse_time(key, fallback)
        return fallback unless params[key].present?

        Time.iso8601(params[key])
      rescue ArgumentError
        raise ArgumentError, "#{key} must be an ISO-8601 timestamp"
      end

      def quota_status
        limit = @organization.monthly_outbound_limit
        accepted = UsageRollup.where(organization: @organization, server_id: 0, period_start: Time.current.utc.to_date.beginning_of_month,
                                     granularity: "monthly", metric: ControlPlane::OutboundQuota::METRIC).pick(:value).to_i
        { plan_code: @organization.plan_code, monthly_outbound_limit: limit, outbound_accepted_count: accepted,
          percent_used: limit ? (accepted / limit.to_f * 100).round(2) : nil, action: @organization.quota_action }
      end

      def domain_health(servers)
        total, unverified, dns_errors = servers.each_with_object([0, 0, 0]) do |server, values|
          server.domain_stats.each_with_index { |value, index| values[index] += value }
        end
        { total: total, unverified: unverified, dns_errors: dns_errors }
      end

    end
  end
end
