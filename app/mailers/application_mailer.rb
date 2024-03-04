# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base

  default from: "#{Postal::Config.smtp.from_name} <#{Postal::Config.smtp.from_address}>"
  layout false

end
