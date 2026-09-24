# frozen_string_literal: true

module Postal
  #
  # Rate limiting for Postal's public entry points: SMTP authentication, the
  # inbound SMTP listener, the API and web login.
  #
  # A limit is a count over a period against a namespaced key. The window starts
  # when the first event is counted and lasts for the period, so a limit of ten
  # failures per five minutes means ten failures from the first one, not ten
  # failures in whichever five-minute block the clock happens to be in.
  #
  # Counters are held in the process that counts them. That is exact for a
  # deployment with a single worker per service, which is the default; a
  # deployment running several workers would need a shared store, and the store
  # is therefore replaceable rather than hard-coded.
  #
  module RateLimiter

    class Error < StandardError; end

    #
    # The outcome of counting one event against a limit.
    #
    Result = Struct.new(:hits, :limit, :retry_after) do
      def allowed?
        hits <= limit
      end

      def exceeded?
        !allowed?
      end

      def remaining
        [limit - hits, 0].max
      end
    end

    # Returned when the limiter is switched off: nothing is counted and nothing
    # is refused.
    UNLIMITED = Result.new(0, Float::INFINITY, 0).freeze

    #
    # A quota is a named use limit: which key to count, where its limit and
    # period come from, and what happens on exceed. Quotas reuse check/clear
    # and the counter store; they differ only in key construction and limit
    # resolution. A limit of 0 disables the quota entirely.
    #
    Quota = Struct.new(:name, :key, :limit_from, :period_from, keyword_init: true)

    QUOTAS = {
      api_send: Quota.new(
        name: :api_send,
        key: -> (credential) { "api-send:credential:#{credential.id}" },
        limit_from: -> (credential) { credential_limit(credential, :send_limit, :api_send_limit) },
        period_from: -> (credential) { credential_period(credential, :send_period, :api_send_period) }
      ),
      smtp_send: Quota.new(
        name: :smtp_send,
        key: -> (credential) { "smtp-send:credential:#{credential.id}" },
        limit_from: -> (credential) { credential_limit(credential, :send_limit, :smtp_send_limit) },
        period_from: -> (credential) { credential_period(credential, :send_period, :smtp_send_period) }
      ),
      smtp_ip_send: Quota.new(
        name: :smtp_ip_send,
        key: -> (credential) { "smtp-ip-send:credential:#{credential.id}" },
        limit_from: -> (credential) { credential_limit(credential, :send_limit, :smtp_ip_send_limit) },
        period_from: -> (credential) { credential_period(credential, :send_period, :smtp_ip_send_period) }
      ),
      reset_redeem: Quota.new(
        name: :reset_redeem,
        key: -> (ip) { "web-reset-redeem:#{ip}" },
        limit_from: -> (_ip) { Postal::Config.protection.reset_redeem_limit.to_i },
        period_from: -> (_ip) { Postal::Config.protection.reset_redeem_period.to_i }
      ),
      unauth_intake: Quota.new(
        name: :unauth_intake,
        key: -> (ip, kind) { "smtp-unauth:#{ip}:#{kind}" },
        limit_from: -> (_id) { Postal::Config.protection.unauth_intake_limit.to_i },
        period_from: -> (_id) { Postal::Config.protection.unauth_intake_period.to_i }
      )
    }.freeze

    class << self

      #
      # Count one use against a named quota and report the outcome. Returns
      # UNLIMITED when the limiter is off or the quota's limit is 0.
      #
      def check_quota(name, *identity)
        return UNLIMITED unless enabled?

        quota = QUOTAS.fetch(name)
        limit = quota.limit_from.call(identity.first).to_i
        return UNLIMITED if limit < 1

        period = quota.period_from.call(identity.first).to_i
        raise Error, "A quota needs a positive period" if period < 1

        quota_store.increment(namespaced(quota.key.call(*identity)), limit: limit, period: period)
      end

      #
      # Forget everything counted against a named quota for an identity.
      #
      def clear_quota(name, *identity)
        return unless enabled?

        quota = QUOTAS.fetch(name)
        quota_store.clear(namespaced(quota.key.call(*identity)))
      end

      #
      # Count one event against a key and report whether it is within its limit.
      # The result carries the number of seconds until the count resets, which is
      # what a caller quotes back to a client as a retry delay.
      #
      def check(key, limit:, period:)
        return UNLIMITED unless enabled?

        limit = limit.to_i
        period = period.to_i
        raise Error, "A rate limit needs a positive limit and period" if limit < 1 || period < 1

        store.increment(namespaced(key), limit: limit, period: period)
      end

      #
      # Count one event and report whether its limit has been exceeded. Callers
      # which only need a yes/no answer should use this.
      #
      def exceeded?(key, limit:, period:)
        check(key, limit: limit, period: period).exceeded?
      end

      #
      # Forget everything counted against a key. Used to clear a failure count
      # once the client has proved it is legitimate.
      #
      def clear(key)
        return unless enabled?

        store.clear(namespaced(key))
      end

      def enabled?
        Postal::Config.protection.enabled != false
      end

      def store
        @store ||= build_store
      end

      #
      # Replace the store. Any object which responds to #increment and #clear
      # with the signatures below can serve as one.
      #
      attr_writer :store

      #
      # Forget the memoised store so the next call rebuilds it from the current
      # configuration.
      #
      def reset!
        @store = nil
        @quota_store = nil
      end

      def quota_store
        @quota_store ||= build_quota_store
      end

      #
      # Replace the quota store. Any object which responds to #increment and
      # #clear with the signatures below can serve as one.
      #
      attr_writer :quota_store

      private

      def namespaced(key)
        prefix = Postal::Config.protection.prefix.to_s
        prefix.empty? ? key.to_s : "#{prefix}:#{key}"
      end

      def build_store
        build_counter_store(Postal::Config.protection.counter_store.to_s, "protection.counter_store")
      end

      def build_quota_store
        url = Postal::Config.protection.quota_store.to_s
        url = Postal::Config.protection.counter_store.to_s if url.empty?
        build_counter_store(url, "protection.quota_store")
      end

      def build_counter_store(url, setting)
        case url.split(":", 2).first
        when "memory"
          Memory.new
        when "redis", "valkey"
          # redis-client speaks the Redis protocol, which is what Valkey and
          # other drop-in replacements implement, so the scheme names the
          # topology (shared store) rather than the client.
          Shared.new(url.sub(/\Avalkey:/, "redis:"))
        else
          raise Error, "#{setting} expects a memory://, redis:// or valkey:// URL, " \
                       "not #{url.inspect}"
        end
      end

      def credential_limit(credential, option, global)
        override = credential_option(credential, option)
        return override if override && override >= 0

        Postal::Config.protection.public_send(global).to_i
      end

      def credential_period(credential, option, global)
        override = credential_option(credential, option)
        return override if override&.positive?

        Postal::Config.protection.public_send(global).to_i
      end

      def credential_option(credential, option)
        options = credential&.options
        return nil unless options.is_a?(Hash)

        value = options[option.to_s].nil? ? options[option] : options[option.to_s]
        value&.to_i
      end

    end

  end
end
