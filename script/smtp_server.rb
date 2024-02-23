# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require_relative "../config/environment"

HealthServer.start(name: "smtp-server", default_port: 9091)
SMTPServer::Server.new(debug: true).run
