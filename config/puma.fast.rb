require_relative '../lib/postal/config'
threads_count = Postal.config.fast_server&.max_threads&.to_i || 5
threads         threads_count, threads_count
bind_address  = Postal.config.fast_server&.bind_address || '127.0.0.1'
bind_port     = Postal.config.fast_server&.port&.to_i || 5010
bind            "tcp://#{bind_address}:#{bind_port}"
environment     Postal.config.rails&.environment || 'development'
prune_bundler
quiet false
rackup File.expand_path('../../lib/postal/fast_server/config.ru', __FILE__)
unless ENV['LOG_TO_STDOUT']
  stdout_redirect Postal.app_root.join('log', 'puma.fast.log'), Postal.app_root.join('log', 'puma.fast.log'), true
end

if ENV['APP_ROOT']
  directory ENV['APP_ROOT']
end
