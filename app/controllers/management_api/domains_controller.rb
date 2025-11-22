# frozen_string_literal: true

module ManagementAPI
  class DomainsController < BaseController

    before_action :set_server
    before_action :set_domain, only: [:show, :update, :destroy, :verify, :check_dns]

    # GET /api/v2/management/servers/:server_id/domains
    def index
      authorize!(:domains, :read)

      scope = @server.domains.order(created_at: :desc)

      # Filtering
      scope = scope.where("name LIKE ?", "%#{api_params[:name]}%") if api_params[:name].present?
      scope = scope.verified if api_params[:verified] == "true"
      scope = scope.where(verified_at: nil) if api_params[:verified] == "false"

      result = paginate(scope)
      render_success(result[:records].map { |d| serialize_domain(d) }, meta: result[:meta])
    end

    # GET /api/v2/management/servers/:server_id/domains/:id
    def show
      authorize!(:domains, :read)
      render_success(serialize_domain(@domain, detailed: true))
    end

    # POST /api/v2/management/servers/:server_id/domains
    def create
      authorize!(:domains, :write)

      domain = @server.domains.new(domain_params)
      domain.owner = @server
      domain.verification_method = api_params[:verification_method] || "DNS"

      if domain.save
        render_created(serialize_domain(domain, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to create domain",
            details: domain.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # PATCH /api/v2/management/servers/:server_id/domains/:id
    def update
      authorize!(:domains, :write)

      if @domain.update(domain_params)
        render_success(serialize_domain(@domain, detailed: true))
      else
        render json: {
          status: "error",
          time: elapsed_time,
          error: {
            code: "ValidationError",
            message: "Failed to update domain",
            details: @domain.errors.to_hash
          }
        }, status: :unprocessable_entity
      end
    end

    # DELETE /api/v2/management/servers/:server_id/domains/:id
    def destroy
      authorize!(:domains, :delete)

      @domain.destroy
      render_deleted
    end

    # POST /api/v2/management/servers/:server_id/domains/:id/verify
    def verify
      authorize!(:domains, :write)

      if @domain.verified?
        render_success(serialize_domain(@domain, detailed: true).merge(already_verified: true))
        return
      end

      if @domain.verification_method == "DNS"
        if @domain.verify_with_dns
          render_success(serialize_domain(@domain.reload, detailed: true).merge(verified: true))
        else
          render_error("VerificationFailed", "DNS verification failed. Ensure TXT record is configured.", 400)
        end
      else
        render_error("ManualVerification", "Email verification requires manual process.", 400)
      end
    end

    # POST /api/v2/management/servers/:server_id/domains/:id/check_dns
    def check_dns
      authorize!(:domains, :read)

      @domain.check_dns
      @domain.reload

      render_success({
        uuid: @domain.uuid,
        name: @domain.name,
        dns_checked_at: @domain.dns_checked_at&.iso8601,
        dns_status: {
          spf: { status: @domain.spf_status, error: @domain.spf_error },
          dkim: { status: @domain.dkim_status, error: @domain.dkim_error },
          mx: { status: @domain.mx_status, error: @domain.mx_error },
          return_path: { status: @domain.return_path_status, error: @domain.return_path_error }
        },
        dns_ok: @domain.dns_ok?
      })
    end

    private

    def set_server
      @server = current_api_key.accessible_servers.find_by!(uuid: params[:server_id])
    rescue ActiveRecord::RecordNotFound
      @server = current_api_key.accessible_servers.find_by!(token: params[:server_id])
    end

    def set_domain
      @domain = @server.domains.find_by!(uuid: params[:id])
    rescue ActiveRecord::RecordNotFound
      @domain = @server.domains.find_by!(name: params[:id])
    end

    def domain_params
      {
        name: api_params[:name],
        outgoing: api_params[:outgoing],
        incoming: api_params[:incoming],
        use_for_any: api_params[:use_for_any]
      }.compact
    end

    def serialize_domain(domain, detailed: false)
      data = {
        uuid: domain.uuid,
        name: domain.name,
        verified: domain.verified?,
        verified_at: domain.verified_at&.iso8601,
        outgoing: domain.outgoing,
        incoming: domain.incoming,
        use_for_any: domain.use_for_any,
        created_at: domain.created_at&.iso8601,
        updated_at: domain.updated_at&.iso8601
      }

      if detailed
        data.merge!(
          verification_method: domain.verification_method,
          verification_token: domain.verification_token,
          dns_verification_string: domain.dns_verification_string,
          dkim_identifier: domain.dkim_identifier,
          dkim_record_name: domain.dkim_record_name,
          dkim_record: domain.dkim_record,
          spf_record: domain.spf_record,
          return_path_domain: domain.return_path_domain,
          dns_checked_at: domain.dns_checked_at&.iso8601,
          dns_status: {
            spf: { status: domain.spf_status, error: domain.spf_error },
            dkim: { status: domain.dkim_status, error: domain.dkim_error },
            mx: { status: domain.mx_status, error: domain.mx_error },
            return_path: { status: domain.return_path_status, error: domain.return_path_error }
          }
        )
      end

      data
    end

  end
end
