# frozen_string_literal: true

module OrganizationAuthorization

  extend ActiveSupport::Concern

  included do
    before_action :require_organization_write_access
    helper_method :organization_write_access?, :organization_readonly?
  end

  private

  def organization_membership
    return unless organization

    @organization_membership ||= organization.user_assignment(current_user)
  end

  def organization_write_access?
    return true if current_user.admin?
    return false unless organization

    organization_membership&.can_write?
  end

  def organization_readonly?
    return false if current_user.admin?
    return false unless organization

    organization_membership&.read_only?
  end

  def organization_write_request?
    !request.get? && !request.head?
  end

  def require_organization_write_access
    return unless organization_write_request?
    return unless organization
    return if organization_write_access?

    deny_organization_write_access
  end

  def require_organization_admin
    return if current_user.admin?
    return if organization.owner == current_user
    return if organization_membership&.org_admin?

    redirect_to organization_root_path(organization), alert: "You do not have permission to manage this organization."
  end

  def deny_organization_write_access
    respond_to do |wants|
      wants.html do
        redirect_back fallback_location: organization_root_path(organization),
                      alert: "You have read-only access to this organization and cannot make changes."
      end
      wants.json do
        render json: { error: "Read-only access" }, status: :forbidden
      end
    end
  end

end
