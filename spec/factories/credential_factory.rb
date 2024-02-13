# frozen_string_literal: true

# == Schema Information
#
# Table name: credentials
#
#  id           :integer          not null, primary key
#  hold         :boolean          default(FALSE)
#  key          :string(255)
#  last_used_at :datetime
#  name         :string(255)
#  options      :text(65535)
#  type         :string(255)
#  uuid         :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  server_id    :integer
#
FactoryBot.define do
  factory :credential do
    server
    name { "Example Credential" }
    type { "API" }
  end
end
