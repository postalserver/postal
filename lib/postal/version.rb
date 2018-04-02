module Postal

  VERSION = '1.0.0'
  REVISION = '67d0f6514d'
  CHANNEL = 'stable'

  def self.version
    [VERSION, REVISION, CHANNEL].compact.join('-')
  end

end
