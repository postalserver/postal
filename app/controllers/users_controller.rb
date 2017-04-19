class UsersController < ApplicationController
  include WithinOrganization
  before_action :require_organization_admin
  before_action :require_organization_owner, :only => [:make_owner]
  before_action { params[:id] && @user = params[:invite] ? organization.user_invites.find_by_uuid!(params[:id]) : organization.users.find_by_uuid!(params[:id]) }

  def index
    @users = organization.organization_users.where(:user_type => 'User').includes(:user).to_a.sort_by { |u| "#{u.user.first_name}#{u.user.last_name}".upcase }
    @pending_users = organization.organization_users.where(:user_type => "UserInvite").includes(:user).to_a.sort_by { |u| u.user.email_address.upcase }
  end

  def new
    @organization_user = organization.organization_users.build
  end

  def create
    @organization_user = organization.organization_users.build(params.require(:organization_user).permit(:email_address, :admin, :all_servers))
    if @organization_user.save
      AppMailer.user_invite(@organization_user.user, organization).deliver
      redirect_to_with_json [organization, :users], :notice => "An invitation will be sent to #{@organization_user.user.email_address} which will allow them to access your organization."
    else
      render_form_errors 'new', @organization_user
    end
  end

  def edit
    @organization_user = organization.user_assignment(@user)
  end

  def update
    @organization_user = organization.user_assignment(@user)
    if @organization_user.update(params.require(:organization_user).permit(:admin))
      redirect_to_with_json [organization, :users], :notice => "Permissions for #{@organization_user.user.name} have been updated successfully."
    else
      render_form_errors 'edit', @organization_user
    end
  end

  def destroy
    if @user == current_user
      redirect_to_with_json [organization, :users], :alert => "You cannot revoke your own access."
      return
    end

    if @user == organization.owner
      redirect_to_with_json [organization, :users], :alert => "You cannot revoke the organization owner's access."
      return
    end

    organization.organization_users.where(:user => @user).destroy_all
    redirect_to_with_json [organization, :users], :notice => "#{@user.name} has been removed from this organization"
  end

  def make_owner
    if @user.is_a?(User)
      organization.make_owner(@user)
      redirect_to_with_json [organization, :users], :notice => "#{@user.name} is now the owner of this organization."
    else
      raise Postal::Error, "User must be a User not a UserInvite to make owner"
    end
  end

end
