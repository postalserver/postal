# frozen_string_literal: true

module ManagementAPI
  class UsersController < BaseController

    before_action :set_user, only: [:show, :update, :destroy]

    # GET /api/v2/management/users
    def index
      authorize!(:users, :read)
      require_super_admin!

      scope = User.order(created_at: :desc)

      # Filtering
      scope = scope.where("email_address LIKE ?", "%#{api_params[:email]}%") if api_params[:email].present?
      scope = scope.where("first_name LIKE ? OR last_name LIKE ?", "%#{api_params[:name]}%", "%#{api_params[:name]}%") if api_params[:name].present?
      scope = scope.where(admin: true) if api_params[:admin] == "true"

      result = paginate(scope)
      render_success(result[:records].map { |u| serialize_user(u) }, meta: result[:meta])
    end

    # GET /api/v2/management/users/:id
    def show
      authorize!(:users, :read)
      render_success(serialize_user(@user, detailed: true))
    end

    # POST /api/v2/management/users
    def create
      authorize!(:users, :write)
      require_super_admin!

      user = User.new(user_params)
      user.password = api_params[:password] if api_params[:password].present?

      if user.save
        render_created(serialize_user(user))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create user",
            details: user.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/users/:id
    def update
      authorize!(:users, :write)
      require_super_admin!

      params_to_update = user_params
      if api_params[:password].present?
        @user.password = api_params[:password]
      end

      if @user.update(params_to_update)
        render_success(serialize_user(@user))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update user",
            details: @user.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/users/:id
    def destroy
      authorize!(:users, :delete)
      require_super_admin!

      @user.destroy
      render_deleted
    end

    private

    def set_user
      @user = User.find_by!(uuid: params[:id])
    rescue ActiveRecord::RecordNotFound
      @user = User.find_by!(email_address: params[:id])
    end

    def user_params
      {
        first_name: api_params[:first_name],
        last_name: api_params[:last_name],
        email_address: api_params[:email_address],
        time_zone: api_params[:time_zone],
        admin: api_params[:admin]
      }.compact
    end

    def serialize_user(user, detailed: false)
      data = {
        uuid: user.uuid,
        email_address: user.email_address,
        first_name: user.first_name,
        last_name: user.last_name,
        name: user.name,
        admin: user.admin?,
        time_zone: user.time_zone,
        created_at: user.created_at&.iso8601,
        updated_at: user.updated_at&.iso8601
      }

      if detailed
        data.merge!(
          email_verified: user.email_verified_at.present?,
          email_verified_at: user.email_verified_at&.iso8601,
          oidc_enabled: user.oidc?,
          organizations: user.organizations.map { |o| { uuid: o.uuid, permalink: o.permalink, name: o.name } }
        )
      end

      data
    end

  end
end
