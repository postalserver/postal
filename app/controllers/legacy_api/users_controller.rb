# frozen_string_literal: true

class LegacyApi::UsersController < LegacyApi::BaseController

  def index
    users = @organization.users
    users_data = users.map { |user| serialize_user(user) }
    render_success(users: users_data)
  end

  def show
    user = @organization.users.find_by(uuid: params[:id])
    if user
      render_success(user: serialize_user(user))
    else
      render_error("UserNotFound", message: "User not found")
    end
  end

  def create
    # Check if user already exists
    existing_user = User.find_by(email_address: user_params["email_address"])
    
    if existing_user
      # Add existing user to organization if not already a member
      unless @organization.users.include?(existing_user)
        @organization.organization_users.create!(
          user: existing_user,
          admin: user_params["admin"] || false
        )
      end
      render_success(user: serialize_user(existing_user), message: "User added to organization")
    else
      # Create new user
      user = User.new(user_params)
      user.password = user_params["password"] || SecureRandom.alphanumeric(12)
      user.email_verified_at = Time.current # Auto-verify for API created users
      
      if user.save
        @organization.organization_users.create!(
          user: user,
          admin: user_params["admin"] || false
        )
        render_success(user: serialize_user(user), message: "User created successfully")
      else
        render_parameter_error(user.errors.full_messages.join(", "))
      end
    end
  end

  def update
    @user = @organization.users.find_by(uuid: params[:id])
    unless @user
      render_error("UserNotFound", message: "User not found")
      return
    end

    update_params = user_params.except("email_address") # Don't allow email changes
    update_params.delete("password") if update_params["password"].blank?

    if @user.update(update_params)
      # Update organization admin status if specified
      if user_params.key?("admin")
        org_user = @organization.organization_users.find_by(user: @user)
        org_user&.update(admin: user_params["admin"])
      end
      
      render_success(user: serialize_user(@user), message: "User updated successfully")
    else
      render_parameter_error(@user.errors.full_messages.join(", "))
    end
  end

  def destroy
    @user = @organization.users.find_by(uuid: params[:id])
    unless @user
      render_error("UserNotFound", message: "User not found")
      return
    end

    # Prevent deletion of organization owner
    if @user == @organization.owner
      render_error("CannotDeleteOwner", 
        message: "Cannot delete the organization owner")
      return
    end

    # Remove user from organization
    @organization.organization_users.where(user: @user).destroy_all
    
    # Delete user entirely if they're not in any other organizations
    if @user.organizations.empty?
      @user.destroy
    end

    render_success(message: "User removed successfully")
  end

  private

  def user_params
    allowed_params = api_params.slice("first_name", "last_name", "email_address", "password", "admin", "time_zone")
    allowed_params
  end

  def serialize_user(user)
    org_user = @organization.organization_users.find_by(user: user)
    {
      id: user.uuid,
      first_name: user.first_name,
      last_name: user.last_name,
      email_address: user.email_address,
      time_zone: user.time_zone,
      admin: org_user&.admin || false,
      email_verified_at: user.email_verified_at,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

end