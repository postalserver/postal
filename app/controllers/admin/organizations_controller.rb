class Admin::OrganizationsController < ApplicationController

  before_action :admin_required
  before_action { params[:id] && @organization = Organization.find_by_permalink!(params[:id]) }

  def index
    @organizations = Organization.order(:created_at => :desc).includes(:owner).page(params[:page])
  end

end
