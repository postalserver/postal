# frozen_string_literal: true

# == Schema Information
#
# Table name: routes
#
#  id            :integer          not null, primary key
#  endpoint_type :string(255)
#  mode          :string(255)
#  name          :string(255)
#  spam_mode     :string(255)
#  token         :string(255)
#  uuid          :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  domain_id     :integer
#  endpoint_id   :integer
#  server_id     :integer
#
# Indexes
#
#  index_routes_on_token  (token)
#
FactoryBot.define do
  factory :route do
    name { "test" }
    mode { "Accept" }
    spam_mode { "Mark" }

    before(:create) do |route|
      route.server ||= create(:server)
      route.domain ||= create(:domain, owner: route.server)
    end
  end
end
