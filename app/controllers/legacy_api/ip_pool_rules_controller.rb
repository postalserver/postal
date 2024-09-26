# frozen_string_literal: true

module LegacyAPI
  class IPPoolRulesController < BaseController

    # GET /api/v1/ip_pool_rules
    #
    # Parameters:
    #   organization_id => The UUID of the organization (optional if server_id is provided)
    #   server_id       => The permalink of the server (optional if organization_id is provided)
    #
    # Response:
    #   An array of IP pool rules within the specified scope
    def index
      if params["organization_id"].blank? && params["server_id"].blank?
        render_parameter_error "`organization_id` or `server_id` parameter is required but missing"
        return
      end

      ip_pool_rules = if params["server_id"].present?
                        server = @current_credential.organization.servers.find_by(id: params["server_id"])
                        if server.nil?
                          render_error "ServerNotFound",
                                       message: "No server found matching provided ID",
                                       id: params["server_id"]
                          return
                        end
                        server.ip_pool_rules
                      else
                        organization = Organization.find_by(id: params["organization_id"])
                        if organization.nil?
                          render_error "OrganizationNotFound",
                                       message: "No organization found matching provided ID",
                                       id: params["organization_id"]
                          return
                        end
                        organization.ip_pool_rules
                      end

      rules = ip_pool_rules.map do |rule|
        {
          id: rule.id,
          from_text: rule.from_text,
          to_text: rule.to_text,
          ip_pool_id: rule.ip_pool_id
        }
      end

      render_success ip_pool_rules: rules
    end

    # POST /api/v1/ip_pool_rules/create
    #
    # Parameters:
    #   organization_id => The UUID of the organization (optional if server_id is provided)
    #   server_id       => The permalink of the server (optional if organization_id is provided)
    #   ip_pool_rule    => REQ: A hash of IP pool rule attributes
    #
    # Response:
    #   The created IP pool rule object
    def create
      if api_params["ip_pool_rule"].blank?
        render_parameter_error "`ip_pool_rule` parameter is required but missing"
        return
      end

      if api_params["organization_id"].blank? && api_params["server_id"].blank?
        render_parameter_error "`organization_id` or `server_id` parameter is required but missing"
        return
      end

      scope = if api_params["server_id"].present?
                server = @current_credential.organization.servers.find_by_permalink(api_params["server_id"])
                if server.nil?
                  render_error "ServerNotFound",
                               message: "No server found matching provided ID",
                               id: api_params["server_id"]
                  return
                end
                server
              else
                organization = Organization.find_by_uuid(api_params["organization_id"])
                if organization.nil?
                  render_error "OrganizationNotFound",
                               message: "No organization found matching provided ID",
                               id: api_params["organization_id"]
                  return
                end
                organization
              end

      ip_pool_rule = scope.ip_pool_rules.build(api_params["ip_pool_rule"])
      if ip_pool_rule.save
        render_success ip_pool_rule: ip_pool_rule.attributes, message: "IP Pool Rule created successfully"
      else
        render_error "ValidationError",
                     message: ip_pool_rule.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pool_rules/update
    #
    # Parameters:
    #   id             => REQ: The ID of the IP pool rule
    #   ip_pool_rule   => REQ: A hash of IP pool rule attributes to update
    #
    # Response:
    #   The updated IP pool rule object
    def update
      if api_params["id"].blank? || api_params["ip_pool_rule"].blank?
        render_parameter_error "`id` and `ip_pool_rule` parameters are required but missing"
        return
      end

      ip_pool_rule = IPPoolRule.find_by(id: api_params["id"])
      if ip_pool_rule.nil?
        render_error "IPPoolRuleNotFound",
                     message: "No IP pool rule found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_pool_rule.update(api_params["ip_pool_rule"])
        render_success ip_pool_rule: ip_pool_rule.attributes, message: "IP Pool Rule updated successfully"
      else
        render_error "ValidationError",
                     message: ip_pool_rule.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pool_rules/delete
    #
    # Parameters:
    #   id => REQ: The ID of the IP pool rule to delete
    #
    # Response:
    #   Success message upon deletion
    def delete
      if api_params["id"].blank?
        render_parameter_error "`id` parameter is required but missing"
        return
      end

      ip_pool_rule = IPPoolRule.find_by(id: api_params["id"])
      if ip_pool_rule.nil?
        render_error "IPPoolRuleNotFound",
                     message: "No IP pool rule found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_pool_rule.destroy
        render_success message: "IP Pool Rule deleted successfully"
      else
        render_error "DeleteError",
                     message: "Failed to delete IP Pool Rule",
                     status: :unprocessable_entity
      end
    end

  end
end
