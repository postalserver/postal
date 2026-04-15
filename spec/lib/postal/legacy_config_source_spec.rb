# frozen_string_literal: true

require "rails_helper"

module Postal

  SOURCE_CONFIG = YAML.safe_load(File.read(Rails.root.join("spec/examples/full_legacy_config_file.yml")))

  # Rather than actuall test the LegacyConfigSource directly, I have decided
  # to test this source via. the Konfig::Config system to ensure it works as
  # expected in practice rather than just in theory. Testing '#get' would be
  # fairly easy (and mostly pointless) where as testing the values we actually
  # want are correct is preferred.
  RSpec.describe LegacyConfigSource do
    before do
      # For the purposes of testing, we want to ignore any defaults provided
      # by the schema itself. Otherwise, we might see a value returned that
      # looks correct but is actually the default rather than the value from
      # config file.
      allow_any_instance_of(Konfig::SchemaAttribute).to receive(:default) do |a|
        a.array? ? [] : nil
      end
    end

    let(:source) { described_class.new(SOURCE_CONFIG) }
    subject(:config) { Konfig::Config.build(ConfigSchema, sources: [source]) }

    describe "the 'postal' group" do
      it "returns a value for postal.web_hostname" do
        expect(config.postal.web_hostname).to eq "postal.llamas.com"
      end

      it "returns a value for postal.web_protocol" do
        expect(config.postal.web_protocol).to eq "https"
      end

      it "returns a value for postal.smtp_hostname" do
        expect(config.postal.smtp_hostname).to eq "smtp.postal.llamas.com"
      end

      it "returns a value for postal.use_ip_pools?" do
        expect(config.postal.use_ip_pools?).to eq false
      end

      it "returns a value for postal.default_maximum_delivery_attempts" do
        expect(config.postal.default_maximum_delivery_attempts).to eq 20
      end

      it "returns a value for postal.default_maximum_hold_expiry_days" do
        expect(config.postal.default_maximum_hold_expiry_days).to eq 10
      end

      it "returns a value for postal.default_suppression_list_automatic_removal_days" do
        expect(config.postal.default_suppression_list_automatic_removal_days).to eq 60
      end

      it "returns a value for postal.use_local_ns_for_domain_verification?" do
        expect(config.postal.use_local_ns_for_domain_verification?).to eq true
      end

      it "returns a value for postal.default_spam_threshold" do
        expect(config.postal.default_spam_threshold).to eq 10
      end

      it "returns a value for postal.default_spam_failure_threshold" do
        expect(config.postal.default_spam_failure_threshold).to eq 25
      end

      it "returns a value for postal.use_resent_sender_header?" do
        expect(config.postal.use_resent_sender_header?).to eq true
      end

      it "returns a value for postal.smtp_relays" do
        expect(config.postal.smtp_relays).to eq [
          { "host" => "1.2.3.4", "port" => 25, "ssl_mode" => "Auto" },
          { "host" => "2.2.2.2", "port" => 2525, "ssl_mode" => "None" },
        ]
      end
    end

    describe "the 'web_server' group" do
      it "returns a value for web_server.default_bind_address" do
        expect(config.web_server.default_bind_address).to eq "127.0.0.1"
      end

      it "returns a value for web_server.default_port" do
        expect(config.web_server.default_port).to eq 6000
      end

      it "returns a value for web_server.max_threads" do
        expect(config.web_server.max_threads).to eq 10
      end
    end

    describe "the 'main_db' group" do
      it "returns a value for main_db.host" do
        expect(config.main_db.host).to eq "localhost"
      end

      it "returns a value for main_db.port" do
        expect(config.main_db.port).to eq 3306
      end

      it "returns a value for main_db.username" do
        expect(config.main_db.username).to eq "postal"
      end

      it "returns a value for main_db.password" do
        expect(config.main_db.password).to eq "t35tpassword"
      end

      it "returns a value for main_db.database" do
        expect(config.main_db.database).to eq "postal"
      end

      it "returns a value for main_db.pool_size" do
        expect(config.main_db.pool_size).to eq 20
      end

      it "returns a value for main_db.encoding" do
        expect(config.main_db.encoding).to eq "utf8mb4"
      end
    end

    describe "the 'message_db' group" do
      it "returns a value for message_db.host" do
        expect(config.message_db.host).to eq "localhost"
      end

      it "returns a value for message_db.port" do
        expect(config.message_db.port).to eq 3306
      end

      it "returns a value for message_db.username" do
        expect(config.message_db.username).to eq "postal"
      end

      it "returns a value for message_db.password" do
        expect(config.message_db.password).to eq "p05t41"
      end

      it "returns a value for message_db.database_name_prefix" do
        expect(config.message_db.database_name_prefix).to eq "postal"
      end
    end

    describe "the 'logging' group" do
      it "returns a value for logging.rails_log_enabled" do
        expect(config.logging.rails_log_enabled).to eq true
      end
    end

    describe "the 'gelf' group" do
      it "returns a value for gelf.host" do
        expect(config.gelf.host).to eq "logs.llamas.com"
      end

      it "returns a value for gelf.port" do
        expect(config.gelf.port).to eq 12_201
      end

      it "returns a value for gelf.facility" do
        expect(config.gelf.facility).to eq "mailer"
      end
    end

    describe "the 'smtp_server' group" do
      it "returns a value for smtp_server.default_port" do
        expect(config.smtp_server.default_port).to eq 25
      end

      it "returns a value for smtp_server.default_bind_address" do
        expect(config.smtp_server.default_bind_address).to eq "127.0.0.1"
      end

      it "returns a value for smtp_server.tls_enabled" do
        expect(config.smtp_server.tls_enabled).to eq true
      end

      it "returns a value for smtp_server.tls_certificate_path" do
        expect(config.smtp_server.tls_certificate_path).to eq "config/smtp.cert"
      end

      it "returns a value for smtp_server.tls_private_key_path" do
        expect(config.smtp_server.tls_private_key_path).to eq "config/smtp.key"
      end

      it "returns a value for smtp_server.tls_ciphers" do
        expect(config.smtp_server.tls_ciphers).to eq "abc"
      end

      it "returns a value for smtp_server.ssl_version" do
        expect(config.smtp_server.ssl_version).to eq "SSLv23"
      end

      it "returns a value for smtp_server.proxy_protocol" do
        expect(config.smtp_server.proxy_protocol).to eq false
      end

      it "returns a value for smtp_server.log_connections" do
        expect(config.smtp_server.log_connections).to eq true
      end

      it "returns a value for smtp_server.max_message_size" do
        expect(config.smtp_server.max_message_size).to eq 10
      end
    end

    describe "the 'dns' group" do
      it "returns a value for dns.mx_records" do
        expect(config.dns.mx_records).to eq ["mx1.postal.llamas.com", "mx2.postal.llamas.com"]
      end

      it "returns a value for dns.spf_include" do
        expect(config.dns.spf_include).to eq "spf.postal.llamas.com"
      end

      it "returns a value for dns.return_path_domain" do
        expect(config.dns.return_path_domain).to eq "rp.postal.llamas.com"
      end

      it "returns a value for dns.route_domain" do
        expect(config.dns.route_domain).to eq "routes.postal.llamas.com"
      end

      it "returns a value for dns.track_domain" do
        expect(config.dns.track_domain).to eq "track.postal.llamas.com"
      end

      it "returns a value for dns.helo_hostname" do
        expect(config.dns.helo_hostname).to eq "helo.postal.llamas.com"
      end

      it "returns a value for dns.dkim_identifier" do
        expect(config.dns.dkim_identifier).to eq "postal"
      end

      it "returns a value for dns.domain_verify_prefix" do
        expect(config.dns.domain_verify_prefix).to eq "postal-verification"
      end

      it "returns a value for dns.custom_return_path_prefix" do
        expect(config.dns.custom_return_path_prefix).to eq "psrp"
      end
    end

    describe "the 'smtp' group" do
      it "returns a value for smtp.host" do
        expect(config.smtp.host).to eq "127.0.0.1"
      end

      it "returns a value for smtp.port" do
        expect(config.smtp.port).to eq 25
      end

      it "returns a value for smtp.username" do
        expect(config.smtp.username).to eq "postalserver"
      end

      it "returns a value for smtp.password" do
        expect(config.smtp.password).to eq "llama"
      end

      it "returns a value for smtp.from_name" do
        expect(config.smtp.from_name).to eq "Postal"
      end

      it "returns a value for smtp.from_address" do
        expect(config.smtp.from_address).to eq "postal@llamas.com"
      end
    end

    describe "the 'rails' group" do
      it "returns a value for rails.environment" do
        expect(config.rails.environment).to eq "production"
      end

      it "returns a value for rails.secret_key" do
        expect(config.rails.secret_key).to eq "abcdef123123123123123"
      end
    end

    describe "the 'rspamd' group" do
      it "returns a value for rspamd.enabled" do
        expect(config.rspamd.enabled).to eq true
      end

      it "returns a value for rspamd.host" do
        expect(config.rspamd.host).to eq "rspamd.llamas.com"
      end

      it "returns a value for rspamd.port" do
        expect(config.rspamd.port).to eq 11_334
      end

      it "returns a value for rspamd.ssl?" do
        expect(config.rspamd.ssl?).to eq false
      end

      it "returns a value for rspamd.password" do
        expect(config.rspamd.password).to eq "llama"
      end

      it "returns a value for rspamd.flags" do
        expect(config.rspamd.flags).to eq "abc"
      end
    end

    describe "the 'spamd' group" do
      it "returns a value for spamd.enabled" do
        expect(config.spamd.enabled).to eq false
      end

      it "returns a value for spamd.host" do
        expect(config.spamd.host).to eq "spamd.llamas.com"
      end

      it "returns a value for spamd.port" do
        expect(config.spamd.port).to eq 783
      end
    end

    describe "the 'clamav' group" do
      it "returns a value for clamav.enabled" do
        expect(config.clamav.enabled).to eq false
      end

      it "returns a value for clamav.host" do
        expect(config.clamav.host).to eq "clamav.llamas.com"
      end

      it "returns a value for clamav.port" do
        expect(config.clamav.port).to eq 2000
      end
    end

    describe "the 'smtp_client' group" do
      it "returns a value for smtp_client.open_timeout" do
        expect(config.smtp_client.open_timeout).to eq 60
      end

      it "returns a value for smtp_client.read_timeout" do
        expect(config.smtp_client.read_timeout).to eq 120
      end
    end
  end

end
