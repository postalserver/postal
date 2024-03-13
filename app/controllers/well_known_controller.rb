# frozen_string_literal: true

class WellKnownController < ApplicationController

  layout false

  skip_before_action :set_browser_id
  skip_before_action :login_required
  skip_before_action :set_timezone

  def jwks
    render json: JWT::JWK::Set.new(Postal.signer.jwk).export.to_json
  end

end
