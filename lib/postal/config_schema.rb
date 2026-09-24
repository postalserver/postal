# frozen_string_literal: true

require "uri"

module Postal

  # REMEMBER: If you change the schema, remember to regenerate the configuration docs
  # using the rake command below:
  #
  #     rake postal:generate_config_docs

  ConfigSchema = Konfig::Schema.draw do
    group :postal do
      string :web_hostname do
        description "The hostname that the Postal web interface runs on"
        default "postal.example.com"
      end

      string :web_protocol do
        description "The HTTP protocol to use for the Postal web interface"
        default "https"
      end

      string :smtp_hostname do
        description "The hostname that the Postal SMTP server runs on"
        default "postal.example.com"
      end

      boolean :use_ip_pools do
        description "Should IP pools be enabled for this installation?"
        default false
      end

      integer :default_maximum_delivery_attempts do
        description "The maximum number of delivery attempts"
        default 18
      end

      integer :default_maximum_hold_expiry_days do
        description "The number of days to hold a message before they will be expired"
        default 7
      end

      integer :default_suppression_list_automatic_removal_days do
        description "The number of days an address will remain in a suppression list before being removed"
        default 30
      end

      integer :default_spam_threshold do
        description "The default threshold at which a message should be treated as spam"
        default 5
      end

      integer :default_spam_failure_threshold do
        description "The default threshold at which a message should be treated as spam failure"
        default 20
      end

      boolean :use_local_ns_for_domain_verification do
        description "Domain verification and checking usually checks with a domain's nameserver. Enable this to check with the server's local nameservers."
        default false
      end

      boolean :use_resent_sender_header do
        description "Append a Resend-Sender header to all outgoing e-mails"
        default true
      end

      string :signing_key_path do
        description "Path to the private key used for signing"
        default "$config-file-root/signing.key"
        transform { |v| Postal.substitute_config_file_root(v) }
      end

      string :smtp_relays do
        array
        description "An array of SMTP relays in the format of " \
                    "smtp://user:password@host:port?ssl_mode=Auto&auth=plain. The credentials and " \
                    "the auth mechanism are optional; auth may be plain, login or cram_md5 and " \
                    "defaults to the strongest mechanism the relay advertises"
        transform do |value|
          uri = URI.parse(value)
          query = uri.query ? URI.decode_www_form(uri.query).to_h : {}
          relay = {
            host: uri.host,
            port: uri.port || 25,
            ssl_mode: query["ssl_mode"] || "Auto",
            username: uri.user && URI.decode_uri_component(uri.user),
            password: uri.password && URI.decode_uri_component(uri.password),
            auth_mode: query["auth"]
          }
          # A relay which names no credentials or mechanism carries only the
          # three keys every relay has.
          relay.compact
        end
      end

      string :trusted_proxies do
        array
        description "An array of IP addresses to trust for proxying requests to Postal (in addition to localhost addresses)"
        transform { |ip| IPAddr.new(ip) }
      end

      string :allowed_request_destinations do
        array
        description "Hostnames or IP/CIDR ranges that outbound webhook and HTTP " \
                    "endpoint requests are permitted to reach even when they resolve " \
                    "to a private, loopback, link-local or otherwise reserved address. " \
                    "All other such destinations are blocked to prevent SSRF."
      end

      integer :queued_message_lock_stale_days do
        description "The number of days after which to consider a lock as stale. Messages with stale locks will be removed and not retried."
        default 1
      end

      boolean :batch_queued_messages do
        description "When enabled queued messages will be de-queued in batches based on their destination"
        default true
      end
    end

    group :web_server do
      integer :default_port do
        description "The default port the web server should listen on unless overriden by the PORT environment variable"
        default 5000
      end

      string :default_bind_address do
        description "The default bind address the web server should listen on unless overriden by the BIND_ADDRESS environment variable"
        default "127.0.0.1"
      end

      integer :max_threads do
        description "The maximum number of threads which can be used by the web server"
        default 5
      end
    end

    group :worker do
      integer :default_health_server_port do
        description "The default port for the worker health server to listen on"
        default 9090
      end

      string :default_health_server_bind_address do
        description "The default bind address for the worker health server to listen on"
        default "127.0.0.1"
      end

      integer :threads do
        description "The number of threads to execute within each worker"
        default 2
      end
    end

    group :main_db do
      string :host do
        description "Hostname for the main MariaDB server"
        default "localhost"
      end

      integer :port do
        description "The MariaDB port to connect to"
        default 3306
      end

      string :username do
        description "The MariaDB username"
        default "postal"
      end

      string :password do
        description "The MariaDB password"
      end

      string :database do
        description "The MariaDB database name"
        default "postal"
      end

      integer :pool_size do
        description "The maximum size of the MariaDB connection pool"
        default 5
      end

      string :encoding do
        description "The encoding to use when connecting to the MariaDB database"
        default "utf8mb4"
      end
    end

    group :message_db do
      string :host do
        description "Hostname for the MariaDB server which stores the mail server databases"
        default "localhost"
      end

      integer :port do
        description "The MariaDB port to connect to"
        default 3306
      end

      string :username do
        description "The MariaDB username"
        default "postal"
      end

      string :password do
        description "The MariaDB password"
      end

      string :database do
        description "The database to connect to for engines which need one: the PostgreSQL database " \
                    "which holds each server's schema, or the directory holding the per-server files " \
                    "for SQLite. Not used by MySQL/MariaDB, which keeps each server in its own database."
      end

      string :encoding do
        description "The encoding to use when connecting to the MariaDB database"
        default "utf8mb4"
      end

      string :database_name_prefix do
        description "The MariaDB prefix to add to database names"
        default "postal"
      end

      integer :raw_message_chunk_size do
        description "The maximum number of bytes from a raw message stored in a single database row " \
                    "(in bytes). Larger messages are split across multiple rows so that no single query " \
                    "exceeds the server's max_allowed_packet limit. Lower this if your database server " \
                    "uses a small max_allowed_packet."
        default 4 * 1024 * 1024
      end

      string :adapter do
        description "The database engine used for the per-server message databases. Either 'mysql' " \
                    "(MySQL/MariaDB), 'postgresql' or 'sqlite'."
        default "mysql"
      end
    end

    group :blob_store do
      string :url do
        description "Where the bodies of large raw messages are stored. The scheme selects the " \
                    "backend: 'inline://' (the default) keeps them in the message database, " \
                    "'filesystem:///var/lib/postal/blobs?depth=2' writes them to disk, " \
                    "'s3://bucket/prefix' uses an S3-compatible bucket, and " \
                    "'foundationdb://' uses a FoundationDB cluster."
        default "inline://"
      end

      integer :threshold do
        description "The minimum size of a message body (in bytes) before it is stored in the blob " \
                    "store rather than inline in the message database"
        default 1 * 1024 * 1024
      end
    end

    group :analytics do
      string :url do
        description "Where the daily analytics extract is written. The scheme selects the sink: " \
                    "'duckdb:///var/lib/postal/analytics' (embedded), " \
                    "'clickhouse://user:pass@host:8123/database', 'prometheus+http://host:8428' or " \
                    "'influx+http://host:8086/database'. Leave unset to disable analytics."
      end
    end

    group :live_stats do
      string :url do
        description "Where the live statistics (the last 60 minutes of message counts, shown on " \
                    "Postal's own dashboard) are kept. The scheme selects the store: 'mysql://' (the " \
                    "default) keeps them in the message database, 'valkey://host:6379/0' " \
                    "(or 'redis://', or any store speaking the Redis protocol) and " \
                    "'aerospike://host:3000/namespace/set' use an in-memory store, and " \
                    "'prometheus+http://host:8428' uses a Prometheus-compatible time-series " \
                    "store which can also stream to the dashboard as messages flow. The " \
                    "'influx' and 'json' schemes are write-only: they accept the extract " \
                    "but cannot be read back by the dashboard."
        default "mysql://"
      end

      integer :window do
        description "The number of seconds of recent statistics a live query covers"
        default 3600
      end
    end

    group :telemetry do
      string :url do
        description "Where Postal pushes metrics and events as they happen, for external dashboards " \
                    "and alerting. The scheme selects the protocol and endpoint: " \
                    "'prometheus+http://host:8428' (a Prometheus-compatible store such as " \
                    "VictoriaMetrics or Prometheus), 'influx+http://host:8086/database' or " \
                    "'json+http://host:8686' (for example a vector.dev http_server source). Unset to " \
                    "disable telemetry."
      end

      integer :interval do
        description "The number of seconds between telemetry flushes"
        default 15
      end

      integer :batch_size do
        description "The maximum number of telemetry samples sent in a single request"
        default 1000
      end

      integer :queue_size do
        description "The maximum number of telemetry samples buffered in memory before the oldest " \
                    "are dropped"
        default 10_000
      end
    end

    group :logging do
      boolean :rails_log_enabled do
        description "Enable the default Rails logger"
        default false
      end

      string :sentry_dsn do
        description "A DSN which should be used to report exceptions to Sentry"
      end

      boolean :enabled do
        description "Enable the Postal logger to log to STDOUT"
        default true
      end

      string :level do
        description "The minimum log level for the Postal logger (debug, info, warn, error, fatal)"
        default "INFO"
        transform do |value|
          normalized = value.to_s.strip.downcase
          normalized = "info" if normalized.empty?
          unless %w[debug info warn error fatal].include?(normalized)
            raise ArgumentError, "logging.level must be one of: debug, info, warn, error, fatal (got #{value.inspect})"
          end
          normalized
        end
      end

      boolean :highlighting_enabled do
        description "Enable highlighting of log lines"
        default false
      end
    end

    group :gelf do
      string :host do
        description "GELF-capable host to send logs to"
      end

      integer :port do
        description "GELF port to send logs to"
        default 12_201
      end

      string :facility do
        description "The facility name to add to all log entries sent to GELF"
        default "postal"
      end
    end

    group :smtp_server do
      integer :default_port do
        description "The default port the SMTP server should listen on unless overriden by the PORT environment variable"
        default 25
      end

      string :default_bind_address do
        description "The default bind address the SMTP server should listen on unless overriden by the BIND_ADDRESS environment variable"
        default "::"
      end

      integer :default_health_server_port do
        description "The default port for the SMTP server health server to listen on"
        default 9091
      end

      string :default_health_server_bind_address do
        description "The default bind address for the SMTP server health server to listen on"
        default "127.0.0.1"
      end

      boolean :tls_enabled do
        description "Enable TLS for the SMTP server (requires certificate)"
        default false
      end

      string :tls_certificate_path do
        description "The path to the SMTP server's TLS certificate"
        default "$config-file-root/smtp.cert"
        transform { |v| Postal.substitute_config_file_root(v) }
      end

      string :tls_private_key_path do
        description "The path to the SMTP server's TLS private key"
        default "$config-file-root/smtp.key"
        transform { |v| Postal.substitute_config_file_root(v) }
      end

      string :tls_ciphers do
        description "Override ciphers to use for SSL"
      end

      string :ssl_version do
        description "Deprecated. Set min_version and max_version instead"
        default "SSLv23"
      end

      string :min_version do
        description "The oldest TLS version the SMTP server will negotiate (1.0, 1.1, 1.2 or 1.3)"
        default "1.2"
      end

      string :max_version do
        description "The newest TLS version the SMTP server will negotiate (1.0, 1.1, 1.2 or 1.3)"
      end

      string :ciphersuites do
        description "Override the ciphersuites to use for TLS 1.3 (tls_ciphers applies to TLS 1.2 and below)"
      end

      boolean :proxy_protocol do
        description "Enable proxy protocol for use behind some load balancers (supports proxy protocol v1 only)"
        default false
      end

      boolean :log_connections do
        description "Enable connection logging"
        default false
      end

      integer :max_message_size do
        description "The maximum message size to accept from the SMTP server (in MB)"
        default 14
      end

      integer :max_recipients do
        description "The maximum number of recipients a client may send in a single transaction (0 for no limit)"
        default 100
      end

      integer :idle_timeout do
        description "Close an SMTP connection which has been idle for this many seconds (0 to disable)"
        default 300
      end

      string :log_ip_address_exclusion_matcher do
        description "A regular expression to use to exclude connections from logging"
      end
    end

    group :dns do
      string :mx_records do
        description "The names of the default MX records"
        array
        default ["mx1.postal.example.com", "mx2.postal.example.com"]
      end

      string :spf_include do
        description "The location of the SPF record"
        default "spf.postal.example.com"
      end

      string :return_path_domain do
        description "The return path hostname"
        default "rp.postal.example.com"
      end

      string :route_domain do
        description "The domain to use for hosting route-specific addresses"
        default "routes.postal.example.com"
      end

      string :track_domain do
        description "The CNAME which tracking domains should be pointed to"
        default "track.postal.example.com"
      end

      string :helo_hostname do
        description "The hostname to use in HELO/EHLO when connecting to external SMTP servers"
      end

      string :dkim_identifier do
        description "The identifier to use for DKIM keys in DNS records"
        default "postal"
      end

      integer :dkim_key_size do
        description "The size (in bits) of RSA key to generate for DKIM signing (one of 1024, 2048, 3072 or 4096). " \
                    "Note that records for 2048-bit and larger keys exceed 255 characters and must be " \
                    "published as a split (multi-string) TXT record."
        default 2048
        transform do |value|
          unless value.nil? || [1024, 2048, 3072, 4096].include?(value)
            raise Konfig::Error, "dns.dkim_key_size must be one of 1024, 2048, 3072 or 4096 (got #{value})"
          end

          value
        end
      end

      string :domain_verify_prefix do
        description "The prefix to add before TXT record verification string"
        default "postal-verification"
      end

      string :custom_return_path_prefix do
        description "The domain to use on external domains which points to the Postal return path domain"
        default "psrp"
      end

      string :dmarc_report_address do
        description "The address which aggregate DMARC reports should be sent to. Used when showing the " \
                    "recommended DMARC record for a domain. Postal does not store or apply a DMARC policy."
      end

      string :dmarc_failure_report_address do
        description "The address which failure DMARC reports should be sent to. Optional, and used when " \
                    "showing the recommended DMARC record for a domain."
      end

      string :tls_rpt_address do
        description "The destination which TLS-RPT reports for a domain should be sent to. Accepts a " \
                    "mailto: address or an https: endpoint, and may be a destination outside this " \
                    "installation."
      end

      string :tls_rpt_local_part do
        description "The local part of the address which accepts TLS reports for a domain hosted " \
                    "here, so that mail to <local part>@<domain> is ingested as a report rather " \
                    "than delivered. Leave empty to disable ingestion."
        default "tlsrpt"
      end

      integer :timeout do
        description "The timeout to wait for DNS resolution"
        default 5
      end

      string :resolv_conf_path do
        description "The path to the resolv.conf file containing addresses for local nameservers"
        default "/etc/resolv.conf"
      end
    end

    group :mta_sts do
      string :certificate_directory do
        description "The directory in which certificates for MTA-STS policy hosts are stored"
        default "$config-file-root/mta-sts-certs"
      end

      string :account_key_path do
        description "The path of the ACME account key used to request certificates"
        default "$config-file-root/acme-account.key"
      end

      string :acme_directory_url do
        description "The ACME directory to request certificates from"
        default "https://acme-v02.api.letsencrypt.org/directory"
      end

      string :contact_email do
        description "An optional contact address to register with the ACME account"
      end
    end

    group :smtp do
      string :host do
        description "The hostname to send application-level e-mails to"
        default "127.0.0.1"
      end

      integer :port do
        description "The port number to send application-level e-mails to"
        default 25
      end

      string :username do
        description "The username to use when authentication to the SMTP server"
      end

      string :password do
        description "The password to use when authentication to the SMTP server"
      end

      string :authentication_type do
        description "The type of authentication to use"
        default "login"
      end

      boolean :enable_starttls do
        description "Use STARTTLS when connecting to the SMTP server and fail if unsupported"
        default false
      end

      boolean :enable_starttls_auto do
        description "Detects if STARTTLS is enabled in the SMTP server and starts to use it"
        default true
      end

      string :openssl_verify_mode do
        description "When using TLS, you can set how OpenSSL checks the certificate. Use 'none' for no certificate checking"
        default "peer"
      end

      string :from_name do
        description "The name to use as the from name outgoing emails from Postal"
        default "Postal"
      end

      string :from_address do
        description "The e-mail to use as the from address outgoing emails from Postal"
        default "postal@example.com"
      end
    end

    group :rails do
      string :environment do
        description "The Rails environment to run the application in"
        default "production"
      end

      string :secret_key do
        description "The secret key used to sign and encrypt cookies and session data in the application"
      end
    end

    group :rspamd do
      boolean :enabled do
        description "Enable rspamd for message inspection"
        default false
      end

      string :host do
        description "The hostname of the rspamd server"
        default "127.0.0.1"
      end

      integer :port do
        description "The port of the rspamd server"
        default 11_334
      end

      boolean :ssl do
        description "Enable SSL for the rspamd connection"
        default false
      end

      string :password do
        description "The password for the rspamd server"
      end

      string :flags do
        description "Any flags for the rspamd server"
      end
    end

    group :spamd do
      boolean :enabled do
        description "Enable SpamAssassin for message inspection"
        default false
      end

      string :host do
        description "The hostname for the SpamAssassin server"
        default "127.0.0.1"
      end

      integer :port do
        description "The port of the SpamAssassin server"
        default 783
      end
    end

    group :clamav do
      boolean :enabled do
        description "Enable ClamAV for message inspection"
        default false
      end

      string :host do
        description "The host of the ClamAV server"
        default "127.0.0.1"
      end

      integer :port do
        description "The port of the ClamAV server"
        default 2000
      end
    end

    group :smtp_client do
      string :minimum_tls_version do
        description "The oldest TLS version to negotiate with remote servers. Lower this only to reach a server which cannot do better"
        default "1.2"
      end

      boolean :mta_sts do
        description "Deliver to a domain which publishes an MTA-STS policy only over verified TLS " \
                    "and only to the hosts that policy lists"
        default true
      end

      integer :open_timeout do
        description "The open timeout for outgoing SMTP connections"
        default 30
      end

      integer :read_timeout do
        description "The read timeout for outgoing SMTP connections"
        default 30
      end
    end

    group :protection do
      boolean :enabled do
        description "Enable rate limiting and brute-force protection for Postal's public endpoints"
        default true
      end

      string :counter_store do
        description "Where rate limit counters are kept. Use memory:// to count within this " \
                    "process, or redis://host:6379/0 (Valkey is accepted as valkey://host:6379/0) " \
                    "to share the counts between workers"
        default "memory://"
      end

      string :prefix do
        description "The prefix applied to every rate limit key"
        default "postal:limits"
      end

      integer :smtp_auth_attempts_limit do
        description "The number of SMTP authentication attempts allowed per IP address before it is refused"
        default 10
      end

      integer :smtp_auth_attempts_period do
        description "The period, in seconds, over which SMTP authentication attempts are counted and for which an address is refused"
        default 900
      end

      integer :smtp_connections_limit do
        description "The number of SMTP connections allowed per IP address within the period"
        default 60
      end

      integer :smtp_connections_period do
        description "The period, in seconds, over which SMTP connections per IP address are counted"
        default 60
      end

      integer :smtp_max_connections do
        description "The maximum number of concurrent SMTP connections (0 for no limit)"
        default 0
      end

      integer :api_auth_failures_limit do
        description "The number of failed API authentication attempts allowed per IP address"
        default 20
      end

      integer :api_auth_failures_period do
        description "The period, in seconds, over which failed API authentication attempts are counted"
        default 300
      end

      integer :web_login_failures_limit do
        description "The number of failed web login attempts allowed per address"
        default 10
      end

      integer :web_login_failures_period do
        description "The period, in seconds, over which failed web login attempts are counted"
        default 300
      end

      integer :web_password_reset_limit do
        description "The number of password reset requests allowed for one e-mail address, and " \
                    "from one client address, before they are refused"
        default 5
      end

      integer :web_password_reset_period do
        description "The period, in seconds, over which password reset requests are counted"
        default 900
      end

      string :quota_store do
        description "Where quota counters are kept. Defaults to the value of counter_store, so " \
                    "quotas share the same store as the failure counters unless isolated here. " \
                    "Accepts the same memory://, redis:// and valkey:// URLs"
      end

      string :quota_exceed_action do
        description "What happens when a quota is exceeded: reject refuses the request, defer " \
                    "queues it for a later retry where the caller supports it"
        default "reject"
        transform do |value|
          unless value.nil? || %w[reject defer].include?(value.to_s)
            raise Konfig::Error, "protection.quota_exceed_action must be reject or defer (got #{value})"
          end

          value&.to_s
        end
      end

      integer :api_send_limit do
        description "The number of API requests allowed per credential within the period (0 for no limit)"
        default 0
      end

      integer :api_send_period do
        description "The period, in seconds, over which API requests per credential are counted"
        default 3600
      end

      integer :smtp_send_limit do
        description "The number of messages allowed per SMTP credential within the period (0 for no limit)"
        default 0
      end

      integer :smtp_send_period do
        description "The period, in seconds, over which messages per SMTP credential are counted"
        default 3600
      end

      integer :smtp_ip_send_limit do
        description "The number of messages allowed per SMTP-IP credential within the period (0 for no limit)"
        default 0
      end

      integer :smtp_ip_send_period do
        description "The period, in seconds, over which messages per SMTP-IP credential are counted"
        default 3600
      end

      integer :reset_redeem_limit do
        description "The number of password reset redemptions allowed per client address before they are refused (0 for no limit)"
        default 0
      end

      integer :reset_redeem_period do
        description "The period, in seconds, over which password reset redemptions are counted"
        default 900
      end

      integer :unauth_intake_limit do
        description "The number of unauthenticated intake deliveries allowed per client address within the period (0 for no limit)"
        default 0
      end

      integer :unauth_intake_period do
        description "The period, in seconds, over which unauthenticated intake deliveries are counted"
        default 3600
      end
    end

    group :sessions do
      integer :inactivity_timeout do
        description "How long a session may sit unused, in seconds, before it is refused"
        default 43_200
      end

      integer :persistent_length do
        description "How long a remembered login lasts, in seconds"
        default 5_184_000
      end

      integer :sudo_timeout do
        description "How long a session may act, in seconds, after a password is confirmed"
        default 600
      end
    end

    group :migration_waiter do
      boolean :enabled do
        description "Wait for all migrations to run before starting a process"
        default false
      end

      integer :attempts do
        description "The number of attempts to try waiting for migrations to complete before start"
        default 120
      end

      integer :sleep_time do
        description "The number of seconds to wait between each migration check"
        default 2
      end
    end

    group :oidc do
      boolean :enabled do
        description "Enable OIDC authentication"
        default false
      end

      boolean :local_authentication_enabled do
        description "When enabled, users with passwords will still be able to login locally. If disable, only OpenID Connect will be available."
        default true
      end

      string :name do
        description "The name of the OIDC provider as shown in the UI"
        default "OIDC Provider"
      end

      string :issuer do
        description "The OIDC issuer URL"
      end

      string :identifier do
        description "The client ID for OIDC"
      end

      string :secret do
        description "The client secret for OIDC"
      end

      string :scopes do
        description "Scopes to request from the OIDC server."
        array
        default ["openid", "email"]
      end

      string :uid_field do
        description "The field to use to determine the user's UID"
        default "sub"
      end

      string :email_address_field do
        description "The field to use to determine the user's email address"
        default "email"
      end

      string :name_field do
        description "The field to use to determine the user's name"
        default "name"
      end

      boolean :discovery do
        description "Enable discovery to determine endpoints from .well-known/openid-configuration from the Issuer"
        default true
      end

      string :authorization_endpoint do
        description "The authorize endpoint on the authorization server (only used when discovery is false)"
      end

      string :token_endpoint do
        description "The token endpoint on the authorization server (only used when discovery is false)"
      end

      string :userinfo_endpoint do
        description "The user info endpoint on the authorization server (only used when discovery is false)"
      end

      string :jwks_uri do
        description "The JWKS endpoint on the authorization server (only used when discovery is false)"
      end
    end
  end

  class << self

    def substitute_config_file_root(string)
      return if string.nil?

      string.gsub(/\$config-file-root/i, File.dirname(Postal.config_file_path))
    end

  end

end
