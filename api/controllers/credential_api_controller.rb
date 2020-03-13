controller :credentials do
    friendly_name "Credentials API"
    description "This API allows you to access Credential CRUD" 
    authenticator :server
  
    action :get_limit do 
      title "Get a Credential Limit"
      description "This action allows you to Get a list of Credential Limit"
      param :credential_id, "Credential Id", :required => true, :type => Integer

      access_rule :master
      action do
        server = identity.server
        credential = server.credentials.find_by({:id => params["credential_id"]})
        credential.credential_limits
      end
    end
  
    action :create do 
      title "Create a Credential"
      description "This action allows you to create Credentials"
      access_rule :master
      # Acceptable Parameters
      param :type, "Credential Type", :required => true, :type => String
      param :name, "Credential Name", :required => true, :type => String
      param :hold, "Send Message Status", :required => true, :type => Integer
      param :limits, "Credential Limits", :required => true, :type => Array
      # error
      error 'ValidationError', "The provided data was not sufficient to create Credential", :attributes => {:errors => "A hash of error details"}
      action do
        server = identity.server
        credential = server.credentials.build
        credential.type = params["type"]
        credential.name = params["name"]
        credential.hold = params["hold"]

        if credential.save
          if params['limits'].present? 
              params['limits'].each do |limit| 
                  credential_limit = CredentialLimit.new
                  credential_limit.credential_id = credential.id
                  credential_limit.limit = limit["limit"].to_i
                  credential_limit.type = limit["type"].to_s

                  credential_limit.save
              end
          end  
          {
              'credential_key': credential.key,
              'credential_id': credential.id
          }
        else 
            error 'ValidationError'
        end
      end
    end
  
    action :update do 
      access_rule :master
      # Acceptable Parameters
      param :credential_id, "Credential Id", :required => true, :type => Integer
      param :type, "Credential Type", :type => String
      param :name, "Credential Name", :type => String
      param :hold, "Send Message Status", :type => Integer
      param :limits, "Credential Limits", :type => Array
      # error
      error 'ValidationError', "The provided data was not sufficient to update Credential", :attributes => {:errors => "A hash of error details"}

      action do
        server = identity.server
        credential = server.credentials.find_by({:id => params["credential_id"]}) 
        if credential.present? 
          if params["type"].present? ||
             params["name"].present? ||
             params["hold"].present?
              credential.update({
                type: params["type"],
                name: params["name"],
                hold: params["hold"]
              })
          end
 
          if params['limits'].present? 
            params['limits'].each do |limit| 
                credential_limit = credential.credential_limits.find_by({:type => limit["type"]})
                if credential_limit.present?
                  credential_limit.update({
                    limit: limit["limit"],
                    usage: limit["usage"]
                  })
                else
                  if limit["limit"].present? && limit["type"].present?
                    credential_limit = CredentialLimit.new
                    credential_limit.credential_id = credential.id
                    credential_limit.limit = limit["limit"].to_i
                    credential_limit.type = limit["type"].to_s
                    credential_limit.usage = limit["usage"].to_i

                    credential_limit.save
                  end
                end
            end
          end 

          {
              'success': true
          }
        else 
            error 'ValidationError'
        end
      end
    end
  
    action :destroy do 
      access_rule :master
      # Acceptable Parameters
      param :credential_id, "Credential Id", :required => true, :type => Integer
      param :type, "Credential Type", :type => String
      param :name, "Credential Name", :type => String
      param :hold, "Send Message Status", :type => Integer
      param :limits, "Credential Limits", :type => Array
      # error
      error 'ValidationError', "The provided data was not sufficient to destroy Credential", :attributes => {:errors => "A hash of error details"}

      action do
        server = identity.server
        credential = server.credentials.find_by({:id => params["credential_id"]}) 
        
        if credential.present? && credential.destroy
            {:success => true}
        else 
            error 'ValidationError'
        end
      end
    end
  end