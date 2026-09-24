# frozen_string_literal: true

require "rails_helper"

module Postal

  describe TLS do
    describe ".version_constant" do
      it "maps the configured names onto the OpenSSL constants" do
        expect(described_class.version_constant("1.0")).to eq OpenSSL::SSL::TLS1_VERSION
        expect(described_class.version_constant("1.1")).to eq OpenSSL::SSL::TLS1_1_VERSION
        expect(described_class.version_constant("1.2")).to eq OpenSSL::SSL::TLS1_2_VERSION
      end

      it "returns nil when no version is configured" do
        expect(described_class.version_constant(nil)).to be_nil
        expect(described_class.version_constant("")).to be_nil
      end

      it "refuses a name it does not recognise rather than falling back" do
        expect { described_class.version_constant("2.0") }.to raise_error(Postal::Error)
      end

      it "offers the configured names it can honour" do
        expect(described_class::VERSIONS.keys).to include("1.0", "1.1", "1.2")
        expect(described_class::VERSIONS).to be_frozen
      end

      it "maps 1.3 when the build can negotiate it, and refuses it when it cannot" do
        if defined?(OpenSSL::SSL::TLS1_3_VERSION) && described_class::VERSIONS.key?("1.3")
          expect(described_class.version_constant("1.3")).to eq OpenSSL::SSL::TLS1_3_VERSION
        else
          expect { described_class.version_constant("1.3") }.to raise_error(Postal::Error)
        end
      end

      it "coerces a value which is not a string" do
        expect(described_class.version_constant(1.2)).to eq OpenSSL::SSL::TLS1_2_VERSION
      end
    end

    describe ".apply_version_limits" do
      subject(:context) { OpenSSL::SSL::SSLContext.new }

      # OpenSSL exposes the version writers but not the matching readers, so the
      # range cannot be asserted by reading it back. The mapping above is where
      # the meaning of a version name lives; these examples cover that the range
      # is accepted, that a bad name is not, and that a context left alone is
      # unchanged.
      it "accepts a floor" do
        expect(described_class.apply_version_limits(context, min: "1.2")).to be context
      end

      it "accepts a floor and a ceiling" do
        expect(described_class.apply_version_limits(context, min: "1.0", max: "1.2")).to be context
      end

      it "refuses an unknown floor rather than leaving the context at its default" do
        expect { described_class.apply_version_limits(context, min: "9.9") }.to raise_error(Postal::Error)
      end

      it "refuses an unknown ceiling" do
        expect { described_class.apply_version_limits(context, max: "9.9") }.to raise_error(Postal::Error)
      end

      it "accepts a ceiling on its own" do
        expect(described_class.apply_version_limits(context, max: "1.2")).to be context
      end

      it "refuses an unknown floor even when a ceiling is also given" do
        expect { described_class.apply_version_limits(context, min: "0.9", max: "1.2") }
          .to raise_error(Postal::Error)
      end

      it "leaves a context alone when nothing is configured" do
        described_class.apply_version_limits(context, min: nil, max: nil)

        expect(context.verify_mode).to eq OpenSSL::SSL::VERIFY_NONE
      end
    end
  end

  describe SMTPClient::Endpoint do
    # The contexts are memoised on the class, so each example builds its own.
    before do
      described_class.instance_variable_set(:@ssl_context_with_verify, nil)
      described_class.instance_variable_set(:@ssl_context_without_verify, nil)
    end

    describe "the TLS contexts it offers" do
      it "verifies the peer for an endpoint which asks for TLS" do
        expect(described_class.ssl_context_with_verify.verify_mode).to eq OpenSSL::SSL::VERIFY_PEER
      end

      it "does not verify the peer for an opportunistic endpoint" do
        expect(described_class.ssl_context_without_verify.verify_mode).to eq OpenSSL::SSL::VERIFY_NONE
      end

      it "trusts the system certificate store when it does verify" do
        expect(described_class.ssl_context_with_verify.cert_store).to be_a(OpenSSL::X509::Store)
      end

      it "builds a context even when the floor is lowered for a legacy server" do
        allow(Postal::Config.smtp_client).to receive(:minimum_tls_version).and_return("1.0")

        expect(described_class.ssl_context_without_verify.verify_mode).to eq OpenSSL::SSL::VERIFY_NONE
      end

      it "refuses to build a context from an unusable version name" do
        allow(Postal::Config.smtp_client).to receive(:minimum_tls_version).and_return("ssl3")

        expect { described_class.ssl_context_without_verify }.to raise_error(Postal::Error)
      end
    end
  end

end
