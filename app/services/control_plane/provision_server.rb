# frozen_string_literal: true

module ControlPlane
  class ProvisionServer

    class ProvisioningError < StandardError; end

    def initialize(organization:, attributes:)
      @organization = organization
      @attributes = attributes
    end

    def call
      server = @organization.servers.build(@attributes)
      server.provision_database = false
      server.validate!

      Server.transaction { server.save! }
      begin
        server.message_db.provisioner.provision
      rescue StandardError => _e
        cleanup(server)
        raise ProvisioningError, "Mail server provisioning failed"
      end
      server
    end

    private

    def cleanup(server)
      server.message_db.provisioner.drop
    rescue StandardError
      nil
    ensure
      server.provision_database = false
      server.destroy!
    end

  end
end
