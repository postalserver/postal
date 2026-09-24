# frozen_string_literal: true

require "rails_helper"

RSpec.describe Postal::Jemalloc do
  describe ".malloc_conf_for" do
    it "returns a MALLOC_CONF string for each known profile" do
      expect(described_class.malloc_conf_for("balanced")).to include("dirty_decay_ms:10000")
      expect(described_class.malloc_conf_for("aggressive")).to include("dirty_decay_ms:1000")
    end

    it "keeps thread-local caching on in every profile" do
      described_class::PROFILES.each_value do |conf|
        expect(conf).to include("tcache:true")
      end
    end

    it "aborts on invalid options rather than running misconfigured" do
      described_class::PROFILES.each_value do |conf|
        expect(conf).to include("abort_conf:true")
      end
    end

    it "sets max_background_threads so the decay thread actually spawns" do
      described_class::PROFILES.each_value do |conf|
        expect(conf).to include("max_background_threads:1")
      end
    end

    it "rejects unknown profiles" do
      expect { described_class.malloc_conf_for("phycpu") }.to raise_error(ArgumentError, /unknown jemalloc profile/)
      expect { described_class.malloc_conf_for(nil) }.to raise_error(ArgumentError, /unknown jemalloc profile/)
    end
  end

  describe ".lib_path" do
    it "finds the library when installed" do
      skip "libjemalloc2 is not installed in this image" unless system("ldconfig -p 2>/dev/null | grep -q libjemalloc.so.2")

      expect(described_class.lib_path).to end_with("libjemalloc.so.2")
    end

    it "returns nil when the library is absent" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(/libjemalloc/).and_return(false)
      allow(described_class).to receive(:`).and_return("")

      expect(described_class.lib_path).to be_nil
    end
  end
end
