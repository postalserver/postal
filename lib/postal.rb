module Postal

  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :AppLogger
    autoload :BounceMessage
    autoload :Config
    autoload :Countries
    autoload :DKIMHeader
    autoload :Error
    autoload :Helpers
    autoload :HTTP
    autoload :HTTPSender
    autoload :Job
    autoload :MessageDB
    autoload :MessageInspection
    autoload :MessageInspector
    autoload :MessageInspectors
    autoload :MessageParser
    autoload :MessageRequeuer
    autoload :MXLookup
    autoload :QueryString
    autoload :RabbitMQ
    autoload :ReplySeparator
    autoload :RspecHelpers
    autoload :Sender
    autoload :SendResult
    autoload :SMTPSender
    autoload :SMTPServer
    autoload :SpamCheck
    autoload :TrackingMiddleware
    autoload :UserCreator
    autoload :Version
    autoload :Worker
  end

  def self.eager_load!
    super
    Postal::MessageDB.eager_load!
    Postal::SMTPServer.eager_load!
    Postal::MessageInspectors.eager_load!
  end

end
