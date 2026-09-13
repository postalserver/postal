# frozen_string_literal: true

module API
  module V2
    class DomainsController < BaseController

      before_action { @organization = scoped_organization!(params[:organization_uuid]) }
      before_action { @server = @organization&.servers&.present&.find_by!(uuid: params[:server_uuid]) }
      before_action(only: [:show, :destroy, :verify, :check_dns]) do
        @domain = @server&.domains&.find_by!(uuid: params[:uuid])
      end

      def index
        require_scope!("domains:read")
        return if performed? || @server.nil?

        scope, meta = pagination_for(@server.domains.order(:name))
        render_data(scope.map { |domain| serialize(domain) }, meta: meta)
      end

      def show
        require_scope!("domains:read")
        return if performed? || @domain.nil?

        render_data(serialize(@domain))
      end

      def create
        require_scope!("domains:write")
        return if performed? || @server.nil?

        with_idempotency do
          domain = @server.domains.create!(domain_params)
          audit!(organization: @organization, resource: domain, action: "domain.created", after: serialize(domain))
          render_data(serialize(domain), status: :created)
        end
      end

      def destroy
        require_scope!("domains:write")
        return if performed? || @domain.nil?

        with_idempotency do
          @domain.destroy!
          audit!(organization: @organization, resource: @domain, action: "domain.deleted")
          head :no_content
        end
      end

      def verify
        require_scope!("domains:write")
        return if performed? || @domain.nil?

        with_idempotency do
          @domain.verify_with_dns
          audit!(organization: @organization, resource: @domain, action: "domain.verify_requested", after: serialize(@domain))
          render_data(serialize(@domain))
        end
      end

      def check_dns
        require_scope!("domains:write")
        return if performed? || @domain.nil?

        with_idempotency do
          @domain.verify_with_dns unless @domain.verified?
          @domain.check_dns(:manual)
          dmarc = dmarc_status(@domain)
          audit!(organization: @organization, resource: @domain, action: "domain.dns_checked", after: serialize(@domain, dmarc: dmarc))
          render_data(serialize(@domain, dmarc: dmarc))
        end
      end

      private

      def domain_params
        params.permit(:name, :verification_method, :outgoing, :incoming, :use_for_any).tap do |attributes|
          attributes[:verification_method] ||= "DNS"
        end
      end

      def serialize(domain, dmarc: nil)
        {
          uuid: domain.uuid, name: domain.name, verified: domain.verified?, use_for_any: domain.use_for_any?, verification_method: domain.verification_method,
          dns_records: {
            verification: { type: "TXT", name: domain.name, value: domain.dns_verification_string },
            spf: { type: "TXT", name: domain.name, value: domain.spf_record },
            dkim: { type: "TXT", name: "#{domain.dkim_record_name}.#{domain.name}", value: domain.dkim_record },
            dmarc: { type: "TXT", name: "_dmarc.#{domain.name}", value: "v=DMARC1; p=none; adkim=s; aspf=s" },
            return_path: { type: "CNAME", name: domain.return_path_domain, value: Postal::Config.dns.return_path_domain },
            mx: Array(Postal::Config.dns.mx_records)
          },
          dns_status: { checked_at: domain.dns_checked_at, spf: status(domain, :spf), dkim: status(domain, :dkim), dmarc: dmarc || { status: "Pending", error: "Run Check DNS to verify the DMARC record." }, mx: status(domain, :mx), return_path: status(domain, :return_path) }
        }
      end

      def status(domain, type)
        { status: domain.public_send("#{type}_status"), error: domain.public_send("#{type}_error") }
      end

      def dmarc_status(domain)
        records = domain.resolver.txt("_dmarc.#{domain.name}")
        record = records.find { |value| value.match?(/\Av=DMARC1(?:;|\s|$)/i) }
        return { status: "Missing", error: "No DMARC record exists for this domain." } if record.nil?

        return { status: "Invalid", error: "The DMARC record must include a valid p= policy." } unless record.match?(/(?:\A|;)\s*p=(?:none|quarantine|reject)(?:;|\s|$)/i)

        { status: "OK", error: nil }
      rescue DNSResolver::LocalResolversUnavailableError, Resolv::ResolvError
        { status: "Pending", error: "Unable to check DMARC right now. Try again shortly." }
      end

    end
  end
end
