module Postal
  module FastServer
    extend ActiveSupport::Autoload
    eager_autoload do
      autoload :Client
      autoload :HTTPHeader
      autoload :HTTPHeaderSet
      autoload :Interface
      autoload :Server
    end
  end
end
