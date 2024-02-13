# frozen_string_literal: true

class HelpController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.find_by_permalink!(params[:server_id]) }

  def outgoing
    @credentials = @server.credentials.group_by(&:type)
  end

end
