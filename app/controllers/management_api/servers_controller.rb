# frozen_string_literal: true

module ManagementApi
  class ServersController < BaseController

    before_action :set_organization, only: [:index, :create]
    before_action :set_server, only: [:show, :update, :destroy, :suspend, :unsuspend, :stats]

    # GET /api/v2/management/organizations/:organization_id/servers
    # GET /api/v2/management/servers
    def index
      authorize!(:servers, :read)

      scope = if @organization
        @organization.servers
      else
        current_api_key.accessible_servers
      end

      scope = scope.order(created_at: :desc)

      # Filtering
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?
      scope = scope.where(mode: api_params[:mode]) if api_params[:mode].present?

      result = paginate(scope)
      render_success(result[:records].map { |s| serialize_server(s) }, meta: result[:meta])
    end

    # GET /api/v2/management/servers/:id
    def show
      authorize!(:servers, :read)
      render_success(serialize_server(@server, detailed: true))
    end

    # POST /api/v2/management/organizations/:organization_id/servers
    def create
      authorize!(:servers, :write)

      server = @organization.servers.new(server_params)
      server.mode = api_params[:mode] || "Live"

      if server.save
        # Create default API credential
        if api_params[:create_api_credential] != false
          credential = server.credentials.create!(
            type: "API",
            name: "Default API Key"
          )
        end

        render_created(serialize_server(server, detailed: true, include_credentials: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create server",
            details: server.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/servers/:id
    def update
      authorize!(:servers, :write)

      if @server.update(server_params)
        render_success(serialize_server(@server, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update server",
            details: @server.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/servers/:id
    def destroy
      authorize!(:servers, :delete)

      @server.soft_destroy
      render_deleted
    end

    # POST /api/v2/management/servers/:id/suspend
    def suspend
      authorize!(:servers, :write)

      reason = api_params[:reason] || "Suspended via Management API"
      @server.suspend(reason)
      render_success(serialize_server(@server))
    end

    # POST /api/v2/management/servers/:id/unsuspend
    def unsuspend
      authorize!(:servers, :write)

      @server.unsuspend
      render_success(serialize_server(@server))
    end

    # GET /api/v2/management/servers/:id/stats
    def stats
      authorize!(:servers, :read)

      render_success({
        uuid: @server.uuid,
        name: @server.name,
        message_rate: @server.message_rate,
        queue_size: @server.queue_size,
        held_messages: @server.held_messages,
        throughput: @server.throughput_stats,
        bounce_rate: @server.bounce_rate,
        domain_stats: {
          total: @server.domain_stats[0],
          unverified: @server.domain_stats[1],
          bad_dns: @server.domain_stats[2]
        },
        send_limit: @server.send_limit,
        send_limit_approaching: @server.send_limit_approaching?,
        send_limit_exceeded: @server.send_limit_exceeded?
      })
    end

    private

    def set_organization
      return unless params[:organization_id]

      @organization = current_api_key.accessible_organizations.find_by!(permalink: params[:organization_id])
    rescue ActiveRecord::RecordNotFound
      @organization = current_api_key.accessible_organizations.find_by!(uuid: params[:organization_id])
    end

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:id])
    rescue ActiveRecord::RecordNotFound
      # Try by token
      @server = current_api_key.accessible_servers.find_by!(token: params[:id])
    end

    def server_params
      {
        name: api_params[:name],
        permalink: api_params[:permalink],
        mode: api_params[:mode],
        send_limit: api_params[:send_limit],
        allow_sender: api_params[:allow_sender],
        privacy_mode: api_params[:privacy_mode],
        raw_message_retention_days: api_params[:raw_message_retention_days],
        raw_message_retention_size: api_params[:raw_message_retention_size],
        message_retention_days: api_params[:message_retention_days],
        spam_threshold: api_params[:spam_threshold],
        spam_failure_threshold: api_params[:spam_failure_threshold],
        outbound_spam_threshold: api_params[:outbound_spam_threshold],
        postmaster_address: api_params[:postmaster_address],
        log_smtp_data: api_params[:log_smtp_data]
      }.compact
    end

    def serialize_server(server, detailed: false, include_credentials: false)
      data = {
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        token: server.token,
        mode: server.mode,
        status: server.status,
        suspended: server.suspended?,
        organization: {
          uuid: server.organization.uuid,
          permalink: server.organization.permalink
        },
        created_at: server.created_at&.iso8601,
        updated_at: server.updated_at&.iso8601
      }

      if detailed
        data.merge!(
          send_limit: server.send_limit,
          allow_sender: server.allow_sender,
          privacy_mode: server.privacy_mode,
          raw_message_retention_days: server.raw_message_retention_days,
          raw_message_retention_size: server.raw_message_retention_size,
          message_retention_days: server.message_retention_days,
          spam_threshold: server.spam_threshold&.to_f,
          spam_failure_threshold: server.spam_failure_threshold&.to_f,
          outbound_spam_threshold: server.outbound_spam_threshold&.to_f,
          postmaster_address: server.postmaster_address,
          log_smtp_data: server.log_smtp_data,
          domains_count: server.domains.count,
          credentials_count: server.credentials.count,
          routes_count: server.routes.count,
          webhooks_count: server.webhooks.count,
          suspension_reason: server.suspension_reason
        )
      end

      if include_credentials
        data[:credentials] = server.credentials.map do |c|
          { uuid: c.uuid, name: c.name, type: c.type, key: c.key }
        end
      end

      data
    end

  end
end
