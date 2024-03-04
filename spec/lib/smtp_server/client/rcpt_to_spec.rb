# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "RCPT TO" do
      let(:helo) { "test.example.com" }
      let(:mail_from) { "test@example.com" }

      before do
        client.handle("HELO #{helo}")
        client.handle("MAIL FROM: #{mail_from}") if mail_from
      end

      context "when MAIL FROM has not been sent" do
        let(:mail_from) { nil }

        it "returns an error if RCPT TO is sent before MAIL FROM" do
          expect(client.handle("RCPT TO: no-route-here@internal.com")).to eq "503 EHLO/HELO and MAIL FROM first please"
          expect(client.state).to eq :welcomed
        end
      end

      it "returns an error if RCPT TO is not valid" do
        expect(client.handle("RCPT TO: blah")).to eq "501 Invalid RCPT TO"
      end

      it "returns an error if RCPT TO is empty" do
        expect(client.handle("RCPT TO: ")).to eq "501 RCPT TO should not be empty"
      end

      context "when the RCPT TO address is the system return path host" do
        it "returns an error if the server does not exist" do
          expect(client.handle("RCPT TO: nothing@#{Postal::Config.dns.return_path_domain}")).to eq "550 Invalid server token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          expect(client.handle("RCPT TO: #{server.token}@#{Postal::Config.dns.return_path_domain}"))
            .to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          address = "#{server.token}@#{Postal::Config.dns.return_path_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:bounce, address, server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when the RCPT TO address is on a host using the return path prefix" do
        it "returns an error if the server does not exist" do
          address = "nothing@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Invalid server token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          address = "#{server.token}@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          address = "#{server.token}@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:bounce, address, server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when the RCPT TO address is within the route domain" do
        it "returns an error if the route token is invalid" do
          address = "nothing@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Invalid route token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          route = create(:route, server: server)
          address = "#{route.token}@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "returns an error if the route is set to Reject mail" do
          server = create(:server)
          route = create(:route, server: server, mode: "Reject")
          address = "#{route.token}@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Route does not accept incoming messages"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          route = create(:route, server: server)
          address = "#{route.token}+tag1@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:route, "#{route.name}+tag1@#{route.domain.name}", server, { route: route }]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when authenticated and the RCPT TO address is provided" do
        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          credential = create(:credential, server: server, type: "SMTP")
          expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 Granted for /)
          expect(client.handle("RCPT TO: outgoing@example.com")).to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          credential = create(:credential, server: server, type: "SMTP")
          expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 Granted for /)
          expect(client.handle("RCPT TO: outgoing@example.com")).to eq "250 OK"
          expect(client.recipients).to eq [[:credential, "outgoing@example.com", server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when not authenticated and the RCPT TO address is a route" do
        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          route = create(:route, server: server)
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "returns an error if the route is set to Reject mail" do
          server = create(:server)
          route = create(:route, server: server, mode: "Reject")
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Route does not accept incoming messages"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          route = create(:route, server: server)
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:route, address, server, { route: route }]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when not authenticated and RCPT TO does not match a route" do
        it "returns an error" do
          expect(client.handle("RCPT TO: nothing@nothing.com")).to eq "530 Authentication required"
        end

        context "when the connecting IP has an credential" do
          it "adds a recipient" do
            server = create(:server)
            create(:credential, server: server, type: "SMTP-IP", key: "1.0.0.0/8")
            address = "test@example.com"
            expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
            expect(client.recipients).to eq [[:credential, address, server]]
            expect(client.state).to eq :rcpt_to_received
          end
        end
      end
    end
  end

end
