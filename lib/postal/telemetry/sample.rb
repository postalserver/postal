# frozen_string_literal: true

module Postal
  module Telemetry

    #
    # A single sample: a metric name, its labels, a value and a timestamp
    # (milliseconds since the epoch, which is what the wire formats want).
    #
    Sample = Struct.new(:name, :labels, :value, :time)

  end
end
