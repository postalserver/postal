# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ruby runtime (YJIT)" do
  it "is built with YJIT support" do
    expect(defined?(RubyVM::YJIT)).to eq("constant")
    expect(RubyVM::YJIT.respond_to?(:enabled?)).to be(true)
  end

  it "leaves YJIT off unless explicitly enabled" do
    enabled = ENV.fetch("RUBY_YJIT_ENABLE", nil) == "1"
    expect(RubyVM::YJIT.enabled?).to eq(enabled)
  end

  it "exposes runtime stats" do
    skip "YJIT is not enabled in this process" unless RubyVM::YJIT.enabled?

    stats = RubyVM::YJIT.runtime_stats
    expect(stats).to respond_to(:keys)
    expect(stats.keys).to include(:live_page_count)
  end
end
