# frozen_string_literal: true

module WithinOrganization

  extend ActiveSupport::Concern

  included do
    helper_method :organization
    before_action :add_organization_to_page_title
  end

  private

  def organization
    @organization ||= current_user.organizations_scope.find_by_permalink!(params[:org_permalink])
  end

  def add_organization_to_page_title
    page_title << organization.name
  end

end
