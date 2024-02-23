# frozen_string_literal: true

module HasPrometheusMetrics

  def register_prometheus_counter(name, **kwargs)
    counter = Prometheus::Client::Counter.new(name, **kwargs)
    registry.register(counter)
  end

  def increment_prometheus_counter(name, labels: {})
    counter = registry.get(name)
    return if counter.nil?

    counter.increment(labels: labels)
  end

  private

  def registry
    Prometheus::Client.registry
  end

end
