# frozen_string_literal: true

module ManagementAPI
  class TrackDomainsController < BaseController

    # GET /management/api/v1/servers/:server_id/track_domains
    # List all track domains for a server
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "track_domains": [
    #       { "uuid": "xxx", "name": "track", "full_name": "track.example.com", ... }
    #     ]
    #   }
    # }
    def index
      server = find_server(params[:server_id])
      track_domains = server.track_domains.includes(:domain)

      render_success(
        track_domains: track_domains.map { |td| track_domain_to_hash(td) }
      )
    end

    # GET /management/api/v1/servers/:server_id/track_domains/:uuid
    # Get a specific track domain
    def show
      server = find_server(params[:server_id])
      track_domain = server.track_domains.find_by!(uuid: params[:id])

      render_success(track_domain: track_domain_to_hash(track_domain, include_details: true))
    end

    # POST /management/api/v1/servers/:server_id/track_domains
    # Create a new track domain
    #
    # Required params:
    #   name - subdomain name (e.g., "track" for track.example.com)
    #   domain_uuid - UUID of the domain
    #
    # Optional params:
    #   ssl_enabled - enable SSL for tracking (default: true)
    #   track_clicks - track click events (default: true)
    #   track_loads - track email open events (default: true)
    #   excluded_click_domains - newline-separated list of domains to exclude from click tracking
    #
    # Response:
    # {
    #   "status": "success",
    #   "data": {
    #     "track_domain": { ... }
    #   }
    # }
    def create
      server = find_server(params[:server_id])
      domain = find_domain_for_server(server, api_params[:domain_uuid])

      track_domain = server.track_domains.create!(
        name: api_params[:name],
        domain: domain,
        ssl_enabled: api_params[:ssl_enabled] != false && api_params[:ssl_enabled] != "false",
        track_clicks: api_params[:track_clicks] != false && api_params[:track_clicks] != "false",
        track_loads: api_params[:track_loads] != false && api_params[:track_loads] != "false",
        excluded_click_domains: api_params[:excluded_click_domains]
      )

      render_success(track_domain: track_domain_to_hash(track_domain, include_details: true))
    end

    # PATCH /management/api/v1/servers/:server_id/track_domains/:uuid
    # Update a track domain
    #
    # Params:
    #   ssl_enabled - enable SSL for tracking
    #   track_clicks - track click events
    #   track_loads - track email open events
    #   excluded_click_domains - newline-separated list of domains to exclude
    def update
      server = find_server(params[:server_id])
      track_domain = server.track_domains.find_by!(uuid: params[:id])

      update_params = {}
      if api_params.key?(:ssl_enabled)
        update_params[:ssl_enabled] = api_params[:ssl_enabled] == true || api_params[:ssl_enabled] == "true"
      end
      if api_params.key?(:track_clicks)
        update_params[:track_clicks] = api_params[:track_clicks] == true || api_params[:track_clicks] == "true"
      end
      if api_params.key?(:track_loads)
        update_params[:track_loads] = api_params[:track_loads] == true || api_params[:track_loads] == "true"
      end
      if api_params.key?(:excluded_click_domains)
        update_params[:excluded_click_domains] = api_params[:excluded_click_domains]
      end

      track_domain.update!(update_params)

      render_success(track_domain: track_domain_to_hash(track_domain, include_details: true))
    end

    # DELETE /management/api/v1/servers/:server_id/track_domains/:uuid
    # Delete a track domain
    def destroy
      server = find_server(params[:server_id])
      track_domain = server.track_domains.find_by!(uuid: params[:id])

      track_domain.destroy!
      render_success(message: "Track domain '#{track_domain.full_name}' has been deleted")
    end

    # POST /management/api/v1/servers/:server_id/track_domains/:uuid/check_dns
    # Check DNS configuration for track domain
    def check_dns
      server = find_server(params[:server_id])
      track_domain = server.track_domains.find_by!(uuid: params[:id])

      track_domain.check_dns

      render_success(
        track_domain: track_domain_to_hash(track_domain, include_details: true),
        dns_ok: track_domain.dns_ok?
      )
    end

    # POST /management/api/v1/servers/:server_id/track_domains/:uuid/toggle_ssl
    # Toggle SSL for track domain
    def toggle_ssl
      server = find_server(params[:server_id])
      track_domain = server.track_domains.find_by!(uuid: params[:id])

      track_domain.update!(ssl_enabled: !track_domain.ssl_enabled?)

      render_success(
        track_domain: track_domain_to_hash(track_domain),
        ssl_enabled: track_domain.ssl_enabled?
      )
    end

    private

    def find_domain_for_server(server, uuid)
      domain = server.domains.find_by(uuid: uuid)
      domain ||= server.organization.domains.find_by!(uuid: uuid)
      domain
    end

    def track_domain_to_hash(track_domain, include_details: false)
      hash = {
        uuid: track_domain.uuid,
        name: track_domain.name,
        full_name: track_domain.full_name,
        domain: {
          uuid: track_domain.domain.uuid,
          name: track_domain.domain.name
        },
        ssl_enabled: track_domain.ssl_enabled?,
        track_clicks: track_domain.track_clicks?,
        track_loads: track_domain.track_loads?,
        dns_status: track_domain.dns_status,
        dns_error: track_domain.dns_error,
        dns_checked_at: track_domain.dns_checked_at,
        created_at: track_domain.created_at,
        updated_at: track_domain.updated_at
      }

      if include_details
        hash[:excluded_click_domains] = track_domain.excluded_click_domains_array
        hash[:cname_record] = {
          hostname: track_domain.full_name,
          type: "CNAME",
          value: Postal::Config.dns.track_domain
        }
      end

      hash
    end

  end
end
