# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                             :integer          not null, primary key
#  dkim_error                     :string(255)
#  dkim_identifier_string         :string(255)
#  dkim_key_size                  :integer
#  dkim_private_key               :text(65535)
#  dkim_status                    :string(255)
#  dmarc_error                    :string(255)
#  dmarc_status                   :string(255)
#  dns_checked_at                 :datetime
#  incoming                       :boolean          default(TRUE)
#  mta_sts_error                  :string(255)
#  mta_sts_max_age                :integer          default(86400)
#  mta_sts_mode                   :string(255)      default("none")
#  mta_sts_policy_id              :string(255)
#  mta_sts_status                 :string(255)
#  mx_error                       :string(255)
#  mx_status                      :string(255)
#  name                           :string(255)
#  outgoing                       :boolean          default(TRUE)
#  owner_type                     :string(255)
#  pending_dkim_identifier_string :string(255)
#  pending_dkim_key_created_at    :datetime
#  pending_dkim_key_notified_at   :datetime
#  pending_dkim_private_key       :text(65535)
#  return_path_error              :string(255)
#  return_path_status             :string(255)
#  spf_error                      :string(255)
#  spf_status                     :string(255)
#  use_for_any                    :boolean
#  uuid                           :string(255)
#  verification_method            :string(255)
#  verification_token             :string(255)
#  verified_at                    :datetime
#  created_at                     :datetime
#  updated_at                     :datetime
#  owner_id                       :integer
#  server_id                      :integer
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#

require "resolv"

