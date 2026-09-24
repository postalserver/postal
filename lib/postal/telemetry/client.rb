# frozen_string_literal: true

require "json"
require "net/http"
require "timeout"
require "uri"

module Postal
  module Telemetry
    #
    # Writes samples to an observability backend over one of the text protocols
    # they have in common, chosen by the URL scheme:
    #
    #   prometheus+http://vm:8428            # VictoriaMetrics, Prometheus, ...
    #   prometheus+http://pushgateway:9091   # ?path=/metrics/job/postal
    #   influx+http://influx:8086/postal     # InfluxDB / VictoriaMetrics / Vector
    #   json+http://vector:8686              # vector.dev http_server source
    #
    # The protocol is the part before "+", the transport (http or https) after
    # it; without a transport, http is assumed. This keeps the client
    # vendor-neutral: VictoriaMetrics is one target, not a special case.
    #
    class Client

      def initialize(url)
        if url.nil? || url.to_s.empty?
          raise Postal::Error, "A telemetry URL must be configured"
        end

        raw = URI.parse(url.to_s)
        protocol, transport = raw.scheme.to_s.split("+", 2)
        @protocol = protocol.to_s
        @options = URI.decode_www_form(raw.query.to_s).to_h

        @uri = raw.dup
        @uri.scheme = transport || "http"
        @uri.query = nil
      end

      attr_reader :protocol

      #
      # Write a batch of samples. Returns the number written.
      #
      def write(samples)
        return 0 if samples.empty?

        post(path, encode(samples), content_type)
        samples.size
      end

      #
      # Run an instant PromQL/MetricsQL query against /api/v1/query. Only
      # meaningful for the prometheus protocol: InfluxDB and JSON endpoints do
      # not speak PromQL, so querying through any other scheme raises rather
      # than posting a query the backend cannot answer. The live statistics
      # read back through this method, which is why only the prometheus scheme
      # can serve them.
      #
      def query(promql, time: nil)
        unless @protocol == "prometheus"
          raise Postal::Error, "Telemetry queries need the prometheus protocol, not '#{@protocol}'"
        end

        params = { "query" => promql }
        params["time"] = time.to_i.to_s if time
        response = post("/api/v1/query", URI.encode_www_form(params),
                        "application/x-www-form-urlencoded")
        JSON.parse(response.body).fetch("data", {})
      end

      private

      def encode(samples)
        case @protocol
        when "prometheus" then encode_prometheus(samples)
        when "influx" then encode_influx(samples)
        when "json" then encode_json(samples)
        else
          raise Postal::Error, "Unknown telemetry protocol '#{@protocol}'"
        end
      end

      def encode_prometheus(samples)
        samples.map do |sample|
          name = Escaping.prometheus_metric_name(sample.name)
          labels = (sample.labels || {}).map do |key, value|
            "#{Escaping.prometheus_label_name(key)}=\"#{Escaping.prometheus_label_value(value)}\""
          end
          set = labels.empty? ? "" : "{#{labels.join(',')}}"
          "#{name}#{set} #{format_value(sample.value)} #{sample.time}"
        end.join("\n")
      end

      def encode_influx(samples)
        lines = samples.map do |sample|
          tags = (sample.labels || {}).map { |key, value| ",#{Escaping.influx_key(key)}=#{Escaping.influx_key(value)}" }
          measurement = Escaping.influx_measurement(sample.name)
          "#{measurement}#{tags.join} value=#{format_value(sample.value)} #{sample.time * 1_000_000}"
        end
        # The line protocol requires every point, including the last, to be
        # newline-terminated.
        "#{lines.join("\n")}\n"
      end

      def encode_json(samples)
        samples.map do |sample|
          JSON.generate(
            name: sample.name,
            labels: sample.labels || {},
            value: sample.value,
            timestamp: sample.time
          )
        end.join("\n")
      end

      def format_value(value)
        value.is_a?(Integer) ? value.to_s : value.to_f.to_s
      end

      def path
        @options["path"] || default_path
      end

      def default_path
        case @protocol
        when "prometheus" then "/api/v1/import/prometheus"
        when "influx" then "/write?#{URI.encode_www_form(db: @uri.path.to_s.delete_prefix('/').presence || 'postal')}"
        else "/"
        end
      end

      def content_type
        case @protocol
        when "json" then "application/json"
        else "text/plain"
        end
      end

      def post(path, body, content_type)
        uri = @uri.dup
        existing_query = uri.query.to_s
        path_part, query_part = path.split("?", 2)
        uri.path = path_part
        uri.query = [existing_query.presence, query_part].compact.join("&").presence

        target = uri.query ? "#{uri.path}?#{uri.query}" : uri.path

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Post.new(target)
          request["Content-Type"] = content_type
          request.body = body
          response = http.request(request)
          unless response.is_a?(Net::HTTPSuccess)
            raise Postal::Error, "Telemetry request failed (#{response.code}): #{response.body}"
          end

          response
        end
      rescue SystemCallError, SocketError, Timeout::Error => e
        raise Postal::Error, "Telemetry request failed: #{e.message}"
      end

    end
  end
end
