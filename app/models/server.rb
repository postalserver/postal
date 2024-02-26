# frozen_string_literal: true

# == Schema Information
#
# Table name: servers
#
#  id                                 :integer          not null, primary key
#  allow_sender                       :boolean          default(FALSE)
#  deleted_at                         :datetime
#  domains_not_to_click_track         :text(65535)
#  log_smtp_data                      :boolean          default(FALSE)
#  message_retention_days             :integer
#  mode                               :string(255)
#  name                               :string(255)
#  outbound_spam_threshold            :decimal(8, 2)
#  permalink                          :string(255)
#  postmaster_address                 :string(255)
#  privacy_mode                       :boolean          default(FALSE)
#  raw_message_retention_days         :integer
#  raw_message_retention_size         :integer
#  send_limit                         :integer
#  send_limit_approaching_at          :datetime
#  send_limit_approaching_notified_at :datetime
#  send_limit_exceeded_at             :datetime
#  send_limit_exceeded_notified_at    :datetime
#  spam_failure_threshold             :decimal(8, 2)
#  spam_threshold                     :decimal(8, 2)
#  suspended_at                       :datetime
#  suspension_reason                  :string(255)
#  token                              :string(255)
#  uuid                               :string(255)
#  created_at                         :datetime
#  updated_at                         :datetime
#  ip_pool_id                         :integer
#  organization_id                    :integer
#
# Indexes
#
#  index_servers_on_organization_id  (organization_id)
#  index_servers_on_permalink        (permalink)
#  index_servers_on_token            (token)
#  index_servers_on_uuid             (uuid)
#

