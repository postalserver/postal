# frozen_string_literal: true

module ManagementAPI
  class SystemController < BaseController

    skip_before_action :authenticate, only: [:health]

    # GET /api/v2/management/system/health
    def health
      render json: {
        status: "healthy",
        time: Time.current.iso8601,
        version: Postal.version
      }
    end

    # GET /api/v2/management/system/status
    def status
      authorize!(:system, :read)

      render_success({
        version: Postal.version,
        hostname: Socket.gethostname,
        time: Time.current.iso8601,
        database: check_database,
        queues: queue_stats,
        api_key: {
          name: current_api_key.name,
          super_admin: current_api_key.super_admin?,
          request_count: current_api_key.request_count
        }
      })
    end

    # GET /api/v2/management/system/stats
    def stats
      authorize!(:system, :read)
      require_super_admin!

      render_success({
        organizations: Organization.present.count,
        servers: Server.joins(:organization).where(organizations: { deleted_at: nil }).count,
        domains: Domain.count,
        users: User.count,
        credentials: Credential.count,
        queued_messages: QueuedMessage.count,
        api_keys: ManagementAPIKey.where(enabled: true).count
      })
    end

    # POST /api/v2/management/system/api_keys
    def create_api_key
      require_super_admin!

      api_key = ManagementAPIKey.new(
        name: api_params[:name],
        description: api_params[:description],
        super_admin: api_params[:super_admin] || false,
        permissions: api_params[:permissions],
        expires_at: api_params[:expires_at]
      )

      # Set organization scope if provided
      if api_params[:organization_permalink].present?
        org = Organization.find_by!(permalink: api_params[:organization_permalink])
        api_key.organization = org
      elsif api_params[:organization_uuid].present?
        org = Organization.find_by!(uuid: api_params[:organization_uuid])
        api_key.organization = org
      end

      if api_key.save
        render_created({
          uuid: api_key.uuid,
          name: api_key.name,
          key: api_key.key,
          description: api_key.description,
          super_admin: api_key.super_admin?,
          organization: api_key.organization ? { uuid: api_key.organization.uuid, permalink: api_key.organization.permalink } : nil,
          permissions: api_key.permissions,
          expires_at: api_key.expires_at&.iso8601,
          created_at: api_key.created_at&.iso8601
        })
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create API key",
            details: api_key.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # GET /api/v2/management/system/api_keys
    def list_api_keys
      require_super_admin!

      scope = ManagementAPIKey.order(created_at: :desc)
      scope = scope.where(enabled: true) if api_params[:enabled] == "true"
      scope = scope.where(enabled: false) if api_params[:enabled] == "false"

      result = paginate(scope)
      render_success(result[:records].map { |k| serialize_api_key(k) }, meta: result[:meta])
    end

    # DELETE /api/v2/management/system/api_keys/:id
    def destroy_api_key
      require_super_admin!

      api_key = ManagementAPIKey.find_by!(uuid: params[:id])

      if api_key == current_api_key
        render_error("CannotDeleteSelf", "Cannot delete the API key currently in use", 400)
        return
      end

      api_key.destroy
      render_deleted
    end

    private

    def check_database
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "connected" }
    rescue => e
      { status: "error", message: e.message }
    end

    def queue_stats
      {
        total: QueuedMessage.count,
        ready: QueuedMessage.ready.count,
        locked: QueuedMessage.where.not(locked_by: nil).count
      }
    rescue => e
      { error: e.message }
    end

    def serialize_api_key(key)
      {
        uuid: key.uuid,
        name: key.name,
        description: key.description,
        super_admin: key.super_admin?,
        enabled: key.enabled?,
        organization: key.organization ? { uuid: key.organization.uuid, permalink: key.organization.permalink } : nil,
        last_used_at: key.last_used_at&.iso8601,
        request_count: key.request_count,
        expires_at: key.expires_at&.iso8601,
        expired: key.expired?,
        created_at: key.created_at&.iso8601
      }
    end

  end
end
