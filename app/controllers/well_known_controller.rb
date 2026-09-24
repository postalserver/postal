# frozen_string_literal: true

class WellKnownController < ApplicationController

  layout false

  skip_before_action :set_browser_id
  skip_before_action :login_required
  skip_before_action :set_timezone

  def jwks
    render json: JWT::JWK::Set.new(Postal.signer.jwk).export.to_json
  end

  # The MTA-STS policy for a hosted domain, served over HTTPS at
  # https://mta-sts.<domain>/.well-known/mta-sts.txt. The request is matched to
  # a domain by the host it arrives on.
  def mta_sts
    domain = mta_sts_domain
    if domain.nil?
      render plain: "Not found", status: :not_found
    else
      render plain: domain.mta_sts_policy
    end
  end

  # The response to an ACME HTTP-01 challenge which the certificate authority
  # collects while a certificate is being issued.
  def acme_challenge
    content = ACMEChallenge.content_for(params[:token])
    if content.nil?
      render plain: "Not found", status: :not_found
    else
      render plain: content
    end
  end

  private

  def mta_sts_domain
    host = request.host.to_s.downcase
    return nil unless host.start_with?("mta-sts.")

    domain = Domain.find_by(name: host.delete_prefix("mta-sts."))
    return nil unless domain&.mta_sts_enabled?

    domain
  end

end
