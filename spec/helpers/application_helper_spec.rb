# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#endpoint_options_for_select" do
    let(:server) { create(:server) }

    context "when an endpoint has HTML characters in its description" do
      let(:payload) { %q(x'"><script>alert(1)</script>) }

      before do
        create(:http_endpoint, server: server, name: payload)
      end

      it "HTML-escapes the endpoint description in the option text" do
        html = helper.endpoint_options_for_select(server)

        # The raw payload must not appear verbatim — if it does, the browser
        # will execute the <script> tag.
        expect(html).not_to include("<script>alert(1)</script>")

        # Escaped form should appear instead.
        expect(html).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
      end

      it "does not allow the payload to break out of the option tag" do
        html = helper.endpoint_options_for_select(server)

        # The ' and > characters in the payload must be escaped so they
        # cannot close the opening <option value='...'> or terminate the
        # element early.
        expect(html).not_to match(/<option[^>]*>[^<]*<script/)
      end
    end
  end
end
