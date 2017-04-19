class RenewTrackCertificatesJob < Postal::Job

  def perform
    TrackCertificate.where("renew_after IS NULL OR renew_after <= ?", Time.now).each do |certificate|
      log "Renewing certificate for track domain ##{certificate.id} (#{certificate.domain})"
      if certificate.get
        log "Successfully renewed"
      else
        certificate.update(:renew_after => 1.day.from_now)
        log "Could not be renewed"
      end
    end
  end

end
