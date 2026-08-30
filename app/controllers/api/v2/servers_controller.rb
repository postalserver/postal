# frozen_string_literal: true

module API
  module V2
    class ServersController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid]) }
      before_action only: [:show, :update, :destroy, :suspend, :unsuspend] do
        @server = @organization&.servers&.present&.find_by!(uuid: params[:uuid])
      end

      rescue_from ControlPlane::ProvisionServer::ProvisioningError do
        render_error("provisioning_failed", "The mail server could not be provisioned", status: :unprocessable_content)
      end

      def index
        require_scope!("servers:read")
        return if performed? || @organization.nil?

        scope = @organization.servers.present.order(:created_at)
        records, meta = pagination_for(scope)
        render_data(records.map { |server| serialize(server) }, meta: meta.merge(total: scope.count))
      end

      def show
        require_scope!("servers:read")
        return if performed? || @server.nil?

        render_data(serialize(@server))
      end

      def create
        require_scope!("servers:write")
        return if performed? || @organization.nil?

        with_idempotency do
          server = ControlPlane::ProvisionServer.new(organization: @organization, attributes: server_params).call
          audit!(organization: @organization, resource: server, action: "server.created", after: serialize(server))
          render_data(serialize(server), status: :created)
        end
      end

      def update
        require_scope!("servers:write")
        return if performed? || @server.nil?

        before = serialize(@server)
        @server.update!(server_params)
        audit!(organization: @organization, resource: @server, action: "server.updated", before: before, after: serialize(@server))
        render_data(serialize(@server))
      end

      def destroy
        require_scope!("servers:write")
        return if performed? || @server.nil?

        @server.soft_destroy
        audit!(organization: @organization, resource: @server, action: "server.deleted")
        head :no_content
      end

      def suspend
        lifecycle(:suspend)
      end

      def unsuspend
        lifecycle(:unsuspend)
      end

      private

      def lifecycle(operation)
        require_scope!("servers:write")
        return if performed? || @server.nil?

        with_idempotency do
          before = serialize(@server)
          operation == :suspend ? @server.suspend(params[:reason].to_s) : @server.unsuspend
          audit!(organization: @organization, resource: @server, action: "server.#{operation}ed", before: before, after: serialize(@server))
          render_data(serialize(@server))
        end
      end

      def server_params
        params.permit(:name, :permalink, :mode, :send_limit, :message_retention_days, :raw_message_retention_days,
                      :raw_message_retention_size, :allow_sender, :privacy_mode, :postmaster_address)
      end

      def serialize(server)
        {
          uuid: server.uuid, name: server.name, permalink: server.permalink, mode: server.mode, status: server.status.downcase,
          suspension_reason: server.actual_suspension_reason, hourly_send_limit: server.send_limit,
          retention: { messages_days: server.message_retention_days, raw_messages_days: server.raw_message_retention_days, raw_message_size: server.raw_message_retention_size },
          tracking: { allow_sender: server.allow_sender, privacy_mode: server.privacy_mode }, created_at: server.created_at, updated_at: server.updated_at
        }
      end

    end
  end
end
