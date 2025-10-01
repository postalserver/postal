# frozen_string_literal: true

require "socket"
require "rackup/handler/webrick"
require "prometheus/client/formats/text"

class HealthServer

  def initialize(name: "unnamed-process")
    @name = name
  end

  def call(env)
    case env["PATH_INFO"]
    when "/health"
      ok
    when "/metrics"
      metrics
    when "/"
      root
    else
      not_found
    end
  end

  private

  def root
    [200, { "Content-Type" => "text/plain" }, ["#{@name} (pid: #{Process.pid}, host: #{hostname})"]]
  end

  def ok
    [200, { "Content-Type" => "text/plain" }, ["OK"]]
  end

  def not_found
    [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
  end

  def metrics
    registry = Prometheus::Client.registry
    body = Prometheus::Client::Formats::Text.marshal(registry)
    [200, { "Content-Type" => "text/plain" }, [body]]
  end

  def hostname
    Socket.gethostname
  rescue StandardError
    "unknown-hostname"
  end

  class << self

    def run(default_port:, default_bind_address:, **options)
      port = ENV.fetch("HEALTH_SERVER_PORT", default_port)
      bind_address = ENV.fetch("HEALTH_SERVER_BIND_ADDRESS", default_bind_address)

      Rackup::Handler::WEBrick.run(new(**options),
                                   Port: port,
                                   BindAddress: bind_address,
                                   AccessLog: [],
                                   Logger: LoggerProxy.new)
    rescue Errno::EADDRINUSE
      Postal.logger.info "health server port (#{bind_address}:#{port}) is already " \
                         "in use, not starting health server"
    end

    def start(**options)
      thread = Thread.new { run(**options) }
      thread.abort_on_exception = false
      thread
    end

  end

  class LoggerProxy

    [:info, :debug, :warn, :error, :fatal].each do |severity|
      define_method(severity) do |message|
        add(severity, message)
      end

      define_method("#{severity}?") do
        severity != :debug
      end
    end

    def add(severity, message)
      return if severity == :debug

      case message
      when /\AWEBrick::HTTPServer#start:.*port=(\d+)/
        Postal.logger.info "started health server on port #{::Regexp.last_match(1)}", component: "health-server"
      when /\AWEBrick::HTTPServer#start done/
        Postal.logger.info "stopped health server", component: "health-server"
      when /\AWEBrick [\d.]+/,
           /\Aruby ([\d.]+)/,
           /\ARackup::Handler::WEBrick is mounted/,
           /\Aclose TCPSocket/,
           /\Agoing to shutdown/
        # Don't actually print routine messages to avoid too much
        # clutter when processes start it
      else
        Postal.logger.debug message, component: "health-server"
      end
    end

  end

end
