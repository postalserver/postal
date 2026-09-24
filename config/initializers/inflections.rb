# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "ACME"
  inflect.acronym "DKIM"
  inflect.acronym "HTTP"
  inflect.acronym "OIDC"
  inflect.acronym "SMTP"
  inflect.acronym "UUID"

  inflect.acronym "API"
  inflect.acronym "DNS"
  inflect.acronym "SSL"
  inflect.acronym "TLS"
  inflect.acronym "MySQL"
  inflect.acronym "PostgreSQL"
  inflect.acronym "DuckDB"
  inflect.acronym "FoundationDB"
  inflect.acronym "ClickHouse"
  inflect.acronym "SQLite"
  inflect.acronym "VictoriaMetrics"

  inflect.acronym "DB"
  inflect.acronym "IP"
  inflect.acronym "MQ"
  inflect.acronym "MTA"
  inflect.acronym "MX"
end
