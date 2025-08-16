# frozen_string_literal: true

class LegacyApi::CredentialsController < LegacyApi::BaseController

  def index
    credentials = @server.credentials
    credentials_data = credentials.map { |credential| serialize_credential(credential) }
    render_success(credentials: credentials_data)
  end

  def show
    credential = @server.credentials.find_by(uuid: params[:id])
    if credential
      render_success(credential: serialize_credential(credential))
    else
      render_error("CredentialNotFound", message: "Credential not found")
    end
  end

  def create
    credential = @server.credentials.build(credential_params)
    if credential.save
      render_success(credential: serialize_credential(credential), message: "Credential created successfully")
    else
      render_parameter_error(credential.errors.full_messages.join(", "))
    end
  end

  def update
    credential = @server.credentials.find_by(uuid: params[:id])
    unless credential
      render_error("CredentialNotFound", message: "Credential not found")
      return
    end

    # Don't allow key modifications for security
    update_params = credential_params.except("key")
    
    if credential.update(update_params)
      render_success(credential: serialize_credential(credential), message: "Credential updated successfully")
    else
      render_parameter_error(credential.errors.full_messages.join(", "))
    end
  end

  def destroy
    credential = @server.credentials.find_by(uuid: params[:id])
    unless credential
      render_error("CredentialNotFound", message: "Credential not found")
      return
    end

    if credential.destroy
      render_success(message: "Credential deleted successfully")
    else
      render_error("CredentialDeletionFailed", message: "Failed to delete credential")
    end
  end

  private

  def credential_params
    allowed_params = api_params.slice("name", "type", "key", "hold", "options")
    
    # Set default type if not provided
    allowed_params["type"] ||= "API"
    
    # Validate IP address for SMTP-IP type
    if allowed_params["type"] == "SMTP-IP" && allowed_params["key"].present?
      begin
        IPAddr.new(allowed_params["key"])
      rescue IPAddr::InvalidAddressError
        render_parameter_error("Key must be a valid IP address for SMTP-IP type")
        return {}
      end
    end
    
    allowed_params
  end

  def serialize_credential(credential)
    {
      id: credential.uuid,
      name: credential.name,
      type: credential.type,
      key: credential.key,
      last_used_at: credential.last_used_at,
      created_at: credential.created_at,
      updated_at: credential.updated_at,
      hold: credential.hold,
      options: credential.options
    }
  end

end