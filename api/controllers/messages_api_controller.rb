controller :messages do
  friendly_name "Messages API"
  description "This API allows you to access message details"
  authenticator :server

  action :stats do
    title "Message stats"
    description "This action will display stats"

    returns Hash

    action do
      server = identity.server
      {
              host_domain: request.headers['HOST'],
              held_messages: server.held_messages,
              queued_messages: server.queue_size,
              bounce_rate: server.bounce_rate,
              used: server.message_db.total_size,
              message_throughput: {
                      outgoing_messages: server.throughput_stats[:outgoing],
                      incoming_messages: server.throughput_stats[:incoming],
                      message_rate: server.message_rate
              }
      }
    end
  end

  action :message do
    title "Return message details"
    description "Returns all details about a message"
    param :id, "The ID of the message", :type => Integer, :required => true
    returns Hash, :structure => :message, :structure_opts => {:paramable => {:expansions => false}}
    error 'MessageNotFound', "No message found matching provided ID", :attributes => {:id => "The ID of the message"}
    action do
      begin
        message = identity.server.message(params.id)
      rescue Postal::MessageDB::Message::NotFound => e
        error 'MessageNotFound', :id => params.id
      end
      structure :message, message, :return => true
    end
  end

  action :deliveries do
    title "Return deliveries for a message"
    description "Returns an array of deliveries which have been attempted for this message"
    param :id, "The ID of the message", :type => Integer, :required => true
    returns Array, :structure => :delivery, :structure_opts => {:full => true}
    error 'MessageNotFound', "No message found matching provided ID", :attributes => {:id => "The ID of the message"}
    action do
      begin
        message = identity.server.message(params.id)
      rescue Postal::MessageDB::Message::NotFound => e
        error 'MessageNotFound', :id => params.id
      end
      message.deliveries.map do |d|
        structure :delivery, d
      end
    end
  end

end
