controller :domains do
  friendly_name "Domains API"
  description "This API allows you to create and view domains on server"
  authenticator :server

  action :create do
    title "Create a domain"
    description "This action allows you to create domains"
    access_rule :min_scope

    param :name, "Domain name (max 50)", :required => true, :type => String

    error 'ValidationError', "The provided data was not sufficient to create domain", :attributes => {:errors => "A hash of error details"}
    error 'DomainNameMissing', "Domain name is missing"
    error 'InvalidDomainName', "Domain name is invalid"
    error 'DomainNameExists', "Domain name already exists"
    error 'ReachedDomainLimit', "Domain creation has reached maximum limit"

    returns Hash, :structure => :domain

    action do
      domain = identity.server.domains.find_by_name(params.name)
      if domain.nil?
        domain = Domain.new
        domain.server = identity.server
        domain.name = params.name
        domain.verification_method = 'DNS'
        domain.owner_type = Server
        domain.owner_id = identity.server.id
        domain.verified_at = Time.now
        domain_limit = identity.credential_limits.find_by({'type' => 'domain_limit'})
        if (domain_limit.usage.to_i != domain_limit.limit.to_i) && (domain_limit.usage.to_i < domain_limit.limit.to_i)
          if domain.save
            if identity.credential_limits.present?
              if domain_limit.present?
                usage = (domain_limmit.usage.to_i + 1)
                domain_limit.update({"usage": usage})
              end
            end
            structure :domain, domain, :return => true
          else
            error_message = domain.errors.full_messages.first
            if error_message == "Name is invalid"
              error "InvalidDomainName"
            else
              error "Unknown Error", error_message
            end
          end
        else
          error 'ReachedDomainLimit'
        end
      else
        error 'DomainNameExists'
      end

    end
  end

  action :query do
    title "Query domain"
    description "This action allows you to query domain"
    access_rule :min_scope

    param :name, "Domain name (max 50)", :required => true, :type => String

    error 'ValidationError', "The provided data was not sufficient to query domain", :attributes => {:errors => "A hash of error details"}
    error 'DomainNameMissing', "Domain name is missing"
    error 'DomainNotFound', "The domain not found"

    returns Hash, :structure => :domain

    action do
      domain = identity.server.domains.find_by_name(params.name)
      if domain.nil?
        error 'DomainNotFound'
      else
        structure :domain, domain, :return => true
      end
    end
  end

  action :check do
    title "Check domain status"
    description "This action allows you to check domain status"
    access_rule :min_scope

    param :name, "Domain name (max 50)", :required => true, :type => String

    error 'ValidationError', "The provided data was not sufficient to query domain", :attributes => {:errors => "A hash of error details"}
    error 'DomainNameMissing', "Domain name is missing"
    error 'DomainNotFound', "The domain not found"

    returns Hash, :structure => :domain

    action do
      domain = identity.server.domains.find_by_name(params.name)
      if domain.nil?
        error 'DomainNotFound'
      else
        domain.check_dns(:manual)
        structure :domain, domain, :return => true
      end
    end
  end

  action :delete do
    title "Delete a domain"
    description "This action allows you to delete domain"
    access_rule :min_scope

    param :name, "Domain name (max 50)", :required => true, :type => String

    error 'ValidationError', "The provided data was not sufficient to query domain", :attributes => {:errors => "A hash of error details"}
    error 'DomainNameMissing', "Domain name is missing"
    error 'DomainNotFound', "The domain not found"
    error 'DomainNotDeleted', "Domain could not be deleted"

    returns Hash

    action do
      domain = identity.server.domains.find_by_name(params.name)
      if domain.nil?
        error 'DomainNotFound'
      elsif domain.delete
        if identity.credential_limits.present?
          domain_limit = identity.credential_limits.find_by({'type' => 'domain_limit'})
          if domain_limit.present?
            usage = (domain_limmit.usage.to_i - 1)
            usage = 0 if usage < 0
            domain_limit.update({"usage": usage})
          end
        end
        {:message => "Domain deleted successfully"}
      else
        error 'DomainNotDeleted'
      end
    end
  end

  action :get_all do
    title "Get All domain"
    description "TGet All domains with associated credential"
    access_rule :min_scope

    error 'DomainNull', "No Domain Found with the credential", :attributes => {:errors => "A hash of error details"}
 

    returns Hash

    action do
      domains = identity.domains
      if domains.present?
        domains
      else
        error 'DomainNull'
      end
    end
  end

end