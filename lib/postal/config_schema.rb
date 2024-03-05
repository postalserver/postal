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
        default "config/postal/signing.key"
      end

      string :smtp_relays do
        array
        description "An array of SMTP relays in the format of smtp://host:port"
        transform do |value|
          uri = URI.parse(value)
          query = uri.query ? CGI.parse(uri.query) : {}
          {
            host: uri.host,
            port: uri.port || 25,
            ssl_mode: query["ssl_mode"]&.first || "Auto"
          }
        end
      end

      string :trusted_proxies do
        array
        description "An array of IP addresses to trust for proxying requests to Postal (in addition to localhost addresses)"
        transform { |ip| IPAddr.new(ip) }
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

      string :encoding do
        description "The encoding to use when connecting to the MariaDB database"
        default "utf8mb4"
      end

      string :database_name_prefix do
        description "The MariaDB prefix to add to database names"
        default "postal"
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
        default "127.0.0.1"
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
        default "config/postal/smtp.cert"
      end

      string :tls_private_key_path do
        description "The path to the SMTP server's TLS private key"
        default "config/postal/smtp.key"
      end

      string :tls_ciphers do
        description "Override ciphers to use for SSL"
      end

      string :ssl_version do
        description "The SSL versions which are supported"
        default "SSLv23"
      end

      boolean :proxy_protocol do
        description "Enable proxy protocol for use behind some load balancers"
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

      string :domain_verify_prefix do
        description "The prefix to add before TXT record verification string"
        default "postal-verification"
      end

      string :custom_return_path_prefix do
        description "The domain to use on external domains which points to the Postal return path domain"
        default "psrp"
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
      integer :open_timeout do
        description "The open timeout for outgoing SMTP connections"
        default 30
      end

      integer :read_timeout do
        description "The read timeout for outgoing SMTP connections"
        default 30
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
  end

end
