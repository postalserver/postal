# frozen_string_literal: true

require_relative "../config/environment"
Postal::SMTPServer::Server.new(debug: true).run
