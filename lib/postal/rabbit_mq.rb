require 'postal/config'
require 'bunny'

module Postal
  module RabbitMQ

    def self.create_connection
      conn = Bunny.new(
        :host => Postal.config.rabbitmq&.host || 'localhost',
        :port => Postal.config.rabbitmq&.port || 5672,
        :username => Postal.config.rabbitmq&.username || 'guest',
        :password => Postal.config.rabbitmq&.password || 'guest',
        :vhost => Postal.config.rabbitmq&.vhost || nil
      )
      conn.start
      conn
    end

    def self.create_channel
      conn = self.create_connection
      conn.create_channel(nil, Postal.config.workers.threads)
    end

  end
end
