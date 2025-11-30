# frozen_string_literal: true

module ManagementAPI
  module V2
    class CredentialsController < BaseController

      before_action :find_server!
      before_action :check_server_access!
      before_action :find_credential!, only: [:show, :update, :destroy]

      # GET /api/v2/management/servers/:server_uuid/credentials
      def index
        credentials = @server.credentials
        credentials = filter_credentials(credentials)
        credentials = credentials.order(created_at: :desc)
        credentials, meta = paginate(credentials)

        render_success(
          credentials.map { |c| credential_json(c) },
          meta: meta
        )
      end

      # GET /api/v2/management/servers/:server_uuid/credentials/:uuid
      def show
        render_success(credential_json(@credential, detailed: true))
      end

      # POST /api/v2/management/servers/:server_uuid/credentials
      def create
        @credential = @server.credentials.new(credential_params)
        @credential.save!

        # Include the key in the response only on creation
        render_success(credential_json(@credential, include_key: true), status: :created)
      end

      # PATCH /api/v2/management/servers/:server_uuid/credentials/:uuid
      def update
        @credential.assign_attributes(credential_update_params)
        @credential.save!

        render_success(credential_json(@credential, detailed: true))
      end

      # DELETE /api/v2/management/servers/:server_uuid/credentials/:uuid
      def destroy
        @credential.destroy!
        render_success({ deleted: true, uuid: @credential.uuid })
      end

      private

      def find_credential!
        @credential = @server.credentials.find_by!(uuid: params[:uuid])
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def filter_credentials(scope)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(type: params[:type]) if params[:type].present?
        scope
      end

      def credential_params
        permitted = params.permit(:name, :type, :hold)

        # For SMTP-IP type, the key is the IP address
        if params[:type] == "SMTP-IP" && params[:ip_address].present?
          permitted[:key] = params[:ip_address]
        end

        permitted
      end

      def credential_update_params
        params.permit(:name, :hold)
      end

      def credential_json(credential, detailed: false, include_key: false)
        data = {
          uuid: credential.uuid,
          name: credential.name,
          type: credential.type,
          hold: credential.hold,
          last_used_at: credential.last_used_at&.iso8601,
          usage_type: credential.usage_type,
          created_at: credential.created_at.iso8601,
          updated_at: credential.updated_at.iso8601
        }

        # Include key for SMTP-IP (it's the IP address) or if explicitly requested
        if include_key || credential.type == "SMTP-IP"
          data[:key] = credential.key
        end

        if detailed && credential.type == "SMTP"
          data[:smtp_username] = credential.server.token
          data[:smtp_password] = credential.key
          data[:smtp_plain_auth] = credential.to_smtp_plain
        end

        data
      end

    end
  end
end
