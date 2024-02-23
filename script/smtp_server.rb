# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require_relative "../config/environment"
SMTPServer::Server.new(debug: true).run