class Domain < ApplicationRecord

  include HasUUID

  include HasDNSChecks

  DKIM_KEY_SIZES = [1024, 2048, 3072, 4096].freeze

  MTA_STS_MODES = %w[none testing enforce].freeze

  # The longest period a sender may be asked to cache a policy for (RFC 8461).
  MTA_STS_MAX_AGE_LIMIT = 31_557_600

  VERIFICATION_EMAIL_ALIASES = %w[webmaster postmaster admin administrator hostmaster].freeze
  VERIFICATION_METHODS = %w[DNS Email].freeze

  belongs_to :server, optional: true
  belongs_to :owner, optional: true, polymorphic: true
  has_many :routes, dependent: :destroy
  has_many :tls_reports, dependent: :destroy
  has_many :track_domains, dependent: :destroy

  validates :name, presence: true, format: { with: /\A[a-z0-9\-.]*\z/ }, uniqueness: { case_sensitive: false, scope: [:owner_type, :owner_id], message: "is already added" }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }
  validates :dkim_key_size, inclusion: { in: DKIM_KEY_SIZES }, allow_nil: true
  validates :mta_sts_mode, inclusion: { in: MTA_STS_MODES }
  validates :mta_sts_max_age, numericality: {
    only_integer: true,
    greater_than: 0,
    less_than_or_equal_to: MTA_STS_MAX_AGE_LIMIT
  }

  random_string :dkim_identifier_string, type: :chars, length: 6, unique: true, upper_letters_only: true

  before_create :generate_dkim_key

  scope :verified, -> { where.not(verified_at: nil) }

  # Domains with a DKIM key change which has been waiting to be published for
  # longer than the given period and which have not been reminded about yet.
  scope :dkim_key_change_notifiable, lambda { |age|
    where(pending_dkim_key_notified_at: nil)
      .where.not(pending_dkim_key_created_at: nil)
      .where("pending_dkim_key_created_at < ?", age.ago)
  }

  before_save :update_verification_token_on_method_change
  before_save :update_mta_sts_policy_id

  def verified?
    verified_at.present?
  end

  def mark_as_verified
    return false if verified?

    self.verified_at = Time.now
    save!
  end

  def parent_domains
    parts = name.split(".")
    parts[0, parts.size - 1].each_with_index.map do |_, i|
      parts[i..].join(".")
    end
  end

  # The size of the RSA key to use for this domain's DKIM signature. A domain
  # can override the globally configured size; otherwise the configured value
  # is used.
  def dkim_key_size
    super || Postal::Config.dns.dkim_key_size
  end

  def generate_dkim_key
    self.dkim_private_key = OpenSSL::PKey::RSA.new(dkim_key_size).to_s
  end

  def dkim_key
    return nil unless dkim_private_key

    @dkim_key ||= OpenSSL::PKey::RSA.new(dkim_private_key)
  end

  def pending_dkim_key
    return nil unless pending_dkim_private_key

    @pending_dkim_key ||= OpenSSL::PKey::RSA.new(pending_dkim_private_key)
  end

  def pending_dkim_key?
    pending_dkim_private_key.present?
  end

  # Generate a new DKIM key for this domain. If the current key is verified and
  # in use for signing, the new key is stored as a pending key under a new
  # identifier so that signing continues with the current key until the new
  # key's DNS record has been published and verified. Otherwise, the key is
  # replaced immediately and any in-flight key change is abandoned, since the
  # new key supersedes it.
  def regenerate_dkim_key!
    if dkim_status == "OK"
      self.pending_dkim_private_key = OpenSSL::PKey::RSA.new(dkim_key_size).to_s
      self.pending_dkim_identifier_string = generate_unique_dkim_identifier_string
      self.pending_dkim_key_created_at = Time.now
      self.pending_dkim_key_notified_at = nil
    else
      generate_dkim_key
      self.dkim_status = nil
      self.dkim_error = nil
      clear_pending_dkim_key
      @dkim_key = nil
    end
    @pending_dkim_key = nil
    save!
  end

  # Promote the pending DKIM key to be the active key. Does not save the record.
  def activate_pending_dkim_key
    return unless pending_dkim_key?

    self.dkim_private_key = pending_dkim_private_key
    self.dkim_identifier_string = pending_dkim_identifier_string
    clear_pending_dkim_key
    @dkim_key = nil
  end

  def cancel_pending_dkim_key!
    clear_pending_dkim_key
    save!
  end

  # Send a single reminder that a DKIM key change is still waiting to be
  # published. Returns true when the reminder was sent.
  def notify_pending_dkim_key!
    return false unless pending_dkim_key?
    return false if pending_dkim_key_notified_at

    organization = notification_organization
    AppMailer.domain_dkim_key_pending(self).deliver if organization&.notification_addresses.present?

    if owner.is_a?(Server)
      WebhookRequest.trigger(owner, "DomainDKIMKeyPending", {
        server: owner.webhook_hash,
        domain: name,
        uuid: uuid,
        record_name: pending_dkim_record_name
      })
    end

    update_column(:pending_dkim_key_notified_at, Time.now)
    true
  end

  # The organization which should be notified about changes to this domain.
  def notification_organization
    case owner
    when Organization then owner
    when Server then owner.organization
    else server&.organization
    end
  end

  def to_param
    uuid
  end

  def verification_email_addresses
    parent_domains.map do |domain|
      VERIFICATION_EMAIL_ALIASES.map do |a|
        "#{a}@#{domain}"
      end
    end.flatten
  end

  def spf_record
    "v=spf1 a mx include:#{Postal::Config.dns.spf_include} ~all"
  end

  # The DMARC record recommended for this domain. The policy is published in DNS
  # by the domain owner, so Postal only shows the record and checks it; it does
  # not store or apply a policy of its own.
  def dmarc_record
    parts = ["v=DMARC1", "p=none", "sp=none", "adkim=s", "aspf=r"]
    if Postal::Config.dns.dmarc_report_address.present?
      parts << "rua=#{dmarc_report_uri(Postal::Config.dns.dmarc_report_address)}"
    end
    if Postal::Config.dns.dmarc_failure_report_address.present?
      parts << "ruf=#{dmarc_report_uri(Postal::Config.dns.dmarc_failure_report_address)}"
    end
    "#{parts.join('; ')};"
  end

  def dmarc_record_name
    "_dmarc"
  end

  # The TLS-RPT record which asks sending servers to report the TLS failures they
  # encounter when delivering mail to this domain. It is only published when a
  # report destination has been configured.
  def tls_rpt_record
    address = Postal::Config.dns.tls_rpt_address
    return if address.blank?

    "v=TLSRPTv1; rua=#{tls_rpt_uri(address)};"
  end

  def tls_rpt_record_name
    "_smtp._tls"
  end

  # The MTA-STS policy which is served for this domain at
  # https://mta-sts.<domain>/.well-known/mta-sts.txt. MX hosts are listed only
  # while the policy is enabled, because a policy in "none" mode must not
  # authorise any host.
  def mta_sts_policy
    lines = ["version: STSv1", "mode: #{mta_sts_mode}"]
    Postal::Config.dns.mx_records.each { |mx| lines << "mx: #{mx}" } if mta_sts_enabled?
    lines << "max_age: #{mta_sts_max_age}"
    "#{lines.join("\n")}\n"
  end

  # The TXT record which advertises the policy to sending servers.
  def mta_sts_record
    "v=STSv1; id=#{mta_sts_policy_id};"
  end

  def mta_sts_record_name
    "_mta-sts"
  end

  # Whether a policy is served for this domain.
  def mta_sts_enabled?
    mta_sts_mode.present? && mta_sts_mode != "none"
  end

  # The hostname the policy is served from, and which a certificate is issued
  # for.
  def mta_sts_hostname
    "mta-sts.#{name}"
  end

  def mta_sts_certificate_path
    File.join(Postal::Config.mta_sts.certificate_directory, "#{name}.crt")
  end

  def mta_sts_private_key_path
    File.join(Postal::Config.mta_sts.certificate_directory, "#{name}.key")
  end

  # Whether a certificate needs to be obtained, either because there is not one
  # yet or because the one in use is close to expiring.
  def mta_sts_certificate_required?
    return false unless mta_sts_enabled?
    return true if mta_sts_certificate_expires_at.nil?

    mta_sts_certificate_expires_at < 30.days.from_now
  end

  # Request a certificate for the policy host and store it beside the other
  # runtime secrets. Both files are written alongside their destinations and
  # moved into place, so an interrupted request never leaves a certificate and a
  # key which do not match each other.
  def issue_mta_sts_certificate!
    result = Postal::ACME.issue(mta_sts_hostname)
    certificate = OpenSSL::X509::Certificate.new(result[:certificate])

    FileUtils.mkdir_p(Postal::Config.mta_sts.certificate_directory)
    File.open("#{mta_sts_private_key_path}.new", File::CREAT | File::TRUNC | File::WRONLY, 0o600) do |file|
      file.write(result[:key])
    end
    File.write("#{mta_sts_certificate_path}.new", result[:certificate])
    File.rename("#{mta_sts_private_key_path}.new", mta_sts_private_key_path)
    File.rename("#{mta_sts_certificate_path}.new", mta_sts_certificate_path)

    update!(
      mta_sts_certificate_status: "OK",
      mta_sts_certificate_error: nil,
      mta_sts_certificate_expires_at: certificate.not_after,
      mta_sts_certificate_obtained_at: Time.now
    )
  rescue StandardError => e
    update_columns(mta_sts_certificate_status: "Error", mta_sts_certificate_error: e.message)
    raise
  end

  def dkim_record
    build_dkim_record(dkim_key)
  end

  def dkim_identifier
    build_dkim_identifier(dkim_identifier_string)
  end

  def dkim_record_name
    build_dkim_record_name(dkim_identifier)
  end

  def pending_dkim_record
    build_dkim_record(pending_dkim_key)
  end

  def pending_dkim_identifier
    build_dkim_identifier(pending_dkim_identifier_string)
  end

  def pending_dkim_record_name
    build_dkim_record_name(pending_dkim_identifier)
  end

  # The DKIM record split into the strings a DNS provider needs when the record
  # is too long to publish as a single 255 character TXT string. Records which
  # fit in one string are returned unchanged.
  def dkim_record_chunks
    build_dkim_record_chunks(dkim_record)
  end

  def pending_dkim_record_chunks
    build_dkim_record_chunks(pending_dkim_record)
  end

  def return_path_domain
    "#{Postal::Config.dns.custom_return_path_prefix}.#{name}"
  end

  # Returns a DNSResolver instance that can be used to perform DNS lookups needed for
  # the verification and DNS checking for this domain.
  #
  # @return [DNSResolver]
  def resolver
    return DNSResolver.local if Postal::Config.postal.use_local_ns_for_domain_verification?

    @resolver ||= DNSResolver.for_domain(name)
  end

  def dns_verification_string
    "#{Postal::Config.dns.domain_verify_prefix} #{verification_token}"
  end

  def verify_with_dns
    return false unless verification_method == "DNS"

    result = resolver.txt(name)

    if result.include?(dns_verification_string)
      self.verified_at = Time.now
      return save
    end

    false
  end

  private

  def build_dkim_record(key)
    return if key.nil?

    public_key = key.public_key.to_s.gsub(/-+[A-Z ]+-+\n/, "").gsub(/\n/, "")
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  def build_dkim_record_chunks(record)
    return if record.nil?

    record.scan(/.{1,255}/m)
  end

  # A DMARC report destination as a URI. Accepts either a bare address or a
  # complete mailto: URI so that pasting either form works.
  def dmarc_report_uri(address)
    "mailto:#{address.to_s.sub(/\Amailto:/i, '')}"
  end

  # A TLS-RPT report destination, or several of them separated by commas. A
  # destination which already carries a scheme is used as it is, so that an
  # https: endpoint can be configured alongside a mailbox, and a bare address is
  # treated as a mailbox.
  def tls_rpt_uri(destinations)
    destinations.split(",").map do |destination|
      destination = destination.strip
      destination.include?(":") ? destination : "mailto:#{destination}"
    end.join(",")
  end

  # The MTA-STS policy identifier is derived from the policy body, so it changes
  # whenever the policy changes and stays stable otherwise. Senders only refresh
  # a cached policy when the identifier changes.
  def update_mta_sts_policy_id
    self.mta_sts_policy_id = Digest::SHA256.hexdigest(mta_sts_policy)[0, 16].upcase
  end

  # Discard any pending DKIM key without saving the record.
  def clear_pending_dkim_key
    self.pending_dkim_private_key = nil
    self.pending_dkim_identifier_string = nil
    self.pending_dkim_key_created_at = nil
    self.pending_dkim_key_notified_at = nil
    @pending_dkim_key = nil
  end

  def build_dkim_identifier(identifier_string)
    return nil unless identifier_string

    Postal::Config.dns.dkim_identifier + "-#{identifier_string}"
  end

  def build_dkim_record_name(identifier)
    return if identifier.nil?

    "#{identifier}._domainkey"
  end

  # Generates a random identifier string in the same format as the
  # `random_string :dkim_identifier_string` declaration, unique across both the
  # active and pending identifier columns.
  def generate_unique_dkim_identifier_string
    loop do
      string = Nifty::Utils::RandomString.generate(length: 6, upper_letters_only: true)
      scope = self.class.where(dkim_identifier_string: string).or(self.class.where(pending_dkim_identifier_string: string))
      return string unless scope.exists?
    end
  end

  def update_verification_token_on_method_change
    return unless verification_method_changed?

    if verification_method == "DNS"
      self.verification_token = SecureRandom.alphanumeric(32)
    elsif verification_method == "Email"
      self.verification_token = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    else
      self.verification_token = nil
    end
  end

end
