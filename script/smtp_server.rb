# frozen_string_literal: true

require_relative "../config/environment"
SMTPServer::Server.new(debug: true).run
