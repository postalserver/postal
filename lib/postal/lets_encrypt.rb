require 'acme-client'

module Postal
  module LetsEncrypt

    def self.client
      @client ||= Acme::Client.new(:private_key => private_key, :endpoint => endpoint)
    end

    def self.private_key
      @private_key ||= OpenSSL::PKey::RSA.new(File.open(Postal.lets_encrypt_private_key_path))
    end

    def self.endpoint
      @endpoint ||= Rails.env.development? ? "https://acme-staging.api.letsencrypt.org" : "https://acme-v01.api.letsencrypt.org/"
    end

    def self.register_private_key(email_address)
      registration = client.register(:contact => "mailto:#{email_address}")
      logger.info "Successfully registered private key with address #{email_address}"
      registration.agree_terms
      logger.info "Terms have been accepted"
      true
    end

    def self.logger
      Postal.logger_for(:lets_encrypt)
    end

  end
end
