# frozen_string_literal: true

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
