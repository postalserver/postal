# frozen_string_literal: true

#
# In-process metrics for Postal's own daemons (SMTP server, workers, dequeuers),
# exposed on their health-server /metrics endpoint. The method names are
# deliberately generic (register_counter, increment_counter, observe_histogram):
# they count things, and the exposition format is an implementation detail of
# this one endpoint, not of the callers. External observability with a choice
# of backends is Postal::Telemetry instead.
#
module HasMetrics

  def register_counter(name, **kwargs)
    counter = Prometheus::Client::Counter.new(name, **kwargs)
    registry.register(counter)
  end

  def register_histogram(name, **kwargs)
    histogram = Prometheus::Client::Histogram.new(name, **kwargs)
    registry.register(histogram)
  end

  def increment_counter(name, labels: {})
    counter = registry.get(name)
    return if counter.nil?

    counter.increment(labels: labels)
  end

  def observe_histogram(name, time, labels: {})
    histogram = registry.get(name)
    return if histogram.nil?

    histogram.observe(time, labels: labels)
  end

  private

  def registry
    Prometheus::Client.registry
  end

end
