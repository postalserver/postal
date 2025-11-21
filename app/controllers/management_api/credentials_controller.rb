# frozen_string_literal: true

module ManagementAPI
  class CredentialsController < BaseController

    # GET /management/api/v1/servers/:server_id/credentials
    # List all credentials for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "credentials": [
    #       { "uuid": "xxx", "name": "API", "type": "API", "key": "...", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      render_success(
        server: server.full_permalink,
        credentials: server.credentials.map { |c| credential_to_hash(c) }
      )
    end

    # GET /management/api/v1/servers/:server_id/credentials/:id
    # Get a specific credential
    def show
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      credential = server.credentials.find_by!(uuid: params[:id])

      render_success(credential: credential_to_hash(credential))
    end

    # POST /management/api/v1/servers/:server_id/credentials
    # Create a new credential
    #
    # Required params:
    #   name - credential name
    #   type - "API", "SMTP", or "SMTP-IP"
    #
    # Optional params:
    #   key - required for SMTP-IP type (IP address)
    #   hold - if true, messages will be held (default: false)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "credential": {
    #       "uuid": "xxx",
    #       "name": "API Key",
    #       "type": "API",
    #       "key": "generated-api-key-here",
    #       ...
    #     }
    #   }
    # }
    def create
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      credential = server.credentials.create!(
        name: api_params[:name],
        type: api_params[:type],
        key: api_params[:key], # Only used for SMTP-IP type
        hold: api_params[:hold] || false
      )

      render_success(
        credential: credential_to_hash(credential),
        message: "Credential created. Use the key for authentication."
      )
    end

    # PATCH /management/api/v1/servers/:server_id/credentials/:id
    # Update a credential
    #
    # Params:
    #   name - credential name
    #   hold - if true, messages will be held
    def update
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      credential = server.credentials.find_by!(uuid: params[:id])

      update_params = {}
      update_params[:name] = api_params[:name] if api_params[:name].present?
      update_params[:hold] = api_params[:hold] if api_params.key?(:hold)

      credential.update!(update_params)

      render_success(credential: credential_to_hash(credential))
    end

    # DELETE /management/api/v1/servers/:server_id/credentials/:id
    # Delete a credential
    def destroy
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      credential = server.credentials.find_by!(uuid: params[:id])
      credential.destroy!

      render_success(message: "Credential '#{credential.name}' has been deleted")
    end

    private

    def credential_to_hash(credential)
      {
        uuid: credential.uuid,
        name: credential.name,
        type: credential.type,
        key: credential.key,
        hold: credential.hold?,
        last_used_at: credential.last_used_at,
        usage_type: credential.usage_type,
        created_at: credential.created_at,
        updated_at: credential.updated_at
      }
    end

  end
end
