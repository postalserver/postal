module Postal

  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :AppLogger
    autoload :BounceMessage
    autoload :Config
    autoload :Countries
    autoload :DKIMHeader
    autoload :Error
    autoload :FastServer
    autoload :Helpers
    autoload :HTTP
    autoload :HTTPSender
    autoload :Job
    autoload :LetsEncrypt
    autoload :MessageDB
    autoload :MessageInspection
    autoload :MessageParser
    autoload :MessageRequeuer
    autoload :QueryString
    autoload :RabbitMQ
    autoload :ReplySeparator
    autoload :RspecHelpers
    autoload :SendResult
    autoload :Sender
    autoload :SMTPSender
    autoload :SMTPServer
    autoload :SpamCheck
    autoload :UserCreator
    autoload :Version
    autoload :Worker
  end

  def self.eager_load!
    super
    Postal::MessageDB.eager_load!
    Postal::FastServer.eager_load!
    Postal::SMTPServer.eager_load!
  end

end
