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
      # Log all servers in the organization
      all_servers = organization.servers
      logger.info "All Servers: #{all_servers.pluck(:id, :name)}" # Log server IDs and names

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
      logger.info "1"
      puts "1"
      if api_params["ip_pool_rule"].blank?
        render_parameter_error "ip_pool_rule parameter is required but missing"
        return
      end
      logger.info "2"
      puts "2"
      if api_params["server_id"]
        logger.info "3"
        puts "3"
        server = organization.servers.find_by(id: api_params["server_id"])
        if server.nil?
          logger.info "4"
          puts "4"
          render_error "ServerNotFound",
                       message: "No server found matching provided ID",
                       id: api_params["server_id"]
          return
        end
        ip_pool_rule = server.ip_pool_rules.build(api_params["ip_pool_rule"])
      else
        logger.info "5"
        puts "5"
        Puts "Organization: #{organization.inspect}"
        ip_pool_rule = organization.ip_pool_rules.build(api_params["ip_pool_rule"])
      end
      logger.info "6"
      puts "6"
      if ip_pool_rule.save
        logger.info "7"
        puts "7"
        render_success ip_pool_rule: ip_pool_rule.attributes, message: "IP Pool Rule created successfully"
      else
        logger.info "8"
        puts "8"
        logger.info "Validation Errors: #{ip_pool_rule.errors.full_messages}"
        puts "Validation Errors: #{ip_pool_rule.errors.full_messages}"
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
    #
    # Response:
    #   The updated IP pool rule object
    def update
      if api_params["id"].blank? || api_params["ip_pool_rule"].blank?
        render_parameter_error "id and ip_pool_rule parameters are required but missing"
        return
      end

      ip_pool_rule = organization.ip_pool_rules.find_by(id: api_params["id"])
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

    # DELETE /api/v1/ip_pool_rules/delete
    #
    # Parameters:
    #   id => REQ: The ID of the IP pool rule to delete
    #
    # Response:
    #   Success message upon deletion
    def delete
      if params["id"].blank?
        render_parameter_error "id parameter is required but missing"
        return
      end

      ip_pool_rule = organization.ip_pool_rules.find_by(id: params["id"])
      if ip_pool_rule.nil?
        render_error "IPPoolRuleNotFound",
                     message: "No IP pool rule found matching provided ID",
                     id: params["id"]
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

    private

    # Setting the organization before each action
    def set_organization
      # Print out all organizations
      all_organizations = Organization.all
      logger.info "All Organizations: #{all_organizations.pluck(:id, :name)}" # Log organization IDs and names
      puts "All Organizations: #{all_organizations.pluck(:id, :name)}" # Print organization IDs and names to console

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