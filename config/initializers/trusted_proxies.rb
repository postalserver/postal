# frozen_string_literal: true

Rack::Request.ip_filter = lambda { |ip|
  if Postal::Config.postal.trusted_proxies&.any? { |net| net.include?(ip) } ||
     ip.match(/\A127\.0\.0\.1\Z|\A::1\Z|\Afd[0-9a-f]{2}:.+|\Alocalhost\Z|\Aunix\Z|\Aunix:/i)
    true
  else
    false
  end
}
