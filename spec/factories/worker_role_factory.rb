# frozen_string_literal: true

# == Schema Information
#
# Table name: worker_roles
#
#  id          :bigint           not null, primary key
#  acquired_at :datetime
#  role        :string(255)
#  worker      :string(255)
#
# Indexes
#
#  index_worker_roles_on_role  (role) UNIQUE
#
FactoryBot.define do
  factory :worker_role do
    role { "test" }
  end
end
