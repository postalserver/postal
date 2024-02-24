# frozen_string_literal: true

module HasPrometheusMetrics

  def register_prometheus_counter(name, **kwargs)
    counter = Prometheus::Client::Counter.new(name, **kwargs)
    registry.register(counter)
  end

  def register_prometheus_histogram(name, **kwargs)
    histogram = Prometheus::Client::Histogram.new(name, **kwargs)
    registry.register(histogram)
  end

  def increment_prometheus_counter(name, labels: {})
    counter = registry.get(name)
    return if counter.nil?

    counter.increment(labels: labels)
  end

  def observe_prometheus_histogram(name, time, labels: {})
    histogram = registry.get(name)
    return if histogram.nil?

    histogram.observe(time, labels: labels)
  end

  private

  def registry
    Prometheus::Client.registry
  end

end
