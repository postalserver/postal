# frozen_string_literal: true

require "rails_helper"

# A report is written by whoever sends it, so the parser treats the whole message
# as untrusted. What it must never do is leak an error from the mail library: the
# ingest path rescues this parser's own Error and nothing else, so anything else
# escaping would reach the SMTP transaction.
RSpec.describe Postal::TLSRpt::Parser do
  it "reports a parsing error, rather than raising something else, for a value which is not a message" do
    expect { described_class.new(nil).parse }.to raise_error(described_class::Error)
  end

  it "reports a parsing error for text which carries no report" do
    expect { described_class.new("this is not a message").parse }.to raise_error(described_class::Error)
  end

  it "wraps whatever the mail library raises for a message it cannot read" do
    allow(Mail).to receive(:new).and_raise(RuntimeError, "something the mail library did")

    expect { described_class.new("a message").parse }.to raise_error(described_class::Error, /could not be read/)
  end
end
