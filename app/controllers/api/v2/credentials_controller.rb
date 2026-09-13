# frozen_string_literal: true

module API
  module V2
    class CredentialsController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid]) }
      before_action { @server = @organization&.servers&.present&.find_by!(uuid: params[:server_uuid]) }
      before_action(only: :rotate) do
        @credential = @server&.credentials&.find_by!(uuid: params[:uuid])
      end
      before_action(only: :destroy) { @credential = @server&.credentials&.find_by(uuid: params[:uuid]) }

      def index
        require_scope!("servers:read")
        return if performed? || @server.nil?

        scope, meta = pagination_for(@server.credentials.order(:name))
        render_data(scope.map { |credential| serialize(credential) }, meta: meta)
      end

      def create
        require_scope!("credentials:write")
        return if performed? || @server.nil?

        with_idempotency do
          credential = @server.credentials.create!(credential_params)
          audit!(organization: @organization, resource: credential, action: "credential.created", after: serialize(credential))
          render_data(serialize(credential, include_secret: true), status: :created)
        end
      end

      def destroy
        require_scope!("credentials:write")
        return if performed? || @server.nil?

        with_idempotency do
          return render_error("not_found", "The requested resource could not be found", status: :not_found) unless @credential

          audit!(organization: @organization, resource: @credential, action: "credential.revoked", before: serialize(@credential))
          @credential.destroy!
          head :no_content
        end
      end

      def rotate
        require_scope!("credentials:write")
        return if performed? || @credential.nil?
        return render_error("credential_rotation_unsupported", "SMTP-IP credentials cannot be rotated", status: :unprocessable_content) if @credential.type == "SMTP-IP"

        with_idempotency do
          replacement = @server.credentials.create!(type: @credential.type, name: @credential.name, hold: @credential.hold, options: @credential.options)
          audit!(organization: @organization, resource: @credential, action: "credential.rotated", before: serialize(@credential), after: serialize(replacement))
          @credential.destroy!
          render_data(serialize(replacement, include_secret: true), status: :created)
        end
      end

      private

      def credential_params
        params.permit(:type, :name, :key, :hold)
      end

      def serialize(credential, include_secret: false)
        data = { uuid: credential.uuid, name: credential.name, type: credential.type, hold: credential.hold, last_used_at: credential.last_used_at,
                 key_hint: credential.key.present? ? "…#{credential.key.last(4)}" : nil, created_at: credential.created_at }
        data[:key] = credential.key if include_secret
        data
      end

    end
  end
end
