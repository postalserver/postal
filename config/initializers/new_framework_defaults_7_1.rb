# frozen_string_literal: true

# Be sure to restart your server when you modify this file.
#
# This file eases your Rails 7.1 framework defaults upgrade.
#
# Uncomment each configuration one by one to switch to the new default.
# Once your application is ready to run with all new defaults, you can remove
# this file and set the `config.load_defaults` to `7.1`.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.
# https://guides.rubyonrails.org/upgrading_ruby_on_rails.html

###
# No longer add autoloaded paths into `$LOAD_PATH`. This means that you won't be able
# to manually require files that are managed by the autoloader, which you shouldn't do anyway.
#
# This will reduce the size of the load path, making `require` faster if you don't use bootsnap, or reduce the size
# of the bootsnap cache if you use it.
#++
# Rails.application.config.add_autoload_paths_to_load_path = false

###
# Remove the default X-Download-Options header since it is used only by Internet Explorer.
# If you need to support Internet Explorer, add back `"X-Download-Options" => "noopen"`.
#++
# Rails.application.config.action_dispatch.default_headers = {
#   "X-Frame-Options" => "SAMEORIGIN",
#   "X-XSS-Protection" => "0",
#   "X-Content-Type-Options" => "nosniff",
#   "X-Permitted-Cross-Domain-Policies" => "none",
#   "Referrer-Policy" => "strict-origin-when-cross-origin"
# }

###
# Do not treat an `ActiveSupport::Duration` as a number of seconds when it is
# used as a cache expiry. Raise instead, because the intent is ambiguous.
#++
# Rails.application.config.active_support.raise_on_invalid_cache_expiration_time = true

###
# Specify the default serializer used by `MessageEncryptor` and `MessageVerifier`
# instances.
#
# The legacy default is `:marshal`, which is a potential vector for
# deserialization attacks in cases where a message signing secret has been
# leaked.
#
# In Rails 7.1, the new default is `:json_allow_marshal`, which serializes and
# deserializes with `ActiveSupport::JSON`, but can fall back to deserializing
# with `Marshal` so that legacy messages can still be read.
#
# In Rails 7.2, the default will become `:json`, which serializes and
# deserializes with `ActiveSupport::JSON` only.
#
# Alternatively, you can choose `:message_pack` or `:message_pack_allow_marshal`,
# which serialize with `ActiveSupport::MessagePack`. `ActiveSupport::MessagePack`
# can roundtrip some Ruby types that are not supported by JSON, and may provide
# improved performance, but it requires the `msgpack` gem.
#
# For more information, see
# https://guides.rubyonrails.org/v7.1/configuring.html#config-active-support-message-serializer
#
# NOTE: Changing this affects the session cookie and any other signed or
# encrypted message. Deploy `:json_allow_marshal` everywhere before considering
# `:json`, and be aware that rolling back to a version which cannot read the new
# format will invalidate existing sessions.
#++
# Rails.application.config.active_support.message_serializer = :json_allow_marshal

###
# Enable a performance optimization that serializes message data and metadata
# together. This changes the message format, so messages serialized this way
# cannot be read by older versions of Rails. However, messages that use the old
# format can still be read, regardless of whether this optimization is enabled.
#
# To perform a rolling deploy of a Rails 7.1 upgrade, wherein servers that have
# not yet been upgraded must be able to read messages from upgraded servers, leave
# this optimization off on the first deploy, then enable it on a subsequent deploy.
#++
# Rails.application.config.active_support.use_message_serializer_for_metadata = true

###
# Set the maximum size for Rails log files.
#
# `config.load_defaults "7.1"` does not set this value for environments other than
# development and test.
#++
# if Rails.env.local?
#   Rails.application.config.log_file_size = 100 * 1024 * 1024
# end

###
# Enable raising on assignment to attr_readonly attributes. The previous behavior
# would allow assignment but silently not persist changes to the database.
#++
# Rails.application.config.active_record.raise_on_assign_to_attr_readonly = true

###
# Enable validating only parent-related columns for presence when the parent is mandatory.
# The previous behavior was to validate the presence of the parent record, which performed an extra query
# to get the parent every time the child record was updated, even when parent has not changed.
#++
# Rails.application.config.active_record.belongs_to_required_validates_foreign_key = false

###
# Enable preloading of the `before_committed!` callbacks on all records in a transaction,
# instead of only the first copy of a record.
#++
# Rails.application.config.active_record.before_committed_on_all_records = true

###
# Disable deprecated singular associations names.
#++
# Rails.application.config.active_record.allow_deprecated_singular_associations_name = false

###
# Enable running `after_commit` callbacks in the order they are defined,
# rather than in reverse order.
#++
# Rails.application.config.active_record.run_after_transaction_callbacks_in_order_defined = true

###
# Run `after_commit` and `after_rollback` callbacks on the first saved instance
# of a record in a transaction, rather than the instance which was saved last.
#++
# Rails.application.config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction = false

###
# Configure the query log tags to use the SQLCommenter format.
#++
# Rails.application.config.active_record.query_log_tags_format = :sqlcommenter

###
# Specify the default serializer used by `ActiveRecord::Base#serialize`.
#
# `nil` means there is no default, so every `serialize` call must declare its
# `coder:` explicitly. This app already does that, so this option is safe to
# enable. Do not remove those explicit coders.
#++
# Rails.application.config.active_record.default_column_serializer = nil

###
# Use a 7.1-compatible marshalling format when caching Active Record objects.
#
# This format is more efficient, but cannot be read by Rails 7.0 and earlier, so
# do not enable this until every process is running 7.1 or later.
#++
# Rails.application.config.active_record.marshalling_format_version = 7.1

###
# Generate a `has_secure_token` value when the record is initialized rather than
# when it is created.
#++
# Rails.application.config.active_record.generate_secure_token_on = :initialize

###
# Use a modern HTML5 sanitizer (via Nokogiri's HTML5 parser) rather than the
# legacy HTML4 one, where it is supported.
#
# This changes how malformed markup is parsed and sanitized. Review anywhere the
# application sanitizes user-supplied HTML before enabling it.
#++
# Rails.application.config.action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor

###
# Parse HTML in tests with an HTML5 parser rather than an HTML4 one.
#++
# Rails.application.config.dom_testing_default_html_version = :html5

###
# Precompile the filter parameters (`config.filter_parameters`) so that filtering
# is faster at request time.
#++
# Rails.application.config.precompile_filter_parameters = true

###
# Log exceptions that are handled by `rescue_from` (or otherwise rendered as an
# error page) at the `error` level rather than `fatal`.
#++
# Rails.application.config.action_dispatch.debug_exception_log_level = :error

###
# Change the cache entry format, so that new entries are written in a format
# which Rails 7.0 and earlier cannot read.
#
# Only enable this once every process is running 7.1 or later, and you have no
# plans to roll back.
#++
# Rails.application.config.active_support.cache_format_version = 7.1

###
# Use SHA-256 to derive Active Record Encryption keys and stop supporting SHA-1
# for non-deterministic encryption.
#
# This app does not currently use Active Record Encryption. If that changes,
# read the upgrade guide before enabling these.
#++
# Rails.application.config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA256
# Rails.application.config.active_record.encryption.support_sha1_for_non_deterministic_encryption = false
