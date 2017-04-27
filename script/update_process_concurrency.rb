#!/usr/bin/env ruby

require File.expand_path('../../lib/postal/config', __FILE__)
worker_quantity = Postal.config.workers&.quantity || 1
hash = {
  'processes' => {
    'worker' => {
      'quantity' => worker_quantity
    },
    'fast' => {
      'quantity' => Postal.config.fast_server.enabled? ? 1 : 0
    }
  }
}.to_yaml

File.open(Postal.app_root.join('Procfile.local'), 'w') { |f| f.write(hash + "\n")}
