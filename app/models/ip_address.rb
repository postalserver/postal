# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_addresses
#
#  id         :integer          not null, primary key
#  ip_pool_id :integer
#  ipv4       :string(255)
#  ipv6       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  hostname   :string(255)
#  priority   :integer
#  use_proxy  :boolean          default(FALSE)
#  proxy_type :string(255)      default("socks5")
#  proxy_host :string(255)
#  proxy_port :integer          default(1080)
#  proxy_username :string(255)
#  proxy_password :string(255)
#  proxy_auto_install :boolean  default(FALSE)
#  proxy_ssh_host :string(255)
#  proxy_ssh_port :integer      default(22)
#  proxy_ssh_username :string(255) default("root")
#  proxy_ssh_password :string(255)
#  proxy_status :string(255)    default("not_configured")
#  proxy_last_tested_at :datetime
#  proxy_last_test_result :text
#

class IPAddress < ApplicationRecord

  belongs_to :ip_pool

  validates :ipv4, presence: true, uniqueness: true
  validates :hostname, presence: true
  validates :ipv6, uniqueness: { allow_blank: true }
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }

  scope :order_by_priority, -> { order(priority: :desc) }

  before_validation :set_default_priority
  after_save :install_proxy_if_needed

  # Proxy status states
  PROXY_STATUSES = %w[not_configured installing installed failed testing active].freeze

  def proxy_configured?
    use_proxy && proxy_host.present? && proxy_port.present?
  end

  def proxy_needs_installation?
    use_proxy && proxy_auto_install && proxy_ssh_host.present? &&
    proxy_ssh_username.present? && proxy_ssh_password.present? &&
    proxy_status.in?(%w[not_configured failed])
  end

  def proxy_active?
    proxy_status == "active"
  end

  private

  def set_default_priority
    return if priority.present?

    self.priority = 100
  end

  def install_proxy_if_needed
    return unless proxy_needs_installation?
    return if proxy_status == "installing"

    ProxyInstallerJob.perform_later(id)
  end

  class << self

    def select_by_priority
      order(Arel.sql("RAND() * priority DESC")).first
    end

  end

end
