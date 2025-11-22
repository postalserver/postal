# frozen_string_literal: true

module ManagementApi
  class CredentialsController < BaseController

    before_action :set_server
    before_action :set_credential, only: [:show, :update, :destroy]

    # GET /api/v2/management/servers/:server_id/credentials
    def index
      authorize!(:credentials, :read)

      scope = @server.credentials.order(created_at: :desc)

      # Filtering
      scope = scope.where(type: api_params[:type]) if api_params[:type].present?
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?

      result = paginate(scope)
      render_success(result[:records].map { |c| serialize_credential(c) }, meta: result[:meta])
    end

    # GET /api/v2/management/servers/:server_id/credentials/:id
    def show
      authorize!(:credentials, :read)
      render_success(serialize_credential(@credential, detailed: true))
    end

    # POST /api/v2/management/servers/:server_id/credentials
    def create
      authorize!(:credentials, :write)

      credential = @server.credentials.new(credential_params)

      if credential.save
        render_created(serialize_credential(credential, detailed: true, show_key: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create credential",
            details: credential.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/servers/:server_id/credentials/:id
    def update
      authorize!(:credentials, :write)

      update_params = { name: api_params[:name], hold: api_params[:hold] }.compact

      if @credential.update(update_params)
        render_success(serialize_credential(@credential, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update credential",
            details: @credential.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/servers/:server_id/credentials/:id
    def destroy
      authorize!(:credentials, :delete)

      @credential.destroy
      render_deleted
    end

    private

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:server_id])
    rescue ActiveRecord::RecordNotFound
      @server = current_api_key.accessible_servers.find_by!(token: params[:server_id])
    end

    def set_credential
      @credential = @server.credentials.find_by!(uuid: params[:id])
    end

    def credential_params
      params_hash = {
        name: api_params[:name],
        type: api_params[:type] || "API",
        hold: api_params[:hold]
      }

      # For SMTP-IP type, key is the IP address
      if api_params[:type] == "SMTP-IP"
        params_hash[:key] = api_params[:ip_address]
      end

      params_hash.compact
    end

    def serialize_credential(credential, detailed: false, show_key: false)
      data = {
        uuid: credential.uuid,
        name: credential.name,
        type: credential.type,
        hold: credential.hold,
        usage_type: credential.usage_type,
        last_used_at: credential.last_used_at&.iso8601,
        created_at: credential.created_at&.iso8601,
        updated_at: credential.updated_at&.iso8601
      }

      # Only show key on creation or when explicitly requested
      if show_key || detailed
        data[:key] = credential.key
      end

      if detailed && credential.type == "API"
        data[:smtp_plain] = credential.to_smtp_plain
      end

      data
    end

  end
end
