# frozen_string_literal: true

ENV["POSTAL_ENV"] = "test"

require File.expand_path("../config/environment", __dir__)
require "rspec/rails"
require "spec_helper"
require "factory_bot"
require "timecop"
require "database_cleaner"
require "webmock/rspec"

DatabaseCleaner.allow_remote_database_url = true
ActiveRecord::Base.logger = Logger.new("/dev/null")

Dir[File.expand_path("factories/*.rb", __dir__)].each { |f| require f }
Dir[File.expand_path("helpers/**/*.rb", __dir__)].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include Postal::RspecHelpers

  config.before(:suite) do
    # Test that the factories are working as they should and then clean up before getting started on
    # the rest of the suite.
    DatabaseCleaner.start
    FactoryBot.lint
  ensure
    DatabaseCleaner.clean
  end
end
