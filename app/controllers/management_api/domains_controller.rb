# frozen_string_literal: true

module ManagementAPI
  class DomainsController < BaseController

    # GET /management/api/v1/servers/:server_id/domains
    # List all domains for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "domains": [
    #       {
    #         "uuid": "xxx",
    #         "name": "example.com",
    #         "verified": true,
    #         "dns_status": { "spf": "OK", "dkim": "OK", "mx": "OK", "return_path": "OK" }
    #       }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      render_success(
        server: server.full_permalink,
        domains: server.domains.order(:name).map { |d| domain_to_hash(d) }
      )
    end

    # GET /management/api/v1/servers/:server_id/domains/:id
    # Get a specific domain with full DNS record information
    #
    # Response includes all DNS records needed for setup
    def show
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.find_by!(uuid: params[:id])

      render_success(
        domain: domain_to_hash(domain, include_dns_records: true)
      )
    end

    # POST /management/api/v1/servers/:server_id/domains
    # Add a new domain to a server
    #
    # Required params:
    #   name - domain name (e.g., "example.com")
    #
    # Optional params:
    #   verification_method - "DNS" or "Email" (default: "DNS")
    #   auto_verify - if true and you're admin, immediately verify (default: true)
    #
    # Response includes DNS records needed for setup
    def create
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.build(
        name: api_params[:name]&.downcase&.strip,
        verification_method: api_params[:verification_method] || "DNS"
      )

      # Auto-verify if requested (similar to admin behavior in web UI)
      if api_params[:auto_verify] != false
        domain.verified_at = Time.now
      end

      domain.save!

      render_success(
        domain: domain_to_hash(domain, include_dns_records: true),
        message: domain.verified? ?
          "Domain added and verified. Configure DNS records now." :
          "Domain added. Verify ownership first, then configure DNS."
      )
    end

    # POST /management/api/v1/servers/:server_id/domains/:id/verify
    # Verify domain ownership via DNS
    #
    # This checks for the TXT record with verification token
    def verify
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.find_by!(uuid: params[:id])

      if domain.verified?
        render_success(
          domain: domain_to_hash(domain),
          message: "Domain is already verified"
        )
        return
      end

      if domain.verify_with_dns
        render_success(
          domain: domain_to_hash(domain, include_dns_records: true),
          message: "Domain verified successfully! Configure DNS records now."
        )
      else
        render_error "VerificationFailed",
          message: "DNS verification failed. Ensure TXT record is set.",
          expected_txt_record: domain.dns_verification_string,
          domain: domain.name
      end
    end

    # POST /management/api/v1/servers/:server_id/domains/:id/check_dns
    # Check DNS configuration for a domain
    #
    # Returns current status of SPF, DKIM, MX, and Return Path records
    def check_dns
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.find_by!(uuid: params[:id])

      unless domain.verified?
        render_error "NotVerified", message: "Domain must be verified before checking DNS"
        return
      end

      dns_ok = domain.check_dns(:manual)

      render_success(
        domain: domain_to_hash(domain, include_dns_records: true),
        dns_ok: dns_ok,
        message: dns_ok ? "All DNS records are configured correctly!" : "Some DNS records need attention"
      )
    end

    # GET /management/api/v1/servers/:server_id/domains/:id/dns_records
    # Get DNS records that need to be configured for a domain
    #
    # This is useful for automation - get all records to configure in your DNS provider
    def dns_records
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.find_by!(uuid: params[:id])

      records = []

      # Verification TXT record (if not verified)
      unless domain.verified?
        records << {
          type: "TXT",
          name: domain.name,
          value: domain.dns_verification_string,
          purpose: "verification",
          required: true
        }
      end

      # SPF record
      records << {
        type: "TXT",
        name: domain.name,
        value: domain.spf_record,
        purpose: "spf",
        required: true,
        status: domain.spf_status,
        error: domain.spf_error
      }

      # DKIM record
      records << {
        type: "TXT",
        name: "#{domain.dkim_record_name}.#{domain.name}",
        value: domain.dkim_record,
        purpose: "dkim",
        required: true,
        status: domain.dkim_status,
        error: domain.dkim_error
      }

      # Return path CNAME
      records << {
        type: "CNAME",
        name: domain.return_path_domain,
        value: Postal::Config.dns.return_path_domain,
        purpose: "return_path",
        required: false,
        status: domain.return_path_status,
        error: domain.return_path_error
      }

      # MX records (for incoming mail)
      Postal::Config.dns.mx_records.each do |mx|
        records << {
          type: "MX",
          name: domain.name,
          value: mx,
          priority: 10,
          purpose: "mx",
          required: false
        }
      end

      render_success(
        domain: domain.name,
        verified: domain.verified?,
        dns_ok: domain.dns_ok?,
        records: records
      )
    end

    # DELETE /management/api/v1/servers/:server_id/domains/:id
    # Remove a domain from a server
    def destroy
      server = find_server(params[:server_id])
      raise ActiveRecord::RecordNotFound, "Server not found" unless server

      domain = server.domains.find_by!(uuid: params[:id])
      domain.destroy!

      render_success(message: "Domain '#{domain.name}' has been removed")
    end

    private

    def domain_to_hash(domain, include_dns_records: false)
      hash = {
        uuid: domain.uuid,
        name: domain.name,
        verified: domain.verified?,
        verified_at: domain.verified_at,
        verification_method: domain.verification_method,
        dns_status: {
          checked_at: domain.dns_checked_at,
          spf: domain.spf_status,
          spf_error: domain.spf_error,
          dkim: domain.dkim_status,
          dkim_error: domain.dkim_error,
          mx: domain.mx_status,
          mx_error: domain.mx_error,
          return_path: domain.return_path_status,
          return_path_error: domain.return_path_error,
          ok: domain.dns_ok?
        },
        outgoing: domain.outgoing?,
        incoming: domain.incoming?,
        created_at: domain.created_at
      }

      if include_dns_records
        hash[:dns_records] = {
          verification: {
            type: "TXT",
            name: domain.name,
            value: domain.dns_verification_string
          },
          spf: {
            type: "TXT",
            name: domain.name,
            value: domain.spf_record
          },
          dkim: {
            type: "TXT",
            name: "#{domain.dkim_record_name}.#{domain.name}",
            value: domain.dkim_record
          },
          return_path: {
            type: "CNAME",
            name: domain.return_path_domain,
            value: Postal::Config.dns.return_path_domain
          },
          mx: {
            type: "MX",
            priority: 10,
            values: Postal::Config.dns.mx_records
          }
        }
      end

      hash
    end

  end
end
