# frozen_string_literal: true

Rails.autoloaders.each do |autoloader|
  # Ignore the message DB migrations directory as it doesn't follow
  # Zeitwerk's conventions and is always loaded and executed in order.
  autoloader.ignore(Rails.root.join("lib/postal/message_db/migrations"))
end
