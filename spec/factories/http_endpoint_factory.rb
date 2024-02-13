# frozen_string_literal: true

# == Schema Information
#
# Table name: http_endpoints
#
#  id                  :integer          not null, primary key
#  disabled_until      :datetime
#  encoding            :string(255)
#  error               :text(65535)
#  format              :string(255)
#  include_attachments :boolean          default(TRUE)
#  last_used_at        :datetime
#  name                :string(255)
#  strip_replies       :boolean          default(FALSE)
#  timeout             :integer
#  url                 :string(255)
#  uuid                :string(255)
#  created_at          :datetime
#  updated_at          :datetime
#  server_id           :integer
#
FactoryBot.define do
  factory :http_endpoint do
    server
    name { "HTTP endpoint" }
    url { "https://example.com/endpoint" }
    encoding { "BodyAsJSON" }
    format { "Hash" }
  end
end
