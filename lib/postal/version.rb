module Postal

  VERSION = '1.0.0'
  REVISION = nil
  CHANNEL = 'dev'

  def self.version
    [VERSION, REVISION, CHANNEL].compact.join('-')
  end

end
