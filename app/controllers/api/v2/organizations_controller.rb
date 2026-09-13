# frozen_string_literal: true

module API
  module V2
    class OrganizationsController < BaseController

      before_action only: [:show, :update, :destroy, :suspend, :unsuspend] do
        @organization = scoped_organization!(params[:uuid])
      end

      def index
        require_scope!("organizations:read")
        return if performed?

        if current_control_api_key.platform_admin?
          scope = Organization.present.order(:created_at)
        else
          scope = Organization.present.where(id: current_control_api_key.organization_id).order(:created_at)
        end
        records, meta = pagination_for(scope)
        render_data(records.map { |organization| serialize(organization) }, meta: meta.merge(total: scope.count))
      end

      def show
        require_scope!("organizations:read")
        return if performed? || @organization.nil?

        render_data(serialize(@organization))
      end

      def create
        require_scope!("organizations:write")
        return if performed?
        return render_error("forbidden", "Only platform API keys can create organizations", status: :forbidden) unless current_control_api_key.platform_admin?

        with_idempotency do
          organization = nil
          Organization.transaction do
            owner = find_or_create_owner!(owner_params)
            organization = Organization.create!(organization_params.merge(owner: owner))
            OrganizationUser.where(organization: organization, user: owner).first_or_create!.update!(admin: true, all_servers: true)
          end
          audit!(organization: organization, resource: organization, action: "organization.created", after: serialize(organization))
          render_data(serialize(organization), status: :created)
        end
      end

      def update
        require_scope!("organizations:write")
        return if performed? || @organization.nil?

        before = serialize(@organization)
        @organization.update!(organization_params.except(:external_customer_id))
        audit!(organization: @organization, resource: @organization, action: "organization.updated", before: before, after: serialize(@organization))
        render_data(serialize(@organization))
      end

      def destroy
        require_scope!("organizations:write")
        return if performed? || @organization.nil?

        with_idempotency do
          @organization.soft_destroy
          audit!(organization: @organization, resource: @organization, action: "organization.deleted")
          head :no_content
        end
      end

      def suspend
        lifecycle(:suspend)
      end

      def unsuspend
        lifecycle(:unsuspend)
      end

      private

      def lifecycle(operation)
        require_scope!("organizations:write")
        return if performed? || @organization.nil?

        with_idempotency do
          before = serialize(@organization)
          operation == :suspend ? @organization.suspend(params[:reason].to_s) : @organization.unsuspend
          audit!(organization: @organization, resource: @organization, action: "organization.#{operation}ed", before: before, after: serialize(@organization))
          render_data(serialize(@organization))
        end
      end

      def organization_params
        params.permit(:name, :permalink, :time_zone, :external_customer_id, :plan_code,
                      :monthly_outbound_limit, :quota_warning_percent, :quota_action)
      end

      def owner_params
        params.require(:owner).permit(:email_address, :first_name, :last_name)
      end

      def find_or_create_owner!(attributes)
        User.find_by(email_address: attributes[:email_address]) || User.create!(attributes.merge(password: SecureRandom.urlsafe_base64(48)))
      rescue ActiveRecord::RecordNotUnique
        User.find_by!(email_address: attributes[:email_address])
      end

      def serialize(organization)
        {
          uuid: organization.uuid, name: organization.name, permalink: organization.permalink, time_zone: organization.time_zone,
          status: organization.status.downcase, suspension_reason: organization.suspension_reason,
          external_customer_id: organization.external_customer_id, plan_code: organization.plan_code,
          monthly_outbound_limit: organization.monthly_outbound_limit, quota_warning_percent: organization.quota_warning_percent,
          quota_action: organization.quota_action, created_at: organization.created_at, updated_at: organization.updated_at
        }
      end

    end
  end
end
