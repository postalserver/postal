# frozen_string_literal: true

module GlobalMessageDB

  class << self

    def find_or_create
      return @db if @db

      @db = Postal::MessageDB::Database.new(1, 1, database_name: "postal-test-message-db")
      @db.provisioner.provision
    end

    def exists?
      !@db.nil?
    end

  end

end

RSpec.configure do |config|
  config.before(:example) do
    @mocked_message_dbs = []
    allow_any_instance_of(Server).to receive(:message_db).and_wrap_original do |m|
      GlobalMessageDB.find_or_create

      message_db = m.call
      @mocked_message_dbs << message_db
      allow(message_db).to receive(:database_name).and_return("postal-test-message-db")
      message_db
    end
  end

  config.after(:example) do
    if GlobalMessageDB.exists? && @mocked_message_dbs.present?
      GlobalMessageDB.find_or_create.provisioner.clean
      @mocked_message_dbs = []
    end
  end
end
