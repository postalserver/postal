# frozen_string_literal: true

module ManagementAPI
  module V2
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
        render_success({
          version: Postal.version,
          hostname: Socket.gethostname,
          authenticated_as: {
            uuid: current_api_key.uuid,
            name: current_api_key.name,
            super_admin: current_api_key.super_admin
          },
          database_connected: ActiveRecord::Base.connected?,
          time: Time.current.iso8601
        })
      end

      # GET /api/v2/management/system/stats
      def stats
        require_super_admin!
        return if performed?

        stats_data = {
          organizations: {
            total: Organization.present.count,
            suspended: Organization.present.where.not(suspended_at: nil).count
          },
          servers: {
            total: Server.present.count,
            suspended: Server.present.where.not(suspended_at: nil).count,
            by_mode: Server.present.group(:mode).count
          },
          users: {
            total: User.count,
            admins: User.where(admin: true).count
          },
          messages: {
            queued: QueuedMessage.count,
            held: count_held_messages
          },
          management_api_keys: {
            total: ManagementAPIKey.count,
            enabled: ManagementAPIKey.enabled.count,
            super_admin: ManagementAPIKey.super_admin.count
          }
        }

        render_success(stats_data)
      end

      # GET /api/v2/management/system/api_keys
      def api_keys_index
        require_super_admin!
        return if performed?

        keys = ManagementAPIKey.order(created_at: :desc)
        keys, meta = paginate(keys)

        render_success(
          keys.map { |k| k.as_json_for_api },
          meta: meta
        )
      end

      # POST /api/v2/management/system/api_keys
      def api_keys_create
        require_super_admin!
        return if performed?

        key = ManagementAPIKey.new(api_key_params)

        if params[:organization_permalink].present?
          org = Organization.find_by!(permalink: params[:organization_permalink])
          key.organization = org
        end

        key.save!

        render_success(key.as_json_for_api(include_key: true), status: :created)
      end

      # DELETE /api/v2/management/system/api_keys/:uuid
      def api_keys_destroy
        require_super_admin!
        return if performed?

        key = ManagementAPIKey.find_by!(uuid: params[:uuid])

        if key.id == current_api_key.id
          render_error("CannotDeleteSelf", "Cannot delete the API key currently being used")
          return
        end

        key.destroy!
        render_success({ deleted: true })
      end

      private

      def api_key_params
        params.permit(:name, :description, :super_admin, :enabled, :expires_at)
      end

      def count_held_messages
        total = 0
        Server.present.find_each do |server|
          total += server.message_db.messages(where: { held: true }, count: true)
        rescue StandardError
          # Skip servers with database issues
        end
        total
      end

    end
  end
end
