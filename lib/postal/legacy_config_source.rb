# frozen_string_literal: true

require "konfig/sources/abstract"
require "konfig/error"

module Postal
  class LegacyConfigSource < Konfig::Sources::Abstract

    # This maps all the new configuration values to where they
    # exist in the old YAML file. The source will load any YAML
    # file that has been provided to this source in order. A
    # warning will be generated to the console for configuration
    # loaded from this format.
    MAPPING = {
      "postal.web_hostname" => -> (c) { c.dig("web", "host") },
      "postal.web_protocol" => -> (c) { c.dig("web", "protocol") },
      "postal.smtp_hostname" => -> (c) { c.dig("dns", "smtp_server_hostname") },
      "postal.use_ip_pools" => -> (c) { c.dig("general", "use_ip_pools") },
      "logging.sentry_dsn" => -> (c) { c.dig("general", "exception_url") },
      "postal.default_maximum_delivery_attempts" => -> (c) { c.dig("general", "maximum_delivery_attempts") },
      "postal.default_maximum_hold_expiry_days" => -> (c) { c.dig("general", "maximum_hold_expiry_days") },
      "postal.default_suppression_list_automatic_removal_days" => -> (c) { c.dig("general", "suppression_list_removal_delay") },
      "postal.use_local_ns_for_domain_verification" => -> (c) { c.dig("general", "use_local_ns_for_domains") },
      "postal.default_spam_threshold" => -> (c) { c.dig("general", "default_spam_threshold") },
      "postal.default_spam_failure_threshold" => -> (c) { c.dig("general", "default_spam_failure_threshold") },
      "postal.use_resent_sender_header" => -> (c) { c.dig("general", "use_resent_sender_header") },
      # SMTP relays must be converted to the new URI style format and they'll
      # then be transformed back to a hash by the schema transform.
      "postal.smtp_relays" => -> (c) { c["smtp_relays"]&.map { |r| "smtp://#{r['hostname']}:#{r['port']}?ssl_mode=#{r['ssl_mode']}" } },

      "web_server.default_bind_address" => -> (c) { c.dig("web_server", "bind_address") },
      "web_server.default_port" => -> (c) { c.dig("web_server", "port") },
      "web_server.max_threads" => -> (c) { c.dig("web_server", "max_threads") },

      "main_db.host" => -> (c) { c.dig("main_db", "host") },
      "main_db.port" => -> (c) { c.dig("main_db", "port") },
      "main_db.username" => -> (c) { c.dig("main_db", "username") },
      "main_db.password" => -> (c) { c.dig("main_db", "password") },
      "main_db.database" => -> (c) { c.dig("main_db", "database") },
      "main_db.pool_size" => -> (c) { c.dig("main_db", "pool_size") },
      "main_db.encoding" => -> (c) { c.dig("main_db", "encoding") },

      "message_db.host" => -> (c) { c.dig("message_db", "host") },
      "message_db.port" => -> (c) { c.dig("message_db", "port") },
      "message_db.username" => -> (c) { c.dig("message_db", "username") },
      "message_db.password" => -> (c) { c.dig("message_db", "password") },
      "message_db.database_name_prefix" => -> (c) { c.dig("message_db", "prefix") },

      "logging.rails_log_enabled" => -> (c) { c.dig("logging", "rails_log") },

      "gelf.host" => -> (c) { c.dig("logging", "graylog", "host") },
      "gelf.port" => -> (c) { c.dig("logging", "graylog", "port") },
      "gelf.facility" => -> (c) { c.dig("logging", "graylog", "facility") },

      "smtp_server.default_port" => -> (c) { c.dig("smtp_server", "port") },
      "smtp_server.default_bind_address" => -> (c) { c.dig("smtp_server", "bind_address") || "::" },
      "smtp_server.tls_enabled" => -> (c) { c.dig("smtp_server", "tls_enabled") },
      "smtp_server.tls_certificate_path" => -> (c) { c.dig("smtp_server", "tls_certificate_path") },
      "smtp_server.tls_private_key_path" => -> (c) { c.dig("smtp_server", "tls_private_key_path") },
      "smtp_server.tls_ciphers" => -> (c) { c.dig("smtp_server", "tls_ciphers") },
      "smtp_server.ssl_version" => -> (c) { c.dig("smtp_server", "ssl_version") },
      "smtp_server.proxy_protocol" => -> (c) { c.dig("smtp_server", "proxy_protocol") },
      "smtp_server.log_connections" => -> (c) { c.dig("smtp_server", "log_connect") },
      "smtp_server.max_message_size" => -> (c) { c.dig("smtp_server", "max_message_size") },

      "dns.mx_records" => -> (c) { c.dig("dns", "mx_records") },
      "dns.spf_include" => -> (c) { c.dig("dns", "spf_include") },
      "dns.return_path_domain" => -> (c) { c.dig("dns", "return_path") },
      "dns.route_domain" => -> (c) { c.dig("dns", "route_domain") },
      "dns.track_domain" => -> (c) { c.dig("dns", "track_domain") },
      "dns.helo_hostname" => -> (c) { c.dig("dns", "helo_hostname") },
      "dns.dkim_identifier" => -> (c) { c.dig("dns", "dkim_identifier") },
      "dns.domain_verify_prefix" => -> (c) { c.dig("dns", "domain_verify_prefix") },
      "dns.custom_return_path_prefix" => -> (c) { c.dig("dns", "custom_return_path_prefix") },

      "smtp.host" => -> (c) { c.dig("smtp", "host") },
      "smtp.port" => -> (c) { c.dig("smtp", "port") },
      "smtp.username" => -> (c) { c.dig("smtp", "username") },
      "smtp.password" => -> (c) { c.dig("smtp", "password") },
      "smtp.from_name" => -> (c) { c.dig("smtp", "from_name") },
      "smtp.from_address" => -> (c) { c.dig("smtp", "from_address") },

      "rails.environment" => -> (c) { c.dig("rails", "environment") },
      "rails.secret_key" => -> (c) { c.dig("rails", "secret_key") },

      "rspamd.enabled" => -> (c) { c.dig("rspamd", "enabled") },
      "rspamd.host" => -> (c) { c.dig("rspamd", "host") },
      "rspamd.port" => -> (c) { c.dig("rspamd", "port") },
      "rspamd.ssl" => -> (c) { c.dig("rspamd", "ssl") },
      "rspamd.password" => -> (c) { c.dig("rspamd", "password") },
      "rspamd.flags" => -> (c) { c.dig("rspamd", "flags") },

      "spamd.enabled" => -> (c) { c.dig("spamd", "enabled") },
      "spamd.host" => -> (c) { c.dig("spamd", "host") },
      "spamd.port" => -> (c) { c.dig("spamd", "port") },

      "clamav.enabled" => -> (c) { c.dig("clamav", "enabled") },
      "clamav.host" => -> (c) { c.dig("clamav", "host") },
      "clamav.port" => -> (c) { c.dig("clamav", "port") },

      "smtp_client.open_timeout" => -> (c) { c.dig("smtp_client", "open_timeout") },
      "smtp_client.read_timeout" => -> (c) { c.dig("smtp_client", "read_timeout") }

    }.freeze

    def initialize(config)
      super()
      @config = config
    end

    def get(path, attribute: nil)
      path_string = path.join(".")
      raise Konfig::ValueNotPresentError unless MAPPING.key?(path_string)

      legacy_value = MAPPING[path_string].call(@config)
      raise Konfig::ValueNotPresentError if legacy_value.nil?

      legacy_value
    end

  end
end
