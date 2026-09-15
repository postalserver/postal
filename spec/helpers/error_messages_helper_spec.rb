# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorMessagesHelper, type: :helper do
  describe "#error_messages_for" do
    let(:user) { User.new }

    context "when the record has no errors" do
      it "renders nothing" do
        expect(helper.error_messages_for(user)).to eq ""
      end
    end

    context "when the record is nil" do
      it "renders nothing" do
        expect(helper.error_messages_for(nil)).to eq ""
      end
    end

    context "when the record has errors" do
      before do
        user.valid?
      end

      it "renders the errorExplanation container the stylesheet targets" do
        html = helper.error_messages_for(user)
        expect(html).to include %(<div id="errorExplanation" class="errorExplanation">)
      end

      it "renders each full message as a list item" do
        html = helper.error_messages_for(user)
        user.errors.full_messages.each do |message|
          expect(html).to include "<li>#{ERB::Util.html_escape(message)}</li>"
        end
      end

      it "renders one list item per error" do
        html = helper.error_messages_for(user)
        expect(html.scan("<li>").size).to eq user.errors.count
      end

      it "returns an html_safe string" do
        expect(helper.error_messages_for(user)).to be_html_safe
      end
    end

    context "when an error message contains HTML" do
      before do
        user.errors.add(:base, %q(x'"><script>alert(1)</script>))
      end

      it "escapes it rather than emitting it verbatim" do
        html = helper.error_messages_for(user)
        expect(html).to_not include "<script>alert(1)</script>"
        expect(html).to include "&lt;script&gt;alert(1)&lt;/script&gt;"
      end
    end
  end
end
