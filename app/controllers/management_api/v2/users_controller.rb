# frozen_string_literal: true

module ManagementAPI
  module V2
    class UsersController < BaseController

      before_action :require_super_admin!
      before_action :find_user!, only: [:show, :update, :destroy]

      # GET /api/v2/management/users
      def index
        users = User.all
        users = filter_users(users)
        users = users.order(created_at: :desc)
        users, meta = paginate(users)

        render_success(
          users.map { |u| user_json(u) },
          meta: meta
        )
      end

      # GET /api/v2/management/users/:uuid
      def show
        render_success(user_json(@user, detailed: true))
      end

      # POST /api/v2/management/users
      def create
        @user = User.new(user_params)

        if params[:password].present?
          @user.password = params[:password]
        elsif !Postal::Config.oidc.enabled?
          render_error("PasswordRequired", "Password is required when OIDC is not enabled")
          return
        end

        @user.save!
        render_success(user_json(@user, detailed: true), status: :created)
      end

      # PATCH /api/v2/management/users/:uuid
      def update
        @user.assign_attributes(user_update_params)

        if params[:password].present?
          @user.password = params[:password]
        end

        @user.save!
        render_success(user_json(@user, detailed: true))
      end

      # DELETE /api/v2/management/users/:uuid
      def destroy
        # Check if user is owner of any organization
        owned_organizations = Organization.where(owner: @user).present
        if owned_organizations.any?
          render_error(
            "CannotDelete",
            "User is owner of #{owned_organizations.count} organization(s). Transfer ownership first.",
            details: { organizations: owned_organizations.pluck(:permalink) }
          )
          return
        end

        @user.destroy!
        render_success({ deleted: true, uuid: @user.uuid })
      end

      private

      def find_user!
        @user = User.find_by!(uuid: params[:uuid])
      end

      def filter_users(scope)
        scope = scope.where("email_address LIKE ?", "%#{params[:email]}%") if params[:email].present?
        scope = scope.where("first_name LIKE ? OR last_name LIKE ?", "%#{params[:name]}%", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(admin: true) if params[:admin] == "true"
        scope = scope.where(admin: false) if params[:admin] == "false"
        scope
      end

      def user_params
        params.permit(:first_name, :last_name, :email_address, :time_zone, :admin)
      end

      def user_update_params
        params.permit(:first_name, :last_name, :email_address, :time_zone, :admin)
      end

      def user_json(user, detailed: false)
        data = {
          uuid: user.uuid,
          email_address: user.email_address,
          first_name: user.first_name,
          last_name: user.last_name,
          name: user.name,
          admin: user.admin,
          time_zone: user.time_zone,
          has_password: user.password?,
          oidc_enabled: user.oidc?,
          created_at: user.created_at.iso8601,
          updated_at: user.updated_at.iso8601
        }

        if detailed
          data[:organizations] = user.organizations.present.map do |org|
            assignment = user.organization_users.find_by(organization: org)
            {
              uuid: org.uuid,
              permalink: org.permalink,
              name: org.name,
              admin: assignment&.admin,
              all_servers: assignment&.all_servers
            }
          end

          data[:owned_organizations] = Organization.where(owner: user).present.map do |org|
            {
              uuid: org.uuid,
              permalink: org.permalink,
              name: org.name
            }
          end
        end

        data
      end

    end
  end
end
