# frozen_string_literal: true

# Maps the JEMALLOC_PROFILE build/run setting to the MALLOC_CONF string
# jemalloc actually receives. Kept dependency-free (no bundler, no gems) so
# the container entrypoint can evaluate it with a bare `ruby` before the
# application boots.
#
# Only two profiles exist, deliberately. Ruby allocates many small,
# short-lived objects across migrating Puma threads: thread-local caching
# stays on and arenas stay at jemalloc's default. What varies is how fast
# unused pages return to the OS. The per-CPU-arena and tcache-bin variants
# from native-daemon tuning guides do not apply here -- Ruby threads migrate
# between CPUs, so pinning arenas to physical cores hurts rather than helps.
module Postal
  module Jemalloc

    # @return [Hash<String, String>] profile name to MALLOC_CONF value.
    #   abort_conf:true makes jemalloc abort on any invalid option rather
    #   than running with a silently-ignored misconfiguration.
    #   max_background_threads:1 is required, not tuning: jemalloc only
    #   spawns the decay thread when the maximum is set explicitly --
    #   background_thread:true alone leaves zero threads running and dirty
    #   pages are never purged (verified: 95MB retained flat past the
    #   decay window without it).
    PROFILES = {
      "balanced" => "background_thread:true,max_background_threads:1,tcache:true,dirty_decay_ms:10000,muzzy_decay_ms:10000,abort_conf:true",
      "aggressive" => "background_thread:true,max_background_threads:1,tcache:true,dirty_decay_ms:1000,muzzy_decay_ms:0,abort_conf:true"
    }.freeze

    # @param profile [String, nil] requested profile name
    # @return [String] the MALLOC_CONF value for the profile
    # @raise [ArgumentError] for an unknown profile
    def self.malloc_conf_for(profile)
      conf = PROFILES[profile.to_s]
      raise ArgumentError, "unknown jemalloc profile #{profile.inspect} (expected one of: #{PROFILES.keys.join(', ')})" if conf.nil?

      conf
    end

    # Resolves the preloaded library without hardcoding one architecture, so
    # a future arm64 build keeps working.
    #
    # @return [String, nil] absolute path of libjemalloc.so.2, or nil
    def self.lib_path
      candidates = [
        "/usr/lib/x86_64-linux-gnu/libjemalloc.so.2",
        "/usr/lib/aarch64-linux-gnu/libjemalloc.so.2",
      ]
      found = candidates.find { |path| File.exist?(path) }
      return found unless found.nil?

      ldconfig = `ldconfig -p 2>/dev/null`.lines.grep(/libjemalloc\.so\.2/).first
      ldconfig&.split&.last
    end

  end
end
