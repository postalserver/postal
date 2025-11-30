# frozen_string_literal: true

module ManagementAPI
  module V2
    class DomainsController < BaseController

      before_action :find_server!
      before_action :check_server_access!
      before_action :find_domain!, only: [:show, :destroy, :verify, :check_dns]

      # GET /api/v2/management/servers/:server_uuid/domains
      def index
        domains = @server.domains
        domains = filter_domains(domains)
        domains = domains.order(created_at: :desc)
        domains, meta = paginate(domains)

        render_success(
          domains.map { |d| domain_json(d) },
          meta: meta
        )
      end

      # GET /api/v2/management/servers/:server_uuid/domains/:uuid
      def show
        render_success(domain_json(@domain, detailed: true))
      end

      # POST /api/v2/management/servers/:server_uuid/domains
      def create
        @domain = @server.domains.new(domain_params)
        @domain.owner = @server
        @domain.save!

        render_success(domain_json(@domain, detailed: true), status: :created)
      end

      # DELETE /api/v2/management/servers/:server_uuid/domains/:uuid
      def destroy
        @domain.destroy!
        render_success({ deleted: true, uuid: @domain.uuid })
      end

      # POST /api/v2/management/servers/:server_uuid/domains/:uuid/verify
      def verify
        if @domain.verified?
          render_error("AlreadyVerified", "Domain is already verified")
          return
        end

        if @domain.verification_method == "DNS"
          if @domain.verify_with_dns
            render_success(domain_json(@domain, detailed: true))
          else
            render_error("VerificationFailed", "DNS verification failed. Make sure the TXT record is configured correctly.")
          end
        else
          render_error("UnsupportedVerificationMethod", "Only DNS verification is supported via API")
        end
      end

      # POST /api/v2/management/servers/:server_uuid/domains/:uuid/check_dns
      def check_dns
        @domain.check_dns
        render_success(domain_json(@domain, detailed: true))
      end

      private

      def find_domain!
        @domain = @server.domains.find_by!(uuid: params[:uuid])
      end

      def check_server_access!
        return if current_api_key.super_admin?
        return if current_api_key.can_access_organization?(@server.organization)

        render_error("Forbidden", "You don't have access to this server", status: :forbidden)
      end

      def filter_domains(scope)
        scope = scope.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where.not(verified_at: nil) if params[:verified] == "true"
        scope = scope.where(verified_at: nil) if params[:verified] == "false"
        scope
      end

      def domain_params
        params.permit(:name, :verification_method, :outgoing, :incoming, :use_for_any)
      end

      def domain_json(domain, detailed: false)
        data = {
          uuid: domain.uuid,
          name: domain.name,
          verified: domain.verified?,
          verified_at: domain.verified_at&.iso8601,
          verification_method: domain.verification_method,
          outgoing: domain.outgoing,
          incoming: domain.incoming,
          use_for_any: domain.use_for_any,
          dns_ok: domain.dns_ok?,
          dns_checked_at: domain.dns_checked_at&.iso8601,
          created_at: domain.created_at.iso8601,
          updated_at: domain.updated_at.iso8601
        }

        if detailed
          data[:verification_token] = domain.verification_token
          data[:dns_verification_string] = domain.dns_verification_string
          data[:dkim_record_name] = domain.dkim_record_name
          data[:dkim_record] = domain.dkim_record
          data[:spf_record] = domain.spf_record
          data[:return_path_domain] = domain.return_path_domain

          data[:dns_status] = {
            spf: {
              status: domain.spf_status,
              error: domain.spf_error
            },
            dkim: {
              status: domain.dkim_status,
              error: domain.dkim_error
            },
            mx: {
              status: domain.mx_status,
              error: domain.mx_error
            },
            return_path: {
              status: domain.return_path_status,
              error: domain.return_path_error
            }
          }
        end

        data
      end

    end
  end
end
