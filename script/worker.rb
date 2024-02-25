#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require_relative "../config/environment"

HealthServer.start(
  name: "worker",
  default_port: Postal::Config.worker.default_health_server_port,
  default_bind_address: Postal::Config.worker.default_health_server_bind_address
)

Worker::Process.new.run
