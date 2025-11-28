# frozen_string_literal: true

# A simple wrapper class for static Management API keys defined in postal.yml.
# Provides the same interface as ManagementAPIKey for use in controllers.
#
# Usage in postal.yml:
#   management_api:
#     api_key: "your-secret-api-key-here"
#     super_admin: true
#
class StaticManagementAPIKey

  attr_reader :super_admin

  def initialize(super_admin = true)
    @super_admin = super_admin
  end

  def super_admin?
    @super_admin
  end

  # Static keys have all permissions
  def can?(_resource, _action)
    true
  end

  # No-op for static keys (no database record to update)
  def use(_ip_address)
    # Static keys don't track usage
  end

  def name
    "Static Config Key"
  end

  def id
    0
  end

  def accessible_organizations
    if super_admin?
      Organization.present
    else
      Organization.none
    end
  end

  def accessible_servers
    if super_admin?
      Server.joins(:organization).where(organizations: { deleted_at: nil })
    else
      Server.none
    end
  end

end
