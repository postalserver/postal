# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                             :integer          not null, primary key
#  dkim_error                     :string(255)
#  dkim_identifier_string         :string(255)
#  dkim_private_key               :text(65535)
#  dkim_status                    :string(255)
#  dns_checked_at                 :datetime
#  incoming                       :boolean          default(TRUE)
#  mx_error                       :string(255)
#  mx_status                      :string(255)
#  name                           :string(255)
#  outgoing                       :boolean          default(TRUE)
#  owner_type                     :string(255)
#  pending_dkim_identifier_string :string(255)
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

  VERIFICATION_EMAIL_ALIASES = %w[webmaster postmaster admin administrator hostmaster].freeze
  VERIFICATION_METHODS = %w[DNS Email].freeze

  belongs_to :server, optional: true
  belongs_to :owner, optional: true, polymorphic: true
  has_many :routes, dependent: :destroy
  has_many :track_domains, dependent: :destroy

  validates :name, presence: true, format: { with: /\A[a-z0-9\-.]*\z/ }, uniqueness: { case_sensitive: false, scope: [:owner_type, :owner_id], message: "is already added" }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }

  random_string :dkim_identifier_string, type: :chars, length: 6, unique: true, upper_letters_only: true

  before_create :generate_dkim_key

  scope :verified, -> { where.not(verified_at: nil) }

  before_save :update_verification_token_on_method_change

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

  def generate_dkim_key
    self.dkim_private_key = OpenSSL::PKey::RSA.new(Postal::Config.dns.dkim_key_size).to_s
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
      self.pending_dkim_private_key = OpenSSL::PKey::RSA.new(Postal::Config.dns.dkim_key_size).to_s
      self.pending_dkim_identifier_string = generate_unique_dkim_identifier_string
    else
      generate_dkim_key
      self.dkim_status = nil
      self.dkim_error = nil
      self.pending_dkim_private_key = nil
      self.pending_dkim_identifier_string = nil
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
    self.pending_dkim_private_key = nil
    self.pending_dkim_identifier_string = nil
    @dkim_key = nil
    @pending_dkim_key = nil
  end

  def cancel_pending_dkim_key!
    self.pending_dkim_private_key = nil
    self.pending_dkim_identifier_string = nil
    @pending_dkim_key = nil
    save!
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
      self.verification_token = rand(999_999).to_s.ljust(6, "0")
    else
      self.verification_token = nil
    end
  end

end
