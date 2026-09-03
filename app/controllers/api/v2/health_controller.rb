# frozen_string_literal: true

module API
  module V2
    class HealthController < BaseController

      def show
        require_scope!("usage:read")
        return if performed?

        render_data({ status: "ok" })
      end

      def server
        organization = scoped_organization!(params[:organization_uuid])
        return if performed? || organization.nil?

        require_scope!("usage:read")
        return if performed?

        server = organization.servers.present.find_by!(uuid: params[:uuid])
        total, unverified, bad_dns = server.domain_stats
        render_data({ status: server.suspended? ? "suspended" : "ok", queue_size: server.queue_size,
                      domains: { total: total, unverified: unverified, dns_errors: bad_dns }, rolling_send_limit: server.throughput_stats })
      end

    end
  end
end
