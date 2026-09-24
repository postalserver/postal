# frozen_string_literal: true

require "fileutils"
require "openssl"

module Postal
  # Issues the certificates which the MTA-STS policy hosts of hosted domains are
  # served from, using the ACME HTTP-01 challenge. The ACME client library is
  # optional, so installations which never issue a certificate never load it.
  module ACME

    class NotAvailable < StandardError; end

    class Error < StandardError; end

    # How long to wait for a challenge to be validated and for the certificate to
    # be issued.
    TIMEOUT = 120

    class << self

      # Whether the optional ACME client library is installed.
      #
      # @return [Boolean]
      def available?
        require "acme-client"
        true
      rescue LoadError
        false
      end

      # Request a certificate for a hostname. Neither the certificate nor the key
      # which it was issued for is written to disk here; the caller decides where
      # they belong.
      #
      # @param hostname [String] the hostname to issue for
      # @return [Hash] the :certificate PEM chain and the matching :key
      def issue(hostname)
        ensure_available!

        key = OpenSSL::PKey::RSA.new(4096)
        csr = ::Acme::Client::CertificateRequest.new(private_key: key, common_name: hostname)

        tokens = []
        begin
          order = client.new_order(identifiers: [hostname])
          order.authorizations.each do |authorization|
            challenge = authorization.http01
            AcmeChallenge.store!(challenge.token, challenge.file_content)
            tokens << challenge.token
            challenge.request_validation
          end

          await(order, %w[ready valid])
          order.finalize(csr: csr.to_der)
          certificate = await_certificate(order)

          { certificate: certificate, key: key.to_pem }
        ensure
          AcmeChallenge.where(token: tokens).delete_all if tokens.any?
        end
      end

      # A client for the configured directory. The account is registered the first
      # time it is needed.
      #
      # @return [Acme::Client]
      def client
        @client ||= begin
          client = ::Acme::Client.new(
            private_key: account_key,
            directory: Postal::Config.mta_sts.acme_directory_url
          )
          client.new_account(contact: account_contact, terms_of_service_agreed: true)
          client
        end
      end

      # The account key, which is generated and stored on first use.
      #
      # @return [OpenSSL::PKey::RSA]
      def account_key
        @account_key ||= begin
          path = Postal::Config.mta_sts.account_key_path

          if File.exist?(path)
            OpenSSL::PKey::RSA.new(File.read(path))
          else
            key = OpenSSL::PKey::RSA.new(4096)
            FileUtils.mkdir_p(File.dirname(path))
            File.open(path, File::CREAT | File::EXCL | File::WRONLY, 0o600) do |file|
              file.write(key.to_pem)
            end
            key
          end
        end
      end

      private

      def ensure_available!
        return if available?

        raise NotAvailable, "The acme-client gem is not installed. Enable it with " \
                            "`bundle config set --local with acme` and install again."
      end

      def account_contact
        address = Postal::Config.mta_sts.contact_email
        address.present? ? ["mailto:#{address}"] : []
      end

      # Wait for an order to reach one of the given statuses, reloading it as we
      # go. Raises if the order is rejected or takes too long.
      def await(order, statuses)
        deadline = Time.now + TIMEOUT
        loop do
          return if statuses.include?(order.status)

          raise Error, "The certificate order was rejected (#{order.status})" if order.status == "invalid"
          raise Error, "The certificate order did not complete in time" if Time.now > deadline

          sleep 2
          order.reload
        end
      end

      # Wait until the certificate for an order is available and return it.
      def await_certificate(order)
        await(order, ["valid"])
        order.certificate
      end

    end

  end
end
