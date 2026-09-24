# frozen_string_literal: true

module Postal

  #
  # Require a gem which is only installed when its optional bundle group is
  # enabled, turning the LoadError into a message which tells the operator how
  # to enable it.
  #
  def self.require_optional_gem(name, group:)
    require name
  rescue LoadError
    raise Postal::Error, "This needs the optional '#{group}' bundle group (#{name}). Enable it " \
                         "with `bundle config set --local with #{group}`."
  end

end
