class OrganizationIPPoolsController < ApplicationController

  include WithinOrganization

  def index
    @ip_pools = organization.ip_pools.dedicated.order(:name)
  end

end
