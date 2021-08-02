module Postal
  module MessageInspectors
    extend ActiveSupport::Autoload
    eager_autoload do
      autoload :Clamav
      autoload :SpamAssassin
    end
  end
end
