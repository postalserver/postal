# frozen_string_literal: true

require "rails_helper"
require "haml"

# Compiles every HAML template and checks the Ruby it produces actually parses.
# A HAML major version bump changes the compiler, and the request specs only
# render a handful of pages, so without this most of app/views is unverified
# until someone visits the page in production.
RSpec.describe "HAML templates" do
  def compile(source)
    # Wrapped in a method body because layouts use `yield`, which is not legal
    # at the top level.
    RubyVM::AbstractSyntaxTree.parse("def _template\n#{Haml::Engine.new.call(source)}\nend")
  end

  templates = Dir[Rails.root.join("app/views/**/*.haml")]

  it "finds the templates to check" do
    expect(templates.size).to be > 50
  end

  # Without this, a change in how HAML reports errors could quietly turn every
  # example below into a no-op that passes on anything.
  describe "the check itself" do
    it "rejects a template whose Ruby does not parse" do
      expect { compile("= foo(\n") }.to raise_error(SyntaxError)
    end

    it "rejects a template with a malformed attribute hash" do
      expect { compile("%div{:a =>}\n") }.to raise_error(SyntaxError)
    end

    it "accepts a valid template" do
      expect { compile("%div\n  %p hello\n") }.to_not raise_error
    end
  end

  templates.each do |path|
    relative = path.sub("#{Rails.root}/", "")

    it "compiles #{relative}" do
      expect { compile(File.read(path)) }.to_not raise_error
    end
  end
end
