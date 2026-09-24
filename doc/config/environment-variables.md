# Environment Variables

This document contains all the environment variables which are available for this application.

| Name | Type | Description | Default |
| ---- | ---- | ----------- | ------- |
| `POSTAL_WEB_HOSTNAME` | String | The hostname that the Postal web interface runs on | postal.example.com |
| `POSTAL_WEB_PROTOCOL` | String | The HTTP protocol to use for the Postal web interface | https |
| `POSTAL_SMTP_HOSTNAME` | String | The hostname that the Postal SMTP server runs on | postal.example.com |
| `POSTAL_USE_IP_POOLS` | Boolean | Should IP pools be enabled for this installation? | false |
| `POSTAL_DEFAULT_MAXIMUM_DELIVERY_ATTEMPTS` | Integer | The maximum number of delivery attempts | 18 |
| `POSTAL_DEFAULT_MAXIMUM_HOLD_EXPIRY_DAYS` | Integer | The number of days to hold a message before they will be expired | 7 |
| `POSTAL_DEFAULT_SUPPRESSION_LIST_AUTOMATIC_REMOVAL_DAYS` | Integer | The number of days an address will remain in a suppression list before being removed | 30 |
| `POSTAL_DEFAULT_SPAM_THRESHOLD` | Integer | The default threshold at which a message should be treated as spam | 5 |
| `POSTAL_DEFAULT_SPAM_FAILURE_THRESHOLD` | Integer | The default threshold at which a message should be treated as spam failure | 20 |
| `POSTAL_USE_LOCAL_NS_FOR_DOMAIN_VERIFICATION` | Boolean | Domain verification and checking usually checks with a domain's nameserver. Enable this to check with the server's local nameservers. | false |
| `POSTAL_USE_RESENT_SENDER_HEADER` | Boolean | Append a Resend-Sender header to all outgoing e-mails | true |
| `POSTAL_SIGNING_KEY_PATH` | String | Path to the private key used for signing | $config-file-root/signing.key |
| `POSTAL_SMTP_RELAYS` | Array of strings | An array of SMTP relays in the format of smtp://user:password@host:port?ssl_mode=Auto&auth=plain. The credentials and the auth mechanism are optional; auth may be plain, login or cram_md5 and defaults to the strongest mechanism the relay advertises | [] |
| `POSTAL_TRUSTED_PROXIES` | Array of strings | An array of IP addresses to trust for proxying requests to Postal (in addition to localhost addresses) | [] |
| `POSTAL_ALLOWED_REQUEST_DESTINATIONS` | Array of strings | Hostnames or IP/CIDR ranges that outbound webhook and HTTP endpoint requests are permitted to reach even when they resolve to a private, loopback, link-local or otherwise reserved address. All other such destinations are blocked to prevent SSRF. | [] |
| `POSTAL_QUEUED_MESSAGE_LOCK_STALE_DAYS` | Integer | The number of days after which to consider a lock as stale. Messages with stale locks will be removed and not retried. | 1 |
| `POSTAL_BATCH_QUEUED_MESSAGES` | Boolean | When enabled queued messages will be de-queued in batches based on their destination | true |
| `WEB_SERVER_DEFAULT_PORT` | Integer | The default port the web server should listen on unless overriden by the PORT environment variable | 5000 |
| `WEB_SERVER_DEFAULT_BIND_ADDRESS` | String | The default bind address the web server should listen on unless overriden by the BIND_ADDRESS environment variable | 127.0.0.1 |
| `WEB_SERVER_MAX_THREADS` | Integer | The maximum number of threads which can be used by the web server | 5 |
| `WORKER_DEFAULT_HEALTH_SERVER_PORT` | Integer | The default port for the worker health server to listen on | 9090 |
| `WORKER_DEFAULT_HEALTH_SERVER_BIND_ADDRESS` | String | The default bind address for the worker health server to listen on | 127.0.0.1 |
| `WORKER_THREADS` | Integer | The number of threads to execute within each worker | 2 |
| `MAIN_DB_HOST` | String | Hostname for the main MariaDB server | localhost |
| `MAIN_DB_PORT` | Integer | The MariaDB port to connect to | 3306 |
| `MAIN_DB_USERNAME` | String | The MariaDB username | postal |
| `MAIN_DB_PASSWORD` | String | The MariaDB password |  |
| `MAIN_DB_DATABASE` | String | The MariaDB database name | postal |
| `MAIN_DB_POOL_SIZE` | Integer | The maximum size of the MariaDB connection pool | 5 |
| `MAIN_DB_ENCODING` | String | The encoding to use when connecting to the MariaDB database | utf8mb4 |
| `MESSAGE_DB_HOST` | String | Hostname for the MariaDB server which stores the mail server databases | localhost |
| `MESSAGE_DB_PORT` | Integer | The MariaDB port to connect to | 3306 |
| `MESSAGE_DB_USERNAME` | String | The MariaDB username | postal |
| `MESSAGE_DB_PASSWORD` | String | The MariaDB password |  |
| `MESSAGE_DB_DATABASE` | String | The database to connect to for engines which need one: the PostgreSQL database which holds each server's schema, or the directory holding the per-server files for SQLite. Not used by MySQL/MariaDB, which keeps each server in its own database. |  |
| `MESSAGE_DB_ENCODING` | String | The encoding to use when connecting to the MariaDB database | utf8mb4 |
| `MESSAGE_DB_DATABASE_NAME_PREFIX` | String | The MariaDB prefix to add to database names | postal |
| `MESSAGE_DB_RAW_MESSAGE_CHUNK_SIZE` | Integer | The maximum number of bytes from a raw message stored in a single database row (in bytes). Larger messages are split across multiple rows so that no single query exceeds the server's max_allowed_packet limit. Lower this if your database server uses a small max_allowed_packet. | 4194304 |
| `MESSAGE_DB_ADAPTER` | String | The database engine used for the per-server message databases. Either 'mysql' (MySQL/MariaDB), 'postgresql' or 'sqlite'. | mysql |
| `BLOB_STORE_URL` | String | Where the bodies of large raw messages are stored. The scheme selects the backend: 'inline://' (the default) keeps them in the message database, 'filesystem:///var/lib/postal/blobs?depth=2' writes them to disk, 's3://bucket/prefix' uses an S3-compatible bucket, and 'foundationdb://' uses a FoundationDB cluster. | inline:// |
| `BLOB_STORE_THRESHOLD` | Integer | The minimum size of a message body (in bytes) before it is stored in the blob store rather than inline in the message database | 1048576 |
| `ANALYTICS_URL` | String | Where the daily analytics extract is written. The scheme selects the sink: 'duckdb:///var/lib/postal/analytics' (embedded), 'clickhouse://user:pass@host:8123/database', 'prometheus+http://host:8428' or 'influx+http://host:8086/database'. Leave unset to disable analytics. |  |
| `LIVE_STATS_URL` | String | Where the live statistics (the last 60 minutes of message counts, shown on Postal's own dashboard) are kept. The scheme selects the store: 'mysql://' (the default) keeps them in the message database, 'valkey://host:6379/0' (or 'redis://', or any store speaking the Redis protocol) and 'aerospike://host:3000/namespace/set' use an in-memory store, and 'prometheus+http://host:8428' uses a Prometheus-compatible time-series store which can also stream to the dashboard as messages flow. The 'influx' and 'json' schemes are write-only: they accept the extract but cannot be read back by the dashboard. | mysql:// |
| `LIVE_STATS_WINDOW` | Integer | The number of seconds of recent statistics a live query covers | 3600 |
| `TELEMETRY_URL` | String | Where Postal pushes metrics and events as they happen, for external dashboards and alerting. The scheme selects the protocol and endpoint: 'prometheus+http://host:8428' (a Prometheus-compatible store such as VictoriaMetrics or Prometheus), 'influx+http://host:8086/database' or 'json+http://host:8686' (for example a vector.dev http_server source). Unset to disable telemetry. |  |
| `TELEMETRY_INTERVAL` | Integer | The number of seconds between telemetry flushes | 15 |
| `TELEMETRY_BATCH_SIZE` | Integer | The maximum number of telemetry samples sent in a single request | 1000 |
| `TELEMETRY_QUEUE_SIZE` | Integer | The maximum number of telemetry samples buffered in memory before the oldest are dropped | 10000 |
| `LOGGING_RAILS_LOG_ENABLED` | Boolean | Enable the default Rails logger | false |
| `LOGGING_SENTRY_DSN` | String | A DSN which should be used to report exceptions to Sentry |  |
| `LOGGING_ENABLED` | Boolean | Enable the Postal logger to log to STDOUT | true |
| `LOGGING_LEVEL` | String | The minimum log level for the Postal logger (debug, info, warn, error, fatal) | INFO |
| `LOGGING_HIGHLIGHTING_ENABLED` | Boolean | Enable highlighting of log lines | false |
| `GELF_HOST` | String | GELF-capable host to send logs to |  |
| `GELF_PORT` | Integer | GELF port to send logs to | 12201 |
| `GELF_FACILITY` | String | The facility name to add to all log entries sent to GELF | postal |
| `SMTP_SERVER_DEFAULT_PORT` | Integer | The default port the SMTP server should listen on unless overriden by the PORT environment variable | 25 |
| `SMTP_SERVER_DEFAULT_BIND_ADDRESS` | String | The default bind address the SMTP server should listen on unless overriden by the BIND_ADDRESS environment variable | :: |
| `SMTP_SERVER_DEFAULT_HEALTH_SERVER_PORT` | Integer | The default port for the SMTP server health server to listen on | 9091 |
| `SMTP_SERVER_DEFAULT_HEALTH_SERVER_BIND_ADDRESS` | String | The default bind address for the SMTP server health server to listen on | 127.0.0.1 |
| `SMTP_SERVER_TLS_ENABLED` | Boolean | Enable TLS for the SMTP server (requires certificate) | false |
| `SMTP_SERVER_TLS_CERTIFICATE_PATH` | String | The path to the SMTP server's TLS certificate | $config-file-root/smtp.cert |
| `SMTP_SERVER_TLS_PRIVATE_KEY_PATH` | String | The path to the SMTP server's TLS private key | $config-file-root/smtp.key |
| `SMTP_SERVER_TLS_CIPHERS` | String | Override ciphers to use for SSL |  |
| `SMTP_SERVER_SSL_VERSION` | String | Deprecated. Set min_version and max_version instead | SSLv23 |
| `SMTP_SERVER_MIN_VERSION` | String | The oldest TLS version the SMTP server will negotiate (1.0, 1.1, 1.2 or 1.3) | 1.2 |
| `SMTP_SERVER_MAX_VERSION` | String | The newest TLS version the SMTP server will negotiate (1.0, 1.1, 1.2 or 1.3) |  |
| `SMTP_SERVER_CIPHERSUITES` | String | Override the ciphersuites to use for TLS 1.3 (tls_ciphers applies to TLS 1.2 and below) |  |
| `SMTP_SERVER_PROXY_PROTOCOL` | Boolean | Enable proxy protocol for use behind some load balancers (supports proxy protocol v1 only) | false |
| `SMTP_SERVER_LOG_CONNECTIONS` | Boolean | Enable connection logging | false |
| `SMTP_SERVER_MAX_MESSAGE_SIZE` | Integer | The maximum message size to accept from the SMTP server (in MB) | 14 |
| `SMTP_SERVER_MAX_RECIPIENTS` | Integer | The maximum number of recipients a client may send in a single transaction (0 for no limit) | 100 |
| `SMTP_SERVER_IDLE_TIMEOUT` | Integer | Close an SMTP connection which has been idle for this many seconds (0 to disable) | 300 |
| `SMTP_SERVER_LOG_IP_ADDRESS_EXCLUSION_MATCHER` | String | A regular expression to use to exclude connections from logging |  |
| `DNS_MX_RECORDS` | Array of strings | The names of the default MX records | ["mx1.postal.example.com", "mx2.postal.example.com"] |
| `DNS_SPF_INCLUDE` | String | The location of the SPF record | spf.postal.example.com |
| `DNS_RETURN_PATH_DOMAIN` | String | The return path hostname | rp.postal.example.com |
| `DNS_ROUTE_DOMAIN` | String | The domain to use for hosting route-specific addresses | routes.postal.example.com |
| `DNS_TRACK_DOMAIN` | String | The CNAME which tracking domains should be pointed to | track.postal.example.com |
| `DNS_HELO_HOSTNAME` | String | The hostname to use in HELO/EHLO when connecting to external SMTP servers |  |
| `DNS_DKIM_IDENTIFIER` | String | The identifier to use for DKIM keys in DNS records | postal |
| `DNS_DKIM_KEY_SIZE` | Integer | The size (in bits) of RSA key to generate for DKIM signing (one of 1024, 2048, 3072 or 4096). Note that records for 2048-bit and larger keys exceed 255 characters and must be published as a split (multi-string) TXT record. | 2048 |
| `DNS_DOMAIN_VERIFY_PREFIX` | String | The prefix to add before TXT record verification string | postal-verification |
| `DNS_CUSTOM_RETURN_PATH_PREFIX` | String | The domain to use on external domains which points to the Postal return path domain | psrp |
| `DNS_DMARC_REPORT_ADDRESS` | String | The address which aggregate DMARC reports should be sent to. Used when showing the recommended DMARC record for a domain. Postal does not store or apply a DMARC policy. |  |
| `DNS_DMARC_FAILURE_REPORT_ADDRESS` | String | The address which failure DMARC reports should be sent to. Optional, and used when showing the recommended DMARC record for a domain. |  |
| `DNS_TLS_RPT_ADDRESS` | String | The destination which TLS-RPT reports for a domain should be sent to. Accepts a mailto: address or an https: endpoint, and may be a destination outside this installation. |  |
| `DNS_TLS_RPT_LOCAL_PART` | String | The local part of the address which accepts TLS reports for a domain hosted here, so that mail to <local part>@<domain> is ingested as a report rather than delivered. Leave empty to disable ingestion. | tlsrpt |
| `DNS_TIMEOUT` | Integer | The timeout to wait for DNS resolution | 5 |
| `DNS_RESOLV_CONF_PATH` | String | The path to the resolv.conf file containing addresses for local nameservers | /etc/resolv.conf |
| `MTA_STS_CERTIFICATE_DIRECTORY` | String | The directory in which certificates for MTA-STS policy hosts are stored | $config-file-root/mta-sts-certs |
| `MTA_STS_ACCOUNT_KEY_PATH` | String | The path of the ACME account key used to request certificates | $config-file-root/acme-account.key |
| `MTA_STS_ACME_DIRECTORY_URL` | String | The ACME directory to request certificates from | https://acme-v02.api.letsencrypt.org/directory |
| `MTA_STS_CONTACT_EMAIL` | String | An optional contact address to register with the ACME account |  |
| `SMTP_HOST` | String | The hostname to send application-level e-mails to | 127.0.0.1 |
| `SMTP_PORT` | Integer | The port number to send application-level e-mails to | 25 |
| `SMTP_USERNAME` | String | The username to use when authentication to the SMTP server |  |
| `SMTP_PASSWORD` | String | The password to use when authentication to the SMTP server |  |
| `SMTP_AUTHENTICATION_TYPE` | String | The type of authentication to use | login |
| `SMTP_ENABLE_STARTTLS` | Boolean | Use STARTTLS when connecting to the SMTP server and fail if unsupported | false |
| `SMTP_ENABLE_STARTTLS_AUTO` | Boolean | Detects if STARTTLS is enabled in the SMTP server and starts to use it | true |
| `SMTP_OPENSSL_VERIFY_MODE` | String | When using TLS, you can set how OpenSSL checks the certificate. Use 'none' for no certificate checking | peer |
| `SMTP_FROM_NAME` | String | The name to use as the from name outgoing emails from Postal | Postal |
| `SMTP_FROM_ADDRESS` | String | The e-mail to use as the from address outgoing emails from Postal | postal@example.com |
| `RAILS_ENVIRONMENT` | String | The Rails environment to run the application in | production |
| `RAILS_SECRET_KEY` | String | The secret key used to sign and encrypt cookies and session data in the application |  |
| `RSPAMD_ENABLED` | Boolean | Enable rspamd for message inspection | false |
| `RSPAMD_HOST` | String | The hostname of the rspamd server | 127.0.0.1 |
| `RSPAMD_PORT` | Integer | The port of the rspamd server | 11334 |
| `RSPAMD_SSL` | Boolean | Enable SSL for the rspamd connection | false |
| `RSPAMD_PASSWORD` | String | The password for the rspamd server |  |
| `RSPAMD_FLAGS` | String | Any flags for the rspamd server |  |
| `SPAMD_ENABLED` | Boolean | Enable SpamAssassin for message inspection | false |
| `SPAMD_HOST` | String | The hostname for the SpamAssassin server | 127.0.0.1 |
| `SPAMD_PORT` | Integer | The port of the SpamAssassin server | 783 |
| `CLAMAV_ENABLED` | Boolean | Enable ClamAV for message inspection | false |
| `CLAMAV_HOST` | String | The host of the ClamAV server | 127.0.0.1 |
| `CLAMAV_PORT` | Integer | The port of the ClamAV server | 2000 |
| `SMTP_CLIENT_MINIMUM_TLS_VERSION` | String | The oldest TLS version to negotiate with remote servers. Lower this only to reach a server which cannot do better | 1.2 |
| `SMTP_CLIENT_MTA_STS` | Boolean | Deliver to a domain which publishes an MTA-STS policy only over verified TLS and only to the hosts that policy lists | true |
| `SMTP_CLIENT_OPEN_TIMEOUT` | Integer | The open timeout for outgoing SMTP connections | 30 |
| `SMTP_CLIENT_READ_TIMEOUT` | Integer | The read timeout for outgoing SMTP connections | 30 |
| `PROTECTION_ENABLED` | Boolean | Enable rate limiting and brute-force protection for Postal's public endpoints | true |
| `PROTECTION_COUNTER_STORE` | String | Where rate limit counters are kept. Use memory:// to count within this process, or redis://host:6379/0 (Valkey is accepted as valkey://host:6379/0) to share the counts between workers | memory:// |
| `PROTECTION_PREFIX` | String | The prefix applied to every rate limit key | postal:limits |
| `PROTECTION_SMTP_AUTH_ATTEMPTS_LIMIT` | Integer | The number of SMTP authentication attempts allowed per IP address before it is refused | 10 |
| `PROTECTION_SMTP_AUTH_ATTEMPTS_PERIOD` | Integer | The period, in seconds, over which SMTP authentication attempts are counted and for which an address is refused | 900 |
| `PROTECTION_SMTP_CONNECTIONS_LIMIT` | Integer | The number of SMTP connections allowed per IP address within the period | 60 |
| `PROTECTION_SMTP_CONNECTIONS_PERIOD` | Integer | The period, in seconds, over which SMTP connections per IP address are counted | 60 |
| `PROTECTION_SMTP_MAX_CONNECTIONS` | Integer | The maximum number of concurrent SMTP connections (0 for no limit) | 0 |
| `PROTECTION_API_AUTH_FAILURES_LIMIT` | Integer | The number of failed API authentication attempts allowed per IP address | 20 |
| `PROTECTION_API_AUTH_FAILURES_PERIOD` | Integer | The period, in seconds, over which failed API authentication attempts are counted | 300 |
| `PROTECTION_WEB_LOGIN_FAILURES_LIMIT` | Integer | The number of failed web login attempts allowed per address | 10 |
| `PROTECTION_WEB_LOGIN_FAILURES_PERIOD` | Integer | The period, in seconds, over which failed web login attempts are counted | 300 |
| `PROTECTION_WEB_PASSWORD_RESET_LIMIT` | Integer | The number of password reset requests allowed for one e-mail address, and from one client address, before they are refused | 5 |
| `PROTECTION_WEB_PASSWORD_RESET_PERIOD` | Integer | The period, in seconds, over which password reset requests are counted | 900 |
| `PROTECTION_QUOTA_STORE` | String | Where quota counters are kept. Defaults to the value of counter_store, so quotas share the same store as the failure counters unless isolated here. Accepts the same memory://, redis:// and valkey:// URLs |  |
| `PROTECTION_QUOTA_EXCEED_ACTION` | String | What happens when a quota is exceeded: reject refuses the request, defer queues it for a later retry where the caller supports it | reject |
| `PROTECTION_API_SEND_LIMIT` | Integer | The number of API requests allowed per credential within the period (0 for no limit) | 0 |
| `PROTECTION_API_SEND_PERIOD` | Integer | The period, in seconds, over which API requests per credential are counted | 3600 |
| `PROTECTION_SMTP_SEND_LIMIT` | Integer | The number of messages allowed per SMTP credential within the period (0 for no limit) | 0 |
| `PROTECTION_SMTP_SEND_PERIOD` | Integer | The period, in seconds, over which messages per SMTP credential are counted | 3600 |
| `PROTECTION_SMTP_IP_SEND_LIMIT` | Integer | The number of messages allowed per SMTP-IP credential within the period (0 for no limit) | 0 |
| `PROTECTION_SMTP_IP_SEND_PERIOD` | Integer | The period, in seconds, over which messages per SMTP-IP credential are counted | 3600 |
| `PROTECTION_RESET_REDEEM_LIMIT` | Integer | The number of password reset redemptions allowed per client address before they are refused (0 for no limit) | 0 |
| `PROTECTION_RESET_REDEEM_PERIOD` | Integer | The period, in seconds, over which password reset redemptions are counted | 900 |
| `PROTECTION_UNAUTH_INTAKE_LIMIT` | Integer | The number of unauthenticated intake deliveries allowed per client address within the period (0 for no limit) | 0 |
| `PROTECTION_UNAUTH_INTAKE_PERIOD` | Integer | The period, in seconds, over which unauthenticated intake deliveries are counted | 3600 |
| `SESSIONS_INACTIVITY_TIMEOUT` | Integer | How long a session may sit unused, in seconds, before it is refused | 43200 |
| `SESSIONS_PERSISTENT_LENGTH` | Integer | How long a remembered login lasts, in seconds | 5184000 |
| `SESSIONS_SUDO_TIMEOUT` | Integer | How long a session may act, in seconds, after a password is confirmed | 600 |
| `MIGRATION_WAITER_ENABLED` | Boolean | Wait for all migrations to run before starting a process | false |
| `MIGRATION_WAITER_ATTEMPTS` | Integer | The number of attempts to try waiting for migrations to complete before start | 120 |
| `MIGRATION_WAITER_SLEEP_TIME` | Integer | The number of seconds to wait between each migration check | 2 |
| `OIDC_ENABLED` | Boolean | Enable OIDC authentication | false |
| `OIDC_LOCAL_AUTHENTICATION_ENABLED` | Boolean | When enabled, users with passwords will still be able to login locally. If disable, only OpenID Connect will be available. | true |
| `OIDC_NAME` | String | The name of the OIDC provider as shown in the UI | OIDC Provider |
| `OIDC_ISSUER` | String | The OIDC issuer URL |  |
| `OIDC_IDENTIFIER` | String | The client ID for OIDC |  |
| `OIDC_SECRET` | String | The client secret for OIDC |  |
| `OIDC_SCOPES` | Array of strings | Scopes to request from the OIDC server. | ["openid", "email"] |
| `OIDC_UID_FIELD` | String | The field to use to determine the user's UID | sub |
| `OIDC_EMAIL_ADDRESS_FIELD` | String | The field to use to determine the user's email address | email |
| `OIDC_NAME_FIELD` | String | The field to use to determine the user's name | name |
| `OIDC_DISCOVERY` | Boolean | Enable discovery to determine endpoints from .well-known/openid-configuration from the Issuer | true |
| `OIDC_AUTHORIZATION_ENDPOINT` | String | The authorize endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_TOKEN_ENDPOINT` | String | The token endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_USERINFO_ENDPOINT` | String | The user info endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_JWKS_URI` | String | The JWKS endpoint on the authorization server (only used when discovery is false) |  |
