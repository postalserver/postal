# frozen_string_literal: true

module ManagementAPI
  module V2
    class ServersController < BaseController

      # GET /api/v2/management/servers
      # GET /api/v2/management/organizations/:org_permalink/servers
      def index
        if params[:org_permalink].present?
          find_organization!
          servers = @organization.servers.present
        else
          servers = accessible_servers.present
        end

        servers = filter_servers(servers)
        servers = servers.includes(:organization).order(created_at: :desc)
        servers, meta = paginate(servers)

        render_success(
          servers.map { |s| server_json(s) },
          meta: meta
        )
      end

      # GET /api/v2/management/servers/:uuid
      def show
        find_server!(:uuid)
        render_success(server_json(@server, detailed: true))
      end

      # POST /api/v2/management/organizations/:org_permalink/servers
      def create
        find_organization!

        @server = @organization.servers.new(server_params)
        @server.save!

        # Create default API credential if requested
        credentials = []
        if params[:create_api_credential] == true || params[:create_api_credential] == "true"
          credential = @server.credentials.create!(
            name: "Default API Key",
            type: "API"
          )
          credentials << credential_json(credential, include_key: true)
        end

        response = server_json(@server, detailed: true)
        response[:credentials] = credentials if credentials.any?

        render_success(response, status: :created)
      end

      # PATCH /api/v2/management/servers/:uuid
      def update
        find_server!(:uuid)
        check_server_access!
        return if performed?

        @server.assign_attributes(server_update_params)
        @server.save!

        render_success(server_json(@server, detailed: true))
      end

      # DELETE /api/v2/management/servers/:uuid
      def destroy
        find_server!(:uuid)
        check_server_access!
        return if performed?

        @server.soft_destroy
        render_success({ deleted: true, uuid: @server.uuid })
      end

      # POST /api/v2/management/servers/:uuid/suspend
      def suspend
        require_super_admin!
        return if performed?

        find_server!(:uuid)

        if @server.suspended_at.present?
          render_error("AlreadySuspended", "Server is already suspended")
          return
        end

        @server.suspend(params[:reason] || "Suspended via Management API")
        render_success(server_json(@server, detailed: true))
      end

      # POST /api/v2/management/servers/:uuid/unsuspend
      def unsuspend
        require_super_admin!
        return if performed?

        find_server!(:uuid)

        if @server.suspended_at.nil?
          render_error("NotSuspended", "Server is not suspended")
          return
        end

        @server.unsuspend
        render_success(server_json(@server, detailed: true))
      end

      # GET /api/v2/management/servers/:uuid/stats
      def stats
        find_server!(:uuid)
        check_server_access!
        return if performed?

        domain_total, domain_unverified, domain_bad_dns = @server.domain_stats

        stats_data = {
          uuid: @server.uuid,
          name: @server.name,
          message_rate: @server.message_rate.round(2),
          queue_size: @server.queue_size,
          held_messages: @server.held_messages,
          throughput: {
            incoming: @server.throughput_stats[:incoming],
            outgoing: @server.throughput_stats[:outgoing],
            outgoing_usage: @server.throughput_stats[:outgoing_usage].round(2)
          },
          bounce_rate: @server.bounce_rate.round(2),
          domain_stats: {
            total: domain_total,
            unverified: domain_unverified,
            bad_dns: domain_bad_dns
          },
          send_limit: @server.send_limit,
          send_limit_approaching: @server.send_limit_approaching?,
          send_limit_exceeded: @server.send_limit_exceeded?
        }

        render_success(stats_data)
      end

      private

      def accessible_servers
        if current_api_key.super_admin?
          Server.all
        else
          Server.where(organization: current_api_key.accessible_organizations)
        end
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def filter_servers(scope)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(mode: params[:mode]) if params[:mode].present?
        scope
      end

      def server_params
        params.permit(
          :name, :mode, :send_limit, :message_retention_days,
          :raw_message_retention_days, :raw_message_retention_size,
          :allow_sender, :spam_threshold, :spam_failure_threshold,
          :postmaster_address, :log_smtp_data, :outbound_spam_threshold
        )
      end

      def server_update_params
        params.permit(
          :name, :send_limit, :message_retention_days,
          :raw_message_retention_days, :raw_message_retention_size,
          :allow_sender, :spam_threshold, :spam_failure_threshold,
          :postmaster_address, :log_smtp_data, :outbound_spam_threshold
        )
      end

      def server_json(server, detailed: false)
        data = {
          uuid: server.uuid,
          name: server.name,
          permalink: server.permalink,
          token: server.token,
          mode: server.mode,
          status: server.status,
          suspended: server.suspended?,
          suspension_reason: server.actual_suspension_reason,
          organization: {
            uuid: server.organization.uuid,
            permalink: server.organization.permalink,
            name: server.organization.name
          },
          send_limit: server.send_limit,
          created_at: server.created_at.iso8601,
          updated_at: server.updated_at.iso8601
        }

        if detailed
          data[:settings] = {
            message_retention_days: server.message_retention_days,
            raw_message_retention_days: server.raw_message_retention_days,
            raw_message_retention_size: server.raw_message_retention_size,
            allow_sender: server.allow_sender,
            spam_threshold: server.spam_threshold&.to_f,
            spam_failure_threshold: server.spam_failure_threshold&.to_f,
            outbound_spam_threshold: server.outbound_spam_threshold&.to_f,
            postmaster_address: server.postmaster_address,
            log_smtp_data: server.log_smtp_data
          }
          data[:stats] = {
            domains: server.domains.count,
            credentials: server.credentials.count,
            routes: server.routes.count,
            webhooks: server.webhooks.count
          }
        end

        data
      end

      def credential_json(credential, include_key: false)
        data = {
          uuid: credential.uuid,
          name: credential.name,
          type: credential.type,
          created_at: credential.created_at.iso8601
        }
        data[:key] = credential.key if include_key
        data
      end

    end
  end
end
