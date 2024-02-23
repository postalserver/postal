#!/usr/bin/env ruby
# frozen_string_literal: true

$stdout.sync = true
$stderr.sync = true

require_relative "../config/environment"

HealthServer.start(name: "worker", default_port: 9090)
Worker::Process.new.run
