# frozen_string_literal: true

# == Schema Information
#
# Table name: routes
#
#  id            :integer          not null, primary key
#  uuid          :string(255)
#  server_id     :integer
#  domain_id     :integer
#  endpoint_id   :integer
#  endpoint_type :string(255)
#  name          :string(255)
#  spam_mode     :string(255)
#  created_at    :datetime
#  updated_at    :datetime
#  token         :string(255)
#  mode          :string(255)
#
# Indexes
#
#  index_routes_on_token  (token)
#

class Route < ApplicationRecord

  MODES = %w[Endpoint Accept Hold Bounce Reject].freeze
  SPAM_MODES = %w[Mark Quarantine Fail].freeze
  ENDPOINT_TYPES = %w[SMTPEndpoint HTTPEndpoint AddressEndpoint].freeze

  include HasUUID

  belongs_to :server
  belongs_to :domain, optional: true
  belongs_to :endpoint, polymorphic: true, optional: true
  has_many :additional_route_endpoints, dependent: :destroy

  validates :name, presence: true, format: /\A(([a-z0-9\-.]*)|(\*)|(__returnpath__))\z/
  validates :spam_mode, inclusion: { in: SPAM_MODES }
  validates :endpoint, presence: { if: proc { mode == "Endpoint" } }
  validates :domain_id, presence: { unless: :return_path? }
  validate :validate_route_is_routed
  validate :validate_domain_belongs_to_server
  validate :validate_endpoint_belongs_to_server
  validate :validate_name_uniqueness
  validate :validate_return_path_route_endpoints
  validate :validate_no_additional_routes_on_non_endpoint_route

  after_save :save_additional_route_endpoints

  random_string :token, type: :chars, length: 8, unique: true

  def return_path?
    name == "__returnpath__"
  end

  def description
    if return_path?
      "Return Path"
    else
      "#{name}@#{domain.name}"
    end
  end

  def _endpoint
    if mode == "Endpoint"
      @endpoint ||= endpoint ? "#{endpoint.class}##{endpoint.uuid}" : nil
    else
      @endpoint ||= mode
    end
  end

  def _endpoint=(value)
    if value.blank?
      self.endpoint = nil
      self.mode = nil
    elsif value =~ /\#/
      class_name, id = value.split("#", 2)
      unless ENDPOINT_TYPES.include?(class_name)
        raise Postal::Error, "Invalid endpoint class name '#{class_name}'"
      end

      self.endpoint = class_name.constantize.find_by_uuid(id)
      self.mode = "Endpoint"
    else
      self.endpoint = nil
      self.mode = value
    end
  end

  def forward_address
    @forward_address ||= "#{token}@#{Postal::Config.dns.route_domain}"
  end

  def wildcard?
    name == "*"
  end

  def additional_route_endpoints_array
    @additional_route_endpoints_array ||= additional_route_endpoints.map(&:_endpoint)
  end

  def additional_route_endpoints_array=(array)
    @additional_route_endpoints_array = array.reject(&:blank?)
  end

  def save_additional_route_endpoints
    return unless @additional_route_endpoints_array

    seen = []
    @additional_route_endpoints_array.each do |item|
      if existing = additional_route_endpoints.find_by_endpoint(item)
        seen << existing.id
      else
        route = additional_route_endpoints.build(_endpoint: item)
        if route.save
          seen << route.id
        else
          route.errors.each do |_, message|
            errors.add :base, message
          end
          raise ActiveRecord::RecordInvalid
        end
      end
    end
    additional_route_endpoints.where.not(id: seen).destroy_all
  end

  #
  # This message will create a suitable number of message objects for messages that
  # are destined for this route. It receives a block which can set the message content
  # but most information is specified already.
  #
  # Returns an array of created messages.
  #
  def create_messages(&block)
    messages = []
    message = build_message
    if mode == "Endpoint" && server.message_db.schema_version >= 18
      message.endpoint_type = endpoint_type
      message.endpoint_id = endpoint_id
    end
    block.call(message)
    message.save
    messages << message

    # Also create any messages for additional endpoints that might exist
    if mode == "Endpoint" && server.message_db.schema_version >= 18
      additional_route_endpoints.each do |endpoint|
        next unless endpoint.endpoint

        message = build_message
        message.endpoint_id = endpoint.endpoint_id
        message.endpoint_type = endpoint.endpoint_type
        block.call(message)
        message.save
        messages << message
      end
    end

    messages
  end

  def build_message
    message = server.message_db.new_message
    message.scope = "incoming"
    message.rcpt_to = description
    message.domain_id = domain&.id
    message.route_id = id
    message
  end

  private

  def validate_route_is_routed
    return unless mode.nil?

    errors.add :endpoint, "must be chosen"
  end

  def validate_domain_belongs_to_server
    if domain && ![server, server.organization].include?(domain.owner)
      errors.add :domain, :invalid
    end

    return unless domain && !domain.verified?

    errors.add :domain, "has not been verified yet"
  end

  def validate_endpoint_belongs_to_server
    return unless endpoint && endpoint&.server != server

    errors.add :endpoint, :invalid
  end

  def validate_name_uniqueness
    return if server.nil?

    if domain
      if route = Route.includes(:domain).where(domains: { name: domain.name }, name: name).where.not(id: id).first
        errors.add :name, "is configured on the #{route.server.full_permalink} mail server"
      end
    elsif Route.where(name: "__returnpath__").where.not(id: id).exists?
      errors.add :base, "A return path route already exists for this server"
    end
  end

  def validate_return_path_route_endpoints
    return unless return_path?
    return unless mode != "Endpoint" || endpoint_type != "HTTPEndpoint"

    errors.add :base, "Return path routes must point to an HTTP endpoint"
  end

  def validate_no_additional_routes_on_non_endpoint_route
    return unless mode != "Endpoint" && !additional_route_endpoints_array.empty?

    errors.add :base, "Additional routes are not permitted unless the primary route is an actual endpoint"
  end

  class << self

    def find_by_name_and_domain(name, domain)
      route = Route.includes(:domain).where(name: name, domains: { name: domain }).first
      if route.nil?
        route = Route.includes(:domain).where(name: "*", domains: { name: domain }).first
      end
      route
    end

  end

end
