# frozen_string_literal: true

module ManagementAPI
  class SuppressionsController < BaseController

    # GET /management/api/v1/servers/:server_id/suppressions
    # List suppressions for a server
    #
    # Params:
    #   type - "bounce", "complaint", "manual" (optional, filter by type)
    #   page - page number (default: 1)
    #   per_page - items per page (default: 50, max: 100)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "suppressions": [...],
    #     "pagination": { ... }
    #   }
    # }
    def index
      server = find_server(params[:server_id])

      page = (api_params[:page] || 1).to_i
      per_page = [(api_params[:per_page] || 50).to_i, 100].min

      conditions = {}
      conditions[:type] = api_params[:type] if api_params[:type].present?

      suppressions = server.message_db.suppressions(
        where: conditions,
        page: page,
        per_page: per_page
      )

      total = server.message_db.suppressions_count(where: conditions)

      render_success(
        suppressions: suppressions.map { |s| suppression_to_hash(s) },
        pagination: {
          page: page,
          per_page: per_page,
          total: total,
          total_pages: (total.to_f / per_page).ceil
        }
      )
    end

    # GET /management/api/v1/servers/:server_id/suppressions/check
    # Check if an address is suppressed
    #
    # Params:
    #   address - email address to check
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "address": "user@example.com",
    #     "suppressed": true,
    #     "suppression": { ... }
    #   }
    # }
    def check
      server = find_server(params[:server_id])
      address = api_params[:address]

      unless address.present?
        render_error "MissingParameter", message: "address parameter is required"
        return
      end

      suppression = server.message_db.suppression_list.get(address)

      if suppression
        render_success(
          address: address,
          suppressed: true,
          suppression: suppression_to_hash(suppression)
        )
      else
        render_success(
          address: address,
          suppressed: false,
          suppression: nil
        )
      end
    end

    # POST /management/api/v1/servers/:server_id/suppressions
    # Add a suppression
    #
    # Required params:
    #   address - email address to suppress
    #
    # Optional params:
    #   reason - reason for suppression
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "suppression": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])
      address = api_params[:address]
      reason = api_params[:reason] || "Added via Management API"

      unless address.present?
        render_error "MissingParameter", message: "address parameter is required"
        return
      end

      # Check if already suppressed
      existing = server.message_db.suppression_list.get(address)
      if existing
        render_error "AlreadySuppressed", message: "Address is already suppressed"
        return
      end

      suppression = server.message_db.suppression_list.add(
        type: "manual",
        address: address,
        reason: reason
      )

      render_success(suppression: suppression_to_hash(suppression))
    end

    # DELETE /management/api/v1/servers/:server_id/suppressions/:address
    # Remove a suppression
    def destroy
      server = find_server(params[:server_id])
      address = params[:id]

      suppression = server.message_db.suppression_list.get(address)

      unless suppression
        raise ActiveRecord::RecordNotFound, "Suppression not found for address: #{address}"
      end

      server.message_db.suppression_list.remove(address)

      render_success(message: "Suppression for '#{address}' has been removed")
    end

    # POST /management/api/v1/servers/:server_id/suppressions/bulk
    # Bulk add suppressions
    #
    # Params:
    #   addresses - array of email addresses to suppress
    #   reason - reason for suppression (optional)
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "added": 10,
    #     "skipped": 2,
    #     "skipped_addresses": ["already@suppressed.com"]
    #   }
    # }
    def bulk_create
      server = find_server(params[:server_id])
      addresses = api_params[:addresses]
      reason = api_params[:reason] || "Bulk added via Management API"

      unless addresses.is_a?(Array) && addresses.any?
        render_error "MissingParameter", message: "addresses array is required"
        return
      end

      added = 0
      skipped = 0
      skipped_addresses = []

      addresses.each do |address|
        existing = server.message_db.suppression_list.get(address)
        if existing
          skipped += 1
          skipped_addresses << address
        else
          server.message_db.suppression_list.add(
            type: "manual",
            address: address,
            reason: reason
          )
          added += 1
        end
      end

      render_success(
        added: added,
        skipped: skipped,
        skipped_addresses: skipped_addresses
      )
    end

    # DELETE /management/api/v1/servers/:server_id/suppressions/bulk
    # Bulk remove suppressions
    #
    # Params:
    #   addresses - array of email addresses to unsuppress
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "removed": 10,
    #     "not_found": 2
    #   }
    # }
    def bulk_destroy
      server = find_server(params[:server_id])
      addresses = api_params[:addresses]

      unless addresses.is_a?(Array) && addresses.any?
        render_error "MissingParameter", message: "addresses array is required"
        return
      end

      removed = 0
      not_found = 0

      addresses.each do |address|
        existing = server.message_db.suppression_list.get(address)
        if existing
          server.message_db.suppression_list.remove(address)
          removed += 1
        else
          not_found += 1
        end
      end

      render_success(
        removed: removed,
        not_found: not_found
      )
    end

    private

    def suppression_to_hash(suppression)
      {
        address: suppression.address,
        type: suppression.type,
        reason: suppression.reason,
        timestamp: suppression.timestamp,
        keep_until: suppression.keep_until
      }
    end

  end
end
