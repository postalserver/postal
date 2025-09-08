# frozen_string_literal: true

# == Schema Information
#
# Table name: smtp_endpoints
#
#  id             :integer          not null, primary key
#  server_id      :integer
#  uuid           :string(255)
#  name           :string(255)
#  hostname       :string(255)
#  ssl_mode       :string(255)
#  port           :integer
#  error          :text(65535)
#  disabled_until :datetime
#  last_used_at   :datetime
#  created_at     :datetime
#  updated_at     :datetime
#

class SMTPEndpoint < ApplicationRecord

  include HasUUID

  belongs_to :server
  has_many :routes, as: :endpoint
  has_many :additional_route_endpoints, dependent: :destroy, as: :endpoint

  SSL_MODES = %w[None Auto STARTTLS TLS].freeze

  before_destroy :update_routes

  validates :name, presence: true
  validates :hostname, presence: true, format: /\A[a-z0-9.-]*\z/
  validates :ssl_mode, inclusion: { in: SSL_MODES }
  validates :port, numericality: { only_integer: true, allow_blank: true }

  def description
    "#{name} (#{hostname})"
  end

  def mark_as_used
    update_column(:last_used_at, Time.now)
  end

  def update_routes
    routes.each { |r| r.update(endpoint: nil, mode: "Reject") }
  end

  def to_smtp_client_server
    puts "=== SMTPEndpoint -> SMTPClient::Server ==="
    puts "hostname: #{relay.hostname}"
    puts "port: #{relay.port || 25}"
    puts "ssl_mode: #{relay.ssl_mode}"
    puts "username: #{relay.username.inspect}"
    puts "username decoded: #{relay.username ? CGI.unescape(relay.username) : nil}"
    puts "password: #{relay.password? ? '****' : ''}"
    puts "authentication: #{relay.authentication.inspect}"
    puts "======================================="

    SMTPClient::Server.new(
     relay.hostname,
     port: relay.port,
     ssl_mode: relay.ssl_mode,
     username: relay.username ? CGI.unescape(relay.username) : nil,
     password: relay.password ? CGI.unescape(relay.password) : nil,
     authentication: relay.authentication ? relay.authentication : nil
   )

  end

end
