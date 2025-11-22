# frozen_string_literal: true

module ManagementAPI
  class IPPoolRulesController < BaseController

    # GET /management/api/v1/servers/:server_id/ip_pool_rules
    # List all IP pool rules for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_pool_rules": [
    #       { "uuid": "xxx", "ip_pool": {...}, "from": [...], "to": [...] }
    #     ]
    #   }
    # }
    def index
      if params[:server_id]
        server = find_server(params[:server_id])
        rules = server.ip_pool_rules.includes(:ip_pool)
      elsif params[:organization_id]
        organization = find_organization(params[:organization_id])
        rules = organization.ip_pool_rules.includes(:ip_pool)
      else
        render_error "MissingParameter", message: "Either server_id or organization_id is required"
        return
      end

      render_success(
        ip_pool_rules: rules.map { |r| ip_pool_rule_to_hash(r) }
      )
    end

    # GET /management/api/v1/servers/:server_id/ip_pool_rules/:uuid
    # Get a specific IP pool rule
    def show
      rule = find_rule(params[:id])
      render_success(ip_pool_rule: ip_pool_rule_to_hash(rule))
    end

    # POST /management/api/v1/servers/:server_id/ip_pool_rules
    # POST /management/api/v1/organizations/:organization_id/ip_pool_rules
    # Create a new IP pool rule
    #
    # Required params:
    #   ip_pool_id - ID of the IP pool to use when rule matches
    #
    # Optional params:
    #   from_addresses - array of from addresses/domains to match
    #   to_addresses - array of to addresses/domains to match
    #
    # Note: At least one of from_addresses or to_addresses must be provided
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "ip_pool_rule": { ... }
    #   }
    # }
    def create
      if params[:server_id]
        owner = find_server(params[:server_id])
        organization = owner.organization
      elsif params[:organization_id]
        owner = find_organization(params[:organization_id])
        organization = owner
      else
        render_error "MissingParameter", message: "Either server_id or organization_id is required"
        return
      end

      ip_pool = organization.ip_pools.find(api_params[:ip_pool_id])

      from_text = api_params[:from_addresses].is_a?(Array) ? api_params[:from_addresses].join("\n") : api_params[:from_addresses]
      to_text = api_params[:to_addresses].is_a?(Array) ? api_params[:to_addresses].join("\n") : api_params[:to_addresses]

      rule = IPPoolRule.create!(
        owner: owner,
        ip_pool: ip_pool,
        from_text: from_text,
        to_text: to_text
      )

      render_success(ip_pool_rule: ip_pool_rule_to_hash(rule))
    end

    # PATCH /management/api/v1/servers/:server_id/ip_pool_rules/:uuid
    # Update an IP pool rule
    #
    # Params:
    #   ip_pool_id - ID of the IP pool
    #   from_addresses - array of from addresses/domains
    #   to_addresses - array of to addresses/domains
    def update
      rule = find_rule(params[:id])

      update_params = {}

      if api_params[:ip_pool_id].present?
        organization = rule.owner.is_a?(Organization) ? rule.owner : rule.owner.organization
        update_params[:ip_pool] = organization.ip_pools.find(api_params[:ip_pool_id])
      end

      if api_params.key?(:from_addresses)
        update_params[:from_text] = api_params[:from_addresses].is_a?(Array) ? api_params[:from_addresses].join("\n") : api_params[:from_addresses]
      end

      if api_params.key?(:to_addresses)
        update_params[:to_text] = api_params[:to_addresses].is_a?(Array) ? api_params[:to_addresses].join("\n") : api_params[:to_addresses]
      end

      rule.update!(update_params)

      render_success(ip_pool_rule: ip_pool_rule_to_hash(rule))
    end

    # DELETE /management/api/v1/servers/:server_id/ip_pool_rules/:uuid
    # Delete an IP pool rule
    def destroy
      rule = find_rule(params[:id])

      rule.destroy!
      render_success(message: "IP pool rule has been deleted")
    end

    private

    def find_rule(uuid)
      IPPoolRule.find_by!(uuid: uuid)
    end

    def ip_pool_rule_to_hash(rule)
      {
        uuid: rule.uuid,
        owner_type: rule.owner_type,
        owner_id: rule.owner_id,
        ip_pool: {
          id: rule.ip_pool.id,
          name: rule.ip_pool.name
        },
        from_addresses: rule.from,
        to_addresses: rule.to,
        created_at: rule.created_at,
        updated_at: rule.updated_at
      }
    end

  end
end
