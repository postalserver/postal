# frozen_string_literal: true

module ApplicationHelper

  def format_delivery_details(server, text)
    text.gsub!(/<msg:(\d+)>/) do
      id = ::Regexp.last_match(1).to_i
      link_to("message ##{id}", organization_server_message_path(server.organization, server, id), class: "u-link")
    end
    text.html_safe
  end

  def style_width(width, options = {})
    width = 100 if width > 100.0
    width = 0 if width < 0.0
    style = "width:#{width}%;"
    if options[:color]
      if width >= 100
        style += " background-color:#e2383a;"
      elsif width >= 90
        style += " background-color:#e8581f;"
      end
    end
    style
  end

  def domain_options_for_select(server, selected_domain = nil, options = {})
    String.new.tap do |s|
      s << "<option></option>"
      server_domains = server.domains.verified.order(:name)
      unless server_domains.empty?
        s << "<optgroup label='Server Domains'>"
        server_domains.each do |domain|
          selected = domain == selected_domain ? "selected='selected'" : ""
          s << "<option value='#{domain.id}' #{selected}>#{domain.name}</option>"
        end
        s << "</optgroup>"
      end

      organization_domains = server.organization.domains.verified.order(:name)
      unless organization_domains.empty?
        s << "<optgroup label='Organization Domains'>"
        organization_domains.each do |domain|
          selected = domain == selected_domain ? "selected='selected'" : ""
          s << "<option value='#{domain.id}' #{selected}>#{domain.name}</option>"
        end
        s << "</optgroup>"
      end
    end.html_safe
  end

  def endpoint_options_for_select(server, selected_value = nil, options = {})
    String.new.tap do |s|
      s << "<option></option>"

      http_endpoints = server.http_endpoints.order(:name).to_a
      if http_endpoints.present?
        s << "<optgroup label='HTTP Endpoints'>"
        http_endpoints.each do |endpoint|
          value = "#{endpoint.class}##{endpoint.uuid}"
          selected = value == selected_value ? "selected='selected'" : ""
          s << "<option value='#{value}' #{selected}>#{endpoint.description}</option>"
        end
        s << "</optgroup>"
      end

      smtp_endpoints = server.smtp_endpoints.order(:name).to_a
      if smtp_endpoints.present?
        s << "<optgroup label='SMTP Endpoints'>"
        smtp_endpoints.each do |endpoint|
          value = "#{endpoint.class}##{endpoint.uuid}"
          selected = value == selected_value ? "selected='selected'" : ""
          s << "<option value='#{value}' #{selected}>#{endpoint.description}</option>"
        end
        s << "</optgroup>"
      end

      address_endpoints = server.address_endpoints.order(:address).to_a
      if address_endpoints.present?
        s << "<optgroup label='Address Endpoints'>"
        address_endpoints.each do |endpoint|
          value = "#{endpoint.class}##{endpoint.uuid}"
          selected = value == selected_value ? "selected='selected'" : ""
          s << "<option value='#{value}' #{selected}>#{endpoint.address}</option>"
        end
        s << "</optgroup>"
      end

      unless options[:other] == false
        s << "<optgroup label='Other Options'>"
        Route::MODES.each do |mode|
          next if mode == "Endpoint"

          selected = (selected_value == mode ? "selected='selected'" : "")
          text = t("route_modes.#{mode.underscore}")
          s << "<option value='#{mode}' #{selected}>#{text}</option>"
        end
        s << "</optgroup>"
      end
    end.html_safe
  end

  def postal_version_string
    string = Postal.version
    string += " (#{Postal.branch})" if Postal.branch &&
                                       Postal.branch != "main"
    string
  end

end
