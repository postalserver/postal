# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_users
#
#  id              :integer          not null, primary key
#  organization_id :integer
#  user_id         :integer
#  created_at      :datetime
#  admin           :boolean          default(FALSE)
#  all_servers     :boolean          default(TRUE)
#  read_only       :boolean          default(FALSE), not null
#  user_type       :string(255)
#

class OrganizationUser < ApplicationRecord

  ROLES = %w[readonly member admin].freeze

  belongs_to :organization
  belongs_to :user, polymorphic: true, optional: true

  def role
    return "admin" if admin?

    read_only? ? "readonly" : "member"
  end

  def org_admin?
    admin?
  end

  def can_write?
    !read_only?
  end

  def apply_role!(role_name)
    case role_name.to_s
    when "admin"
      update!(admin: true, read_only: false)
    when "readonly"
      update!(admin: false, read_only: true)
    else
      update!(admin: false, read_only: false)
    end
  end

end
