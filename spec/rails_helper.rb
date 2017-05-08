ENV['POSTAL_CONFIG_ROOT'] = File.expand_path('../config', __FILE__)

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'spec_helper'
require 'factory_girl'
require 'database_cleaner'

FACTORIES_EXCLUDED_FROM_LINT = []
Dir[File.expand_path('../factories/*.rb', __FILE__)].each { |f| require f }

ActiveRecord::Migration.maintain_test_schema!
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    begin
      DatabaseCleaner.start
      FactoryGirl.lint(FactoryGirl.factories.select { |f| !FACTORIES_EXCLUDED_FROM_LINT.include?(f.name.to_sym) })
    ensure
      DatabaseCleaner.clean
    end
  end
end
