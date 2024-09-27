# frozen_string_literal: true

module LegacyAPI
  class IPPoolsController < BaseController
    before_action :set_organization, only: [:organisation, :assignments, :add_pool, :remove_pool]

    # GET /api/v1/ip_pools
    #
    # Response:
    #   An array of all IP pools
    def index
      ip_pools = IPPool.order(:name).map do |ip_pool|
        {
          id: ip_pool.id,
          name: ip_pool.name,
          default: ip_pool.default,
        }
      end

      render_success ip_pools: ip_pools
    end

    # POST /api/v1/ip_pools/create
    #
    # Parameters:
    #   ip_pool => REQ: A hash of IP pool attributes
    #
    # Response:
    #   The created IP pool object
    def create
      if api_params["ip_pool"].blank?
        render_parameter_error "`ip_pool` parameter is required but missing"
        return
      end

      ip_pool = IPPool.new(api_params["ip_pool"])
      if ip_pool.save
        render_success ip_pool: ip_pool.attributes, message: "IP Pool created successfully"
      else
        render_error "ValidationError",
                     message: ip_pool.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/update
    #
    # Parameters:
    #   id      => REQ: The ID of the IP pool to update
    #   ip_pool => REQ: A hash of IP pool attributes to update
    #
    # Response:
    #   The updated IP pool object
    def update
      if api_params["id"].blank? || api_params["ip_pool"].blank?
        render_parameter_error "`id` and `ip_pool` parameters are required but missing"
        return
      end

      ip_pool = IPPool.find_by(id: api_params["id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: api_params["id"]
        return
      end

      if ip_pool.update(api_params["ip_pool"])
        render_success ip_pool: ip_pool.attributes, message: "IP Pool updated successfully"
      else
        render_error "ValidationError",
                     message: ip_pool.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/delete
    #
    # Parameters:
    #   id => REQ: The ID of the IP pool to delete
    #
    # Response:
    #   Success message upon deletion
    def delete
      if params["id"].blank?
        render_parameter_error "`id` parameter is required but missing"
        return
      end

      ip_pool = IPPool.find_by(id: params["id"])
      if ip_pool.nil?
        render_error "IPPoolNotFound",
                     message: "No IP pool found matching provided ID",
                     id: params["id"]
        return
      end

      if ip_pool.destroy
        render_success message: "IP Pool deleted successfully"
      else
        render_error "DeleteError",
                     message: "IP Pool cannot be removed because it still has associated addresses or servers",
                     status: :unprocessable_entity
      end
    rescue ActiveRecord::DeleteRestrictionError
      render_error "DeleteRestrictionError",
                   message: "IP Pool cannot be removed because it still has associated addresses or servers",
                   status: :unprocessable_entity
    end

    # GET /api/v1/ip_pools/organisation
    #
    # Response:
    #   An array of IP pools assigned to the organization, ordered by name
    def organisation
      logger.info "1. Organization IP Pools - Organisation action started"
      puts "1. Organization IP Pools - Organisation action started"

      if @organization.nil?
        logger.error "2. Organization is nil"
        puts "2. Organization is nil"
        render_error("OrganizationNotFound", message: "Organization not found")
        return
      end

      logger.info "3. Organization found: #{@organization.id} - #{@organization.name}"
      puts "3. Organization found: #{@organization.id} - #{@organization.name}"

      ip_pools = @organization.ip_pools.order(:name)
      if ip_pools.any?
        logger.info "4. IP pools found: #{ip_pools.map(&:id).join(", ")}"
        puts "4. IP pools found: #{ip_pools.map(&:id).join(", ")}"
        render_success ip_pools: ip_pools.map(&:attributes)
      else
        logger.info "5. No IP pools found"
        puts "5. No IP pools found"
        render_success ip_pools: [], message: "No IP pools found for the organization"
      end
    end

    # POST /api/v1/ip_pools/assignments
    #
    # Parameters:
    #   ip_pools => REQ: An array of IP pool IDs to assign to the organization
    #
    # Response:
    #   Success message upon assignment
    def assignments
      logger.info "6. Organization IP Pools - Assignments action started"
      puts "6. Organization IP Pools - Assignments action started"

      if @organization.nil?
        logger.error "7. Organization is nil"
        puts "7. Organization is nil"
        render_error("OrganizationNotFound", message: "Organization not found")
        return
      end

      logger.info "8. Organization found: #{@organization.id} - #{@organization.name}"
      puts "8. Organization found: #{@organization.id} - #{@organization.name}"

      if params[:ip_pools].blank?
        logger.error "9. ip_pools parameter is missing"
        puts "9. ip_pools parameter is missing"
        render_parameter_error "`ip_pools` parameter is required but missing"
        return
      end

      requested_ip_pools = params[:ip_pools]
      logger.info "10. Requested IP pools: #{requested_ip_pools.inspect}"
      puts "10. Requested IP pools: #{requested_ip_pools.inspect}"

      @organization.ip_pool_ids = requested_ip_pools
      if @organization.save
        logger.info "13. Organization IP pools updated successfully"
        puts "13. Organization IP pools updated successfully"
        render_success message: "Organization IP pools have been updated successfully"
      else
        logger.error "14. Failed to save organization IP pools"
        puts "14. Failed to save organization IP pools"
        render_error "SaveError",
                     message: @organization.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/add_pool
    #
    # Parameters:
    #   organization_id => REQ: The ID of the organization to add the IP pool to
    #   ip_pool_id      => REQ: The ID of the IP pool to add
    #
    # Response:
    #   Success message upon adding the IP pool
    def add_pool
      logger.info "1. Add IP Pool to Organization - Action started"
      puts "1. Add IP Pool to Organization - Action started"

      if @organization.nil?
        logger.error "2. Organization is nil"
        puts "2. Organization is nil"
        render_error("OrganizationNotFound", message: "Organization not found")
        return
      end

      ip_pool_id = params[:ip_pool_id].to_i
      logger.info "3. IP Pool ID to add: #{ip_pool_id}"
      puts "3. IP Pool ID to add: #{ip_pool_id}"

      # Get the current IP pool IDs assigned to the organization
      current_ip_pool_ids = @organization.ip_pool_ids
      logger.info "4. Current IP Pool IDs: #{current_ip_pool_ids.inspect}"
      puts "4. Current IP Pool IDs: #{current_ip_pool_ids.inspect}"

      if current_ip_pool_ids.include?(ip_pool_id)
        logger.info "5. IP Pool ID already assigned to the organization"
        puts "5. IP Pool ID already assigned to the organization"
        render_success message: "IP Pool already assigned to the organization"
        return
      end

      # Add the new IP pool ID
      updated_ip_pool_ids = current_ip_pool_ids + [ip_pool_id]
      logger.info "6. Updated IP Pool IDs: #{updated_ip_pool_ids.inspect}"
      puts "6. Updated IP Pool IDs: #{updated_ip_pool_ids.inspect}"

      # Assign the updated IP pool IDs back to the organization
      @organization.ip_pool_ids = updated_ip_pool_ids
      if @organization.save
        logger.info "7. IP Pool added successfully"
        puts "7. IP Pool added successfully"
        @organization.reload # Reload to ensure associations are updated
        render_success message: "IP Pool added to organization successfully"
      else
        logger.error "8. Failed to add IP Pool: #{@organization.errors.full_messages}"
        puts "8. Failed to add IP Pool: #{@organization.errors.full_messages}"
        render_error "SaveError",
                     message: @organization.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    # POST /api/v1/ip_pools/remove_pool
    #
    # Parameters:
    #   organization_id => REQ: The ID of the organization to remove the IP pool from
    #   ip_pool_id      => REQ: The ID of the IP pool to remove
    #
    # Response:
    #   Success message upon removing the IP pool
    def remove_pool
      logger.info "9. Remove IP Pool from Organization - Action started"
      puts "9. Remove IP Pool from Organization - Action started"

      if @organization.nil?
        logger.error "10. Organization is nil"
        puts "10. Organization is nil"
        render_error("OrganizationNotFound", message: "Organization not found")
        return
      end

      ip_pool_id = params[:ip_pool_id].to_i
      logger.info "11. IP Pool ID to remove: #{ip_pool_id}"
      puts "11. IP Pool ID to remove: #{ip_pool_id}"

      # Get the current IP pool IDs assigned to the organization
      current_ip_pool_ids = @organization.ip_pool_ids
      logger.info "12. Current IP Pool IDs: #{current_ip_pool_ids.inspect}"
      puts "12. Current IP Pool IDs: #{current_ip_pool_ids.inspect}"

      unless current_ip_pool_ids.include?(ip_pool_id)
        logger.error "13. IP Pool ID not assigned to the organization"
        puts "13. IP Pool ID not assigned to the organization"
        render_error "IPPoolNotAssigned",
                     message: "The specified IP pool is not assigned to this organization",
                     id: ip_pool_id,
                     status: :unprocessable_entity
        return
      end

      # Remove the specified IP pool ID
      updated_ip_pool_ids = current_ip_pool_ids - [ip_pool_id]
      logger.info "14. Updated IP Pool IDs: #{updated_ip_pool_ids.inspect}"
      puts "14. Updated IP Pool IDs: #{updated_ip_pool_ids.inspect}"

      # Assign the updated IP pool IDs back to the organization
      @organization.ip_pool_ids = updated_ip_pool_ids
      if @organization.save
        logger.info "15. IP Pool removed successfully"
        puts "15. IP Pool removed successfully"
        @organization.reload # Reload to ensure associations are updated
        render_success message: "IP Pool removed from organization successfully"
      else
        logger.error "16. Failed to remove IP Pool: #{@organization.errors.full_messages}"
        puts "16. Failed to remove IP Pool: #{@organization.errors.full_messages}"
        render_error "SaveError",
                     message: @organization.errors.full_messages.to_sentence,
                     status: :unprocessable_entity
      end
    end

    private

    # Setting the organization for the API request
    def set_organization
      logger.info "17. set_organization method called"
      puts "17. set_organization method called"
      logger.info "Params: #{params.inspect}"
      puts "Params: #{params.inspect}"

      if params[:organization_id].present?
        @organization = Organization.find_by(id: params[:organization_id])
        logger.info "18. Organization found by params: #{@organization.inspect}"
        puts "18. Organization found by params: #{@organization.inspect}"
      elsif current_user&.organization
        @organization = current_user.organization
        logger.info "19. Organization found by current_user: #{@organization.inspect}"
        puts "19. Organization found by current_user: #{@organization.inspect}"
      else
        @organization = nil
        logger.error "20. Organization not found"
        puts "20. Organization not found"
      end
    end

    # Permitting necessary parameters for API requests
    def api_params
      logger.info "21. api_params method called"
      puts "21. api_params method called"
      params.permit(:id, :ip_pool_id, ip_pool: [:name, :default], ip_pools: [])
    end
  end
end
