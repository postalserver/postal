# app/controllers/legacy_api/domains_controller.rb

module LegacyAPI
  class DomainsController < BaseController
    # Create a domain
    def create
      domain = @current_credential.server.domains.find_by(name: api_params["name"])
      if domain
        render_error("DomainNameExists", message: "Domain already exists", status: :conflict)
      else
        domain = @current_credential.server.domains.new(domain_params)
        if domain.save
          render_success(domain: domain.attributes)
        else
          render_error("ValidationError", message: domain.errors.full_messages.to_sentence, status: :unprocessable_entity)
        end
      end
    end

    # Query details of a domain
    def query
      domain = @current_credential.server.domains.find_by(name: api_params["name"])
      if domain
        render_success(domain: domain.attributes, dkim: domain.dkim_identifier)
      else
        render_error("DomainNotFound", message: "No such domain found", status: :not_found)
      end
    end

    # Verify a domain
    def verify
      domain = @current_credential.server.domains.find_by(name: api_params["name"])
      if domain
        domain.verify_with_dns
        render_success(domain: domain)
      else
        render_error("DomainNotFound", message: "No such domain found", status: :not_found)
      end
    end

    # Check domain status
    def check
      domain = @current_credential.server.domains.find_by(name: api_params["name"])
      if domain
        domain.check_dns(:manual)
        render_success(domain: domain.attributes, dkim: domain.dkim_record)
      else
        render_error("DomainNotFound", message: "No such domain found", status: :not_found)
      end
    end

    # Delete a domain
    def delete
      domain = @current_credential.server.domains.find_by(name: api_params["name"])
      if domain&.destroy
        render_success(message: "Domain deleted successfully")
      else
        render_error("DomainNotDeleted", message: "Failed to delete domain", status: :unprocessable_entity)
      end
    end

    private

    def domain_params
      params.require(:domain).permit(:name, :verification_method)
    end
  end
end
