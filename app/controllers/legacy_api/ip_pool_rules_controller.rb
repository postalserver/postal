# frozen_string_literal: true

module LegacyAPI
  class IPPoolRulesController < BaseController
    before_action :set_organization

    # GET /api/v1/ip_pool_rules
    #
    # Parameters:
    #   server_id => OPT: The UUID of the server to filter rules
    #
    # Response:
    #   An array of IP pool rules within the specified organization or server
    def index
      if params["server_id"]
        server = organization.servers.find_by(id: params["server_id"])
        if server.nil?
          render_error "ServerNotFound",
                       message: "No server found matching provided ID",
                       id: params["server_id"]
          return
        end
        ip_pool_rules = server.ip_pool_rules
      else
        ip_pool_rules = organization.ip_pool_rules
      end

      render_success ip_pool_rules: ip_pool_rules.map(&:attributes)
    end

    # POST /api/v1/ip_pool_rules/create
    #
    # Parameters:
    #   server_id    => OPT: The UUID of the server to which the rule belongs
    #   ip_pool_rule => REQ: A hash of IP pool rule attributes
    #
    # Response:
    #   The created IP pool rule object
    def create
      if api_params["ip_pool_rule"].blank?
        render_parameter_error "ip_pool_rule parameter is required but missing"
        return
      end
      if api_params["server_id"]
        server = organization.servers.find_by(id: api_params["server_id"])
        if server.nil?
          render_error "ServerNotFound",
                       message: "No server found matching provided ID",
                       id: api_params["server_id"]
          return
        end
        ip_pool_rule = server.ip_pool_rules.build(api_params["ip_pool_rule"])
      else
        ip_pool_rule = organization.ip_pool_rules.build(api_params["ip_pool_rule"])
      end
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
    #   id           => REQ: The ID of the IP pool rule to update
    #   ip_pool_rule => REQ: A hash of IP pool rule attributes to update
    #   server_id    => OPT: The UUID of the server to update rules for
    #
    # Response:
    #   The updated IP pool rule object
    def update
      if api_params["id"].blank? || api_params["ip_pool_rule"].blank?
        render_parameter_error "id and ip_pool_rule parameters are required but missing"
        return
      end

      if api_params["server_id"]
        server = organization.servers.find_by(id: api_params["server_id"])
        if server.nil?
          render_error "ServerNotFound",
                       message: "No server found matching provided ID",
                       id: api_params["server_id"]
          return
        end

        ip_pool_rule = server.ip_pool_rules.find_by(id: api_params["id"])
        if ip_pool_rule.nil?
          render_error "IPPoolRuleNotFound",
                       message: "No IP pool rule found matching provided ID for the specified server",
                       id: api_params["id"]
          return
        end
      else
        ip_pool_rule = organization.ip_pool_rules.find_by(id: api_params["id"])
        if ip_pool_rule.nil?
          render_error "IPPoolRuleNotFound",
                       message: "No IP pool rule found matching provided ID",
                       id: api_params["id"]
          return
        end
      end

      if ip_pool_rule.update(api_params["ip_pool_rule"])
        render_success ip_pool_rule: ip_pool_rule.attributes, message: "IP Pool Rule updated successfully"
      else
        render_error "ValidationError",
                     message: ip_pool_rule.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # DELETE /api/v1/ip_pool_rules/delete
    #
    # Parameters:
    #   id        => REQ: The ID of the IP pool rule to delete
    #   server_id => OPT: The UUID of the server from which to delete the rule
    #
    # Response:
    #   Success message upon deletion
    def delete
      if params["id"].blank?
        render_parameter_error "id parameter is required but missing"
        return
      end

      if params["server_id"]
        # Find the server by the given server_id within the organization
        server = organization.servers.find_by(id: params["server_id"])
        if server.nil?
          render_error "ServerNotFound",
                       message: "No server found matching provided ID",
                       id: params["server_id"]
          return
        end

        # Find the IP pool rule within the server's IP pool rules
        ip_pool_rule = server.ip_pool_rules.find_by(id: params["id"])
        if ip_pool_rule.nil?
          render_error "IPPoolRuleNotFound",
                       message: "No IP pool rule found matching provided ID for the specified server",
                       id: params["id"]
          return
        end
      else
        # Find the IP pool rule within the organization's IP pool rules
        ip_pool_rule = organization.ip_pool_rules.find_by(id: params["id"])
        if ip_pool_rule.nil?
          render_error "IPPoolRuleNotFound",
                       message: "No IP pool rule found matching provided ID",
                       id: params["id"]
          return
        end
      end

      # Delete the IP pool rule
      if ip_pool_rule.destroy
        render_success message: "IP Pool Rule deleted successfully"
      else
        render_error "DeleteError",
                     message: "Failed to delete IP Pool Rule",
                     status: :unprocessable_entity
      end
    end

    private

    # Setting the organization before each action
    def set_organization

      # Setting organization based on params or current_user logic
      if params[:organization_id]
        @organization = Organization.find_by(id: params[:organization_id])
      elsif current_user
        @organization = current_user.organization
      end

      # Render an error if organization is not found
      unless @organization
        render_error("OrganizationNotFound", message: "Organization not found")
      end
    end

    def organization
      @organization
    end

    # Permitting necessary parameters for API requests
    def api_params
      params.permit(:id, :server_id, ip_pool_rule: [:from_text, :to_text, :ip_pool_id])
    end
  end
end
