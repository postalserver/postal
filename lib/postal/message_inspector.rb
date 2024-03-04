# frozen_string_literal: true

module Postal
  class MessageInspector

    def initialize(config)
      @config = config
    end

    # Inspect a message and update the inspection with the results
    # as appropriate.
    def inspect_message(message, scope, inspection)
    end

    private

    def logger
      Postal.logger
    end

    class << self

      # Return an array of all inspectors that are available for this
      # installation.
      def inspectors
        [].tap do |inspectors|
          if Postal::Config.rspamd.enabled?
            inspectors << MessageInspectors::Rspamd.new(Postal::Config.rspamd)
          elsif Postal::Config.spamd.enabled?
            inspectors << MessageInspectors::SpamAssassin.new(Postal::Config.spamd)
          end

          if Postal::Config.clamav.enabled?
            inspectors << MessageInspectors::Clamav.new(Postal::Config.clamav)
          end
        end
      end

    end

  end
end
