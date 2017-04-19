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
#  user_type       :string(255)
#

class OrganizationUser < ApplicationRecord

  belongs_to :organization
  belongs_to :user, :polymorphic => true, :optional => true

  validate :validate_uniqueness

  before_create :create_user_invite
  after_destroy :remove_user_invites

  def email_address
    @email_address ||= user&.email_address
  end

  def email_address=(value)
    @email_address = value
  end

  def create_user_invite
    if self.user.nil?
      user = UserInvite.where(:email_address => @email_address).first_or_initialize
      if user.save
        self.user = user
      else
        errors.add :base, user.errors.full_messages.to_sentence
        throw :abort
      end
    end
  end

  def validate_uniqueness
    if self.email_address.present?
      if organization.organization_users.where.not(:id => self.id).any? { |ou| ou.user.email_address.upcase == self.email_address.upcase }
        errors.add :email_address, "is already assigned or has an pending invite"
      end
    end
  end

  def remove_user_invites
    if self.user.is_a?(UserInvite) && self.user.organizations.empty?
      self.user.destroy
    end
  end

end