class Server < ApplicationRecord

  RESERVED_PERMALINKS = %w[new all search stats edit manage delete destroy remove].freeze
  MODES = %w[Live Development].freeze

  include HasUUID
  include HasSoftDestroy

  attr_accessor :provision_database

  belongs_to :organization
  belongs_to :ip_pool, optional: true
  has_many :domains, dependent: :destroy, as: :owner
  has_many :credentials, dependent: :destroy
  has_many :smtp_endpoints, dependent: :destroy
  has_many :http_endpoints, dependent: :destroy
  has_many :address_endpoints, dependent: :destroy
  has_many :routes, dependent: :destroy
  has_many :queued_messages, dependent: :delete_all
  has_many :webhooks, dependent: :destroy
  has_many :webhook_requests, dependent: :destroy
  has_many :track_domains, dependent: :destroy
  has_many :ip_pool_rules, dependent: :destroy, as: :owner

  random_string :token, type: :chars, length: 6, unique: true, upper_letters_only: true
  default_value :permalink, -> { name ? name.parameterize : nil }
  default_value :raw_message_retention_days, -> { 30 }
  default_value :raw_message_retention_size, -> { 2048 }
  default_value :message_retention_days, -> { 60 }
  default_value :spam_threshold, -> { Postal::Config.postal.default_spam_threshold }
  default_value :spam_failure_threshold, -> { Postal::Config.postal.default_spam_failure_threshold }

  validates :name, presence: true, uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :mode, inclusion: { in: MODES }
  validates :permalink, presence: true, uniqueness: { scope: :organization_id, case_sensitive: false }, format: { with: /\A[a-z0-9-]*\z/ }, exclusion: { in: RESERVED_PERMALINKS }
  validate :validate_ip_pool_belongs_to_organization

  before_validation(on: :create) do
    self.token = token.downcase if token
  end

  after_create do
    unless provision_database == false
      message_db.provisioner.provision
    end
  end

  after_commit(on: :destroy) do
    unless provision_database == false
      message_db.provisioner.drop
    end
  end

  def status
    if suspended?
      "Suspended"
    else
      mode
    end
  end

  def full_permalink
    "#{organization.permalink}/#{permalink}"
  end

  def suspended?
    suspended_at.present? || organization.suspended?
  end

  def actual_suspension_reason
    return unless suspended?

    if suspended_at.nil?
      organization.suspension_reason
    else
      suspension_reason
    end
  end

  def to_param
    permalink
  end

  def message_db
    @message_db ||= Postal::MessageDB::Database.new(organization_id, id)
  end

  delegate :message, to: :message_db

  def message_rate
    @message_rate ||= message_db.live_stats.total(60, types: [:incoming, :outgoing]) / 60.0
  end

  def held_messages
    @held_messages ||= message_db.messages(where: { held: true }, count: true)
  end

  def throughput_stats
    @throughput_stats ||= begin
      incoming = message_db.live_stats.total(60, types: [:incoming])
      outgoing = message_db.live_stats.total(60, types: [:outgoing])
      outgoing_usage = send_limit ? (outgoing / send_limit.to_f) * 100 : 0
      {
        incoming: incoming,
        outgoing: outgoing,
        outgoing_usage: outgoing_usage
      }
    end
  end

  def bounce_rate
    @bounce_rate ||= begin
      time = Time.now.utc
      total_outgoing = 0.0
      total_bounces = 0.0
      message_db.statistics.get(:daily, [:outgoing, :bounces], time, 30).each do |_, stat|
        total_outgoing += stat[:outgoing]
        total_bounces += stat[:bounces]
      end
      total_outgoing.zero? ? 0 : (total_bounces / total_outgoing) * 100
    end
  end

  def domain_stats
    domains = Domain.where(owner_id: id, owner_type: "Server").to_a
    total = 0
    unverified = 0
    bad_dns = 0
    domains.each do |domain|
      total += 1
      unverified += 1 unless domain.verified?
      bad_dns += 1 if domain.verified? && !domain.dns_ok?
    end
    [total, unverified, bad_dns]
  end

  def webhook_hash
    {
      uuid: uuid,
      name: name,
      permalink: permalink,
      organization: organization&.permalink
    }
  end

  def send_volume
    @send_volume ||= message_db.live_stats.total(60, types: [:outgoing])
  end

  def send_limit_approaching?
    return false unless send_limit

    (send_volume >= send_limit * 0.90)
  end

  def send_limit_exceeded?
    return false unless send_limit

    send_volume >= send_limit
  end

  def send_limit_warning(type)
    if organization.notification_addresses.present?
      AppMailer.send("server_send_limit_#{type}", self).deliver
    end

    update_column("send_limit_#{type}_notified_at", Time.now)
    WebhookRequest.trigger(self, "SendLimit#{type.to_s.capitalize}", server: webhook_hash, volume: send_volume, limit: send_limit)
  end

  def queue_size
    @queue_size ||= queued_messages.ready.count
  end

  # Return the domain which can be used to authenticate emails sent from the given e-mail address.
  #
  # @param address [String] an e-mail address
  # @return [Domain, nil] the domain to use for authentication
  def authenticated_domain_for_address(address)
    return nil if address.blank?

    address = Postal::Helpers.strip_name_from_address(address)
    uname, domain_name = address.split("@", 2)
    return nil unless uname
    return nil unless domain_name

    # Find a verified domain which directly matches the domain name for the given address.
    domain = Domain.verified
                   .order(owner_type: :desc)
                   .where("(owner_type = 'Organization' AND owner_id = ?) OR " \
                          "(owner_type = 'Server' AND owner_id = ?)", organization_id, id)
                   .where(name: domain_name)
                   .first

    # If there is a matching domain, return it
    return domain if domain

    # Otherwise, we need to look to see if there is a domain configured which can be used as the authenticated
    # domain for any domain. This will look for domains directly within the server and return that.
    any_domain = domains.verified.where(use_for_any: true).order(:name).first
    return any_domain if any_domain

    # Return nil if we can't find anything suitable
    nil
  end

  def find_authenticated_domain_from_headers(headers)
    header_to_check = ["from"]
    header_to_check << "sender" if allow_sender?
    header_to_check.each do |header_name|
      if headers[header_name].is_a?(Array)
        values = headers[header_name]
      else
        values = [headers[header_name].to_s]
      end

      authenticated_domains = values.map { |v| authenticated_domain_for_address(v) }.compact
      if authenticated_domains.size == values.size
        return authenticated_domains.first
      end
    end
    nil
  end

  def suspend(reason)
    self.suspended_at = Time.now
    self.suspension_reason = reason
    save!
    if organization.notification_addresses.present?
      AppMailer.server_suspended(self).deliver
    end
    true
  end

  def unsuspend
    self.suspended_at = nil
    self.suspension_reason = nil
    save!
  end

  def ip_pool_for_message(message)
    return unless message.scope == "outgoing"

    [self, organization].each do |scope|
      rules = scope.ip_pool_rules.order(created_at: :desc)
      rules.each do |rule|
        if rule.apply_to_message?(message)
          return rule.ip_pool
        end
      end
    end

    ip_pool
  end

  private

  def validate_ip_pool_belongs_to_organization
    return unless ip_pool && ip_pool_id_changed? && !organization.ip_pools.include?(ip_pool)

    errors.add :ip_pool_id, "must belong to the organization"
  end

  class << self

    def triggered_send_limit(type)
      servers = where("send_limit_#{type}_at IS NOT NULL AND send_limit_#{type}_at > ?", 3.minutes.ago)
      servers.where("send_limit_#{type}_notified_at IS NULL OR send_limit_#{type}_notified_at < ?", 1.hour.ago)
    end

    def send_send_limit_notifications
      [:approaching, :exceeded].each_with_object({}) do |type, hash|
        hash[type] = 0
        servers = triggered_send_limit(type)
        next if servers.empty?

        servers.each do |server|
          hash[type] += 1
          server.send_limit_warning(type)
        end
      end
    end

    def [](id, extra = nil)
      if id.is_a?(String) && id =~ /\A(\w+)\/(\w+)\z/
        joins(:organization).where(
          organizations: { permalink: ::Regexp.last_match(1) }, permalink: ::Regexp.last_match(2)
        ).first
      else
        find_by(id: id.to_i)
      end
    end

  end

end
