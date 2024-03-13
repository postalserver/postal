# frozen_string_literal: true

ENV["SILENCE_POSTAL_CONFIG_LOCATION_MESSAGE"] = "true"
require File.expand_path("../lib/postal/config", __dir__)
puts Postal.rp_dkim_dns_record
