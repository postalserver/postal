# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

require_relative "config/environment"
$0 = "[postal] #{ENV.fetch('PROC_NAME', nil)}"
run Rails.application
