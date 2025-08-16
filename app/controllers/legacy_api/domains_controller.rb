# frozen_string_literal: true

class LegacyApi::DomainsController < LegacyApi::BaseController

  def index
    domains = @server.domains.includes(:dns_checks)
    domains_data = domains.map { |domain| serialize_domain(domain) }
    render_success(domains: domains_data)
  end

  def show
    domain = @server.domains.find_by(uuid: params[:id])
    if domain
      render_success(domain: serialize_domain(domain))
    else
      render_error("DomainNotFound", message: "Domain not found")
    end
  end

  def create
    domain = @server.domains.build(domain_params)
    if domain.save
      render_success(domain: serialize_domain(domain), message: "Domain created successfully")
    else
      render_parameter_error(domain.errors.full_messages.join(", "))
    end
  end

  def update
    domain = @server.domains.find_by(uuid: params[:id])
    unless domain
      render_error("DomainNotFound", message: "Domain not found")
      return
    end

    if domain.update(domain_params)
      render_success(domain: serialize_domain(domain), message: "Domain updated successfully")
    else
      render_parameter_error(domain.errors.full_messages.join(", "))
    end
  end

  def destroy
    domain = @server.domains.find_by(uuid: params[:id])
    unless domain
      render_error("DomainNotFound", message: "Domain not found")
      return
    end

    if domain.destroy
      render_success(message: "Domain deleted successfully")
    else
      render_error("DomainDeletionFailed", message: "Failed to delete domain")
    end
  end

  def verify
    domain = @server.domains.find_by(uuid: params[:id])
    unless domain
      render_error("DomainNotFound", message: "Domain not found")
      return
    end

    domain.check
    render_success(
      domain: serialize_domain(domain),
      message: "Domain verification initiated"
    )
  end

  private

  def domain_params
    allowed_params = api_params.slice("name")
    allowed_params
  end

  def serialize_domain(domain)
    {
      id: domain.uuid,
      name: domain.name,
      verification_token: domain.verification_token,
      verification_method: domain.verification_method,
      verified_at: domain.verified_at,
      dns_checked_at: domain.dns_checked_at,
      spf_status: domain.spf_status,
      spf_error: domain.spf_error,
      dkim_status: domain.dkim_status,
      dkim_error: domain.dkim_error,
      mx_status: domain.mx_status,
      mx_error: domain.mx_error,
      return_path_status: domain.return_path_status,
      return_path_error: domain.return_path_error,
      outbound_spam_threshold: domain.outbound_spam_threshold,
      inbound_spam_threshold: domain.inbound_spam_threshold,
      created_at: domain.created_at,
      updated_at: domain.updated_at
    }
  end

end