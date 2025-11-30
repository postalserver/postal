# frozen_string_literal: true

module ManagementAPI
  module V2
    class OrganizationsController < BaseController

      # GET /api/v2/management/organizations
      def index
        organizations = current_api_key.accessible_organizations.present
        organizations = filter_organizations(organizations)
        organizations = organizations.order(created_at: :desc)

        organizations, meta = paginate(organizations)

        render_success(
          organizations.map { |o| organization_json(o) },
          meta: meta
        )
      end

      # GET /api/v2/management/organizations/:permalink
      def show
        find_organization!(:permalink)
        render_success(organization_json(@organization, detailed: true))
      end

      # POST /api/v2/management/organizations
      def create
        require_super_admin!
        return if performed?

        @organization = Organization.new(organization_params)

        if params[:owner_email].present?
          owner = User.find_by(email_address: params[:owner_email])
          if owner.nil?
            render_error("OwnerNotFound", "User with email #{params[:owner_email]} not found", status: :not_found)
            return
          end
          @organization.owner = owner
        else
          render_error("OwnerRequired", "owner_email is required when creating an organization")
          return
        end

        @organization.save!

        # Add owner to organization users
        @organization.organization_users.create!(user: @organization.owner, admin: true, all_servers: true)

        render_success(organization_json(@organization, detailed: true), status: :created)
      end

      # PATCH /api/v2/management/organizations/:permalink
      def update
        find_organization!(:permalink)

        @organization.assign_attributes(organization_update_params)
        @organization.save!

        render_success(organization_json(@organization, detailed: true))
      end

      # DELETE /api/v2/management/organizations/:permalink
      def destroy
        require_super_admin!
        return if performed?

        find_organization!(:permalink)

        @organization.soft_destroy
        render_success({ deleted: true, permalink: @organization.permalink })
      end

      # POST /api/v2/management/organizations/:permalink/suspend
      def suspend
        require_super_admin!
        return if performed?

        find_organization!(:permalink)

        if @organization.suspended?
          render_error("AlreadySuspended", "Organization is already suspended")
          return
        end

        @organization.suspended_at = Time.current
        @organization.suspension_reason = params[:reason]
        @organization.save!

        render_success(organization_json(@organization, detailed: true))
      end

      # POST /api/v2/management/organizations/:permalink/unsuspend
      def unsuspend
        require_super_admin!
        return if performed?

        find_organization!(:permalink)

        unless @organization.suspended?
          render_error("NotSuspended", "Organization is not suspended")
          return
        end

        @organization.suspended_at = nil
        @organization.suspension_reason = nil
        @organization.save!

        render_success(organization_json(@organization, detailed: true))
      end

      private

      def filter_organizations(scope)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(permalink: params[:permalink]) if params[:permalink].present?
        scope
      end

      def organization_params
        params.permit(:name, :permalink, :time_zone)
      end

      def organization_update_params
        params.permit(:name, :time_zone)
      end

      def organization_json(org, detailed: false)
        data = {
          uuid: org.uuid,
          name: org.name,
          permalink: org.permalink,
          time_zone: org.time_zone,
          status: org.status,
          suspended: org.suspended?,
          suspension_reason: org.suspension_reason,
          created_at: org.created_at.iso8601,
          updated_at: org.updated_at.iso8601
        }

        if detailed
          data[:owner] = {
            uuid: org.owner.uuid,
            email: org.owner.email_address,
            name: "#{org.owner.first_name} #{org.owner.last_name}".strip
          }
          data[:stats] = {
            servers: org.servers.present.count,
            users: org.users.count,
            domains: org.domains.count
          }
          data[:ip_pools] = org.ip_pools.map { |pool| { uuid: pool.uuid, name: pool.name } }
        end

        data
      end

    end
  end
end
