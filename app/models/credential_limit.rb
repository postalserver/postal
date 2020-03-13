# == Schema Information
#
# Table name: credential_limits
#
#  id           :integer          not null, primary key
#  credential_id    :integer
#  type          :string(255)
#  limit         :integer
#  usage         :integer
#
class CredentialLimit < ApplicationRecord
    belongs_to :credential
end