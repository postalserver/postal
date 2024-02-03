module Postal

  VERSION_PATH = File.expand_path("../../VERSION", __dir__)
  if File.file?(VERSION_PATH)
    VERSION = File.read(VERSION_PATH).strip.delete_prefix("v")
  else
    VERSION = "0.0.0-dev"
  end

  def self.version
    VERSION
  end

  Version = VERSION

end
