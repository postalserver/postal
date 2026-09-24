# frozen_string_literal: true

require "resolv"

module HasDNSChecks

  def dns_ok?
    spf_status == "OK" && dkim_status == "OK" && %w[OK Missing].include?(mx_status) && %w[OK Missing].include?(return_path_status)
  end

  def dns_checked?
    spf_status.present?
  end

  def check_dns(source = :manual)
    check_spf_record
    check_dkim_record
    check_dmarc_record
    check_mta_sts_record
    check_tls_rpt_record
    check_mx_records
    check_return_path_record
    self.dns_checked_at = Time.now
    save!
    if source == :auto && !dns_ok? && owner.is_a?(Server)
      WebhookRequest.trigger(owner, "DomainDNSError", {
        server: owner.webhook_hash,
        domain: name,
        uuid: uuid,
        dns_checked_at: dns_checked_at.to_f,
        spf_status: spf_status,
        spf_error: spf_error,
        dkim_status: dkim_status,
        dkim_error: dkim_error,
        dmarc_status: dmarc_status,
        dmarc_error: dmarc_error,
        mta_sts_status: mta_sts_status,
        mta_sts_error: mta_sts_error,
        tls_rpt_status: tls_rpt_status,
        tls_rpt_error: tls_rpt_error,
        mx_status: mx_status,
        mx_error: mx_error,
        return_path_status: return_path_status,
        return_path_error: return_path_error
      })
    end
    dns_ok?
  end

  #
  # SPF
  #

  def check_spf_record
    result = resolver.txt(name)
    spf_records = result.grep(/\Av=spf1/)
    if spf_records.empty?
      self.spf_status = "Missing"
      self.spf_error = "No SPF record exists for this domain"
    else
      suitable_spf_records = spf_records.grep(/include:\s*#{Regexp.escape(Postal::Config.dns.spf_include)}/)
      if suitable_spf_records.empty?
        self.spf_status = "Invalid"
        self.spf_error = "An SPF record exists but it doesn't include #{Postal::Config.dns.spf_include}"
        false
      else
        self.spf_status = "OK"
        self.spf_error = nil
        true
      end
    end
  end

  def check_spf_record!
    check_spf_record
    save!
  end

  #
  # DKIM
  #

  def check_dkim_record
    # If a new DKIM key is waiting to be activated, promote it to be the active
    # key as soon as its DNS record is in place. The matching DNS response has
    # already verified the key, so avoid a second lookup which could return a
    # different answer while DNS changes are propagating.
    if pending_dkim_key? && pending_dkim_record_live?
      activate_pending_dkim_key
      self.dkim_status = "OK"
      self.dkim_error = nil
      return true
    end

    domain = "#{dkim_record_name}.#{name}"
    records = resolver.txt(domain)
    if records.empty?
      self.dkim_status = "Missing"
      self.dkim_error = "No TXT records were returned for #{domain}"
    else
      sanitised_dkim_record = records.first.strip.ends_with?(";") ? records.first.strip : "#{records.first.strip};"
      if records.size > 1
        self.dkim_status = "Invalid"
        self.dkim_error = "There are #{records.size} records for at #{domain}. There should only be one."
      elsif sanitised_dkim_record != dkim_record
        self.dkim_status = "Invalid"
        self.dkim_error = "The DKIM record at #{domain} does not match the record we have provided. Please check it has been copied correctly."
      else
        self.dkim_status = "OK"
        self.dkim_error = nil
        true
      end
    end
  end

  def check_dkim_record!
    check_dkim_record
    save!
  end

  # Returns true if the DNS record for the pending DKIM key has been published
  # correctly.
  def pending_dkim_record_live?
    records = resolver.txt("#{pending_dkim_record_name}.#{name}")
    return false unless records.size == 1

    sanitised_record = records.first.strip.ends_with?(";") ? records.first.strip : "#{records.first.strip};"
    sanitised_record == pending_dkim_record
  end

  #
  # DMARC
  #

  # The DMARC policy belongs to the domain owner, so this checks that a single
  # usable record has been published rather than that it matches a record we
  # generated.
  def check_dmarc_record
    records = resolver.txt("#{dmarc_record_name}.#{name}").grep(/\Av=DMARC1/i)
    if records.empty?
      self.dmarc_status = "Missing"
      self.dmarc_error = "No DMARC record exists for this domain"
    elsif records.size > 1
      self.dmarc_status = "Invalid"
      self.dmarc_error = "There are #{records.size} DMARC records at #{dmarc_record_name}.#{name}. " \
                         "There should only be one."
    elsif records.first !~ /\bp\s*=\s*(none|quarantine|reject)\b/i
      self.dmarc_status = "Invalid"
      self.dmarc_error = "The DMARC record at #{dmarc_record_name}.#{name} does not contain a valid policy."
    else
      self.dmarc_status = "OK"
      self.dmarc_error = nil
      true
    end
  end

  def check_dmarc_record!
    check_dmarc_record
    save!
  end

  #
  # MTA-STS
  #

  # A policy is only meaningful while it is being served, so nothing is reported
  # while the policy is withdrawn.
  def check_mta_sts_record
    unless mta_sts_enabled?
      self.mta_sts_status = nil
      self.mta_sts_error = nil
      return
    end

    records = resolver.txt("#{mta_sts_record_name}.#{name}").grep(/\Av=STSv1/i)
    if records.empty?
      self.mta_sts_status = "Missing"
      self.mta_sts_error = "No MTA-STS record exists for this domain"
    elsif records.size > 1
      self.mta_sts_status = "Invalid"
      self.mta_sts_error = "There are #{records.size} MTA-STS records at #{mta_sts_record_name}.#{name}. " \
                           "There should only be one."
    elsif records.first[/\bid=([A-Za-z0-9]+)/i, 1].to_s.upcase != mta_sts_policy_id.to_s.upcase
      self.mta_sts_status = "Invalid"
      self.mta_sts_error = "The MTA-STS record at #{mta_sts_record_name}.#{name} does not advertise the " \
                           "current policy id (#{mta_sts_policy_id})."
    else
      self.mta_sts_status = "OK"
      self.mta_sts_error = nil
      true
    end
  end

  def check_mta_sts_record!
    check_mta_sts_record
    save!
  end

  #
  # TLS-RPT
  #

  # A reporting record is only meaningful when a destination has been configured
  # for it, so nothing is reported otherwise.
  def check_tls_rpt_record
    if tls_rpt_record.nil?
      self.tls_rpt_status = nil
      self.tls_rpt_error = nil
      return
    end

    records = resolver.txt("#{tls_rpt_record_name}.#{name}").grep(/\Av=TLSRPTv1/i)
    if records.empty?
      self.tls_rpt_status = "Missing"
      self.tls_rpt_error = "No TLS-RPT record exists for this domain"
    elsif records.size > 1
      self.tls_rpt_status = "Invalid"
      self.tls_rpt_error = "There are #{records.size} TLS-RPT records at #{tls_rpt_record_name}.#{name}. " \
                           "There should only be one."
    elsif records.first !~ /\brua\s*=/i
      self.tls_rpt_status = "Invalid"
      self.tls_rpt_error = "The TLS-RPT record at #{tls_rpt_record_name}.#{name} has no report destination."
    else
      self.tls_rpt_status = "OK"
      self.tls_rpt_error = nil
      true
    end
  end

  def check_tls_rpt_record!
    check_tls_rpt_record
    save!
  end

  #
  # MX
  #

  def check_mx_records
    records = resolver.mx(name).map(&:last)
    if records.empty?
      self.mx_status = "Missing"
      self.mx_error = "There are no MX records for #{name}"
    else
      missing_records = Postal::Config.dns.mx_records.dup - records.map { |r| r.to_s.downcase }
      if missing_records.empty?
        self.mx_status = "OK"
        self.mx_error = nil
      elsif missing_records.size == Postal::Config.dns.mx_records.size
        self.mx_status = "Missing"
        self.mx_error = "You have MX records but none of them point to us."
      else
        self.mx_status = "Invalid"
        self.mx_error = "MX #{missing_records.size == 1 ? 'record' : 'records'} for #{missing_records.to_sentence} are missing and are required."
      end
    end
  end

  def check_mx_records!
    check_mx_records
    save!
  end

  #
  # Return Path
  #

  def check_return_path_record
    records = resolver.cname(return_path_domain)
    if records.empty?
      self.return_path_status = "Missing"
      self.return_path_error = "There is no return path record at #{return_path_domain}"
    elsif records.size == 1 && records.first == Postal::Config.dns.return_path_domain
      self.return_path_status = "OK"
      self.return_path_error = nil
    else
      self.return_path_status = "Invalid"
      self.return_path_error = "There is a CNAME record at #{return_path_domain} but it points to #{records.first} which is incorrect. It should point to #{Postal::Config.dns.return_path_domain}."
    end
  end

  def check_return_path_record!
    check_return_path_record
    save!
  end

end

# -*- SkipSchemaAnnotations
