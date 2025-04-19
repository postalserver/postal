# frozen_string_literal: true

module LegacyAPI
  class DomainsController < BaseController
    def create
      # Extract required parameters
      server_id = api_params["server_id"]
      domain_name = api_params["name"]
      
      # Validate parameters
      if server_id.blank?
        render_parameter_error("server_id is required")
        return
      end
      
      if domain_name.blank?
        render_parameter_error("name is required")
        return
      end
      
      # Find the server
      server = @current_credential.server.organization.servers.find_by_uuid(server_id)
      if server.nil?
        render_error "InvalidServer", message: "The server could not be found with the provided server_id"
        return
      end
      
      # Check if server matches credential's server
      unless server == @current_credential.server
        render_error "AccessDenied", message: "You don't have permission to add domains to this server"
        return
      end
      
      # Create the domain
      domain = server.domains.build(
        name: domain_name,
        verification_method: "DNS"
      )
      
      # Auto-verify if the API credential belongs to an admin
      if @current_credential.user&.admin?
        domain.verified_at = Time.now
      end
      
      # Save the domain
      if domain.save
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verification_method: domain.verification_method,
            verified: domain.verified?,
            verification_token: domain.verification_token,
            dns_verification_string: domain.dns_verification_string,
            created_at: domain.created_at,
            updated_at: domain.updated_at
          }
        )
      else
        render_error "ValidationError", 
                     message: "The domain could not be created",
                     errors: domain.errors.full_messages
      end
    end
    
    def verify
      # Extract required parameters
      domain_uuid = api_params["domain_id"]
      
      # Validate parameters
      if domain_uuid.blank?
        render_parameter_error("domain_id is required")
        return
      end
      
      # Find the domain
      domain = @current_credential.server.domains.find_by_uuid(domain_uuid)
      if domain.nil?
        render_error "InvalidDomain", message: "The domain could not be found with the provided domain_id"
        return
      end
      
      # Check if domain is already verified
      if domain.verified?
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verified: domain.verified?,
            verified_at: domain.verified_at
          }
        )
        return
      end
      
      # Verify the domain
      if domain.verification_method == "DNS" && domain.verify_with_dns
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verified: domain.verified?,
            verified_at: domain.verified_at
          }
        )
      else
        render_error "VerificationFailed",
                     message: "We couldn't verify your domain. Please double check you've added the TXT record correctly.",
                     dns_verification_string: domain.dns_verification_string
      end
    end
    
    def dns_records
      # Extract required parameters
      domain_uuid = api_params["domain_id"]
      
      # Validate parameters
      if domain_uuid.blank?
        render_parameter_error("domain_id is required")
        return
      end
      
      # Find the domain
      domain = @current_credential.server.domains.find_by_uuid(domain_uuid)
      if domain.nil?
        render_error "InvalidDomain", message: "The domain could not be found with the provided domain_id"
        return
      end
      
      # Get DNS records for the domain
      records = []
      
      # Verification record - only if domain is not verified
      unless domain.verified?
        records << {
          type: "TXT",
          name: domain.name,
          value: domain.dns_verification_string,
          purpose: "verification"
        }
      end
      
      # SPF record
      records << {
        type: "TXT", 
        name: domain.name,
        value: domain.spf_record,
        purpose: "spf"
      }
      
      # DKIM record
      if domain.dkim_record.present? && domain.dkim_record_name.present?
        records << {
          type: "TXT",
          name: domain.dkim_record_name,
          short_name: "#{domain.dkim_identifier}._domainkey",
          value: domain.dkim_record,
          purpose: "dkim"
        }
      end
      
      # Return path record
      records << {
        type: "CNAME",
        name: domain.return_path_domain,
        short_name: Postal::Config.dns.custom_return_path_prefix,
        value: Postal::Config.dns.return_path,
        purpose: "return_path"
      }
      
      # MX records - only for incoming domains
      if domain.incoming?
        records << {
          type: "MX",
          name: domain.name,
          priority: 10,
          value: Postal::Config.dns.mx_records.first,
          purpose: "mx"
        }
      end
      
      # Track domain records if any exist
      if domain.track_domains.exists?
        domain.track_domains.each do |track_domain|
          records << {
            type: "CNAME",
            name: track_domain.name,
            value: Postal::Config.dns.track_domain,
            purpose: "tracking"
          }
        end
      end
      
      render_success(
        domain: {
          uuid: domain.uuid,
          name: domain.name,
          verified: domain.verified?
        },
        dns_records: records
      )
    end
  end
end