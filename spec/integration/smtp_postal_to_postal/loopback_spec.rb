# frozen_string_literal: true

require "rails_helper"
require "socket"
require "net/smtp"

#
# Postal-to-Postal SMTP over real loopback sockets: one harness thread accepts
# connections and serves each through a real SMTPServer::Client, while
# Net::SMTP (the same library the outbound sender builds on) and
# SMTPClient::Endpoint drive the protocol. This exercises wire framing,
# EHLO capability parsing, and DATA termination in a way unit specs calling
# Client#handle directly never touch.
#
# The harness mirrors the real server loop's framing: it splits on LF and
# keeps the CR (only delete_suffix("\n") — chomp("\n") would strip the CR
# too, and the DATA terminator requires it).
#
# Isolated namespace: nothing here is shared with the mock-peer specs.
#
RSpec.describe "Postal-to-Postal SMTP", type: :integration do
  # The harness serves connections on worker threads sharing the main
  # connection pool, so transactional fixtures (invisible across threads)
  # cannot be used here; DatabaseCleaner truncates instead.
  self.use_transactional_tests = false

  before do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  after do
    DatabaseCleaner.clean
  end

  let(:server_record) { create(:server) }
  let(:domain) { create(:domain, owner: server_record) }
  let(:route) { create(:route, server: server_record, domain: domain) }

  let(:listen_port) { 12525 }

  def start_postal_smtp(port)
    tcp = TCPServer.new("127.0.0.1", port)
    errors = Queue.new
    sockets = Queue.new
    workers = Queue.new
    thread = Thread.new do
      loop do
        io = tcp.accept
        sockets << io
        workers << Thread.new(io) do |sock|
          client = SMTPServer::Client.new("127.0.0.1")
          sock.puts "220 ESMTP Postal/TEST"
          while (line = sock.gets)
            line = line.delete_suffix("\n")
            begin
              response = client.handle(line)
            rescue StandardError => e
              errors << "#{e.class}: #{e.message}"
              break
            end
            break if response.nil? && client.finished?
            unless response.nil?
              # The real server loop writes each reply line with CRLF.
              Array(response).each { |r| sock.write "#{r}\r\n" }
              break if client.finished?
            end
          end
          sock.close
        rescue StandardError => e
          errors << "#{e.class}: #{e.message}"
          sock.close rescue nil
        end
      end
    end
    [tcp, thread, errors, sockets, workers]
  end

  before do
    @tcp, @thread, @errors, @sockets, @workers = start_postal_smtp(listen_port)
  end

  after do
    # Close accepted sockets first so readers blocked in gets wake up, then
    # stop the acceptor. A forced close surfaces as IOError in the reader,
    # which is teardown noise rather than a handler failure.
    until @sockets.empty?
      begin
        @sockets.pop(true)&.close
      rescue StandardError
        nil
      end
    end
    until @workers.empty?
      begin
        @workers.pop(true)&.join(5)
      rescue StandardError
        nil
      end
    end
    @thread&.kill
    @thread&.join(2)
    @tcp&.close rescue nil
    genuine = []
    until @errors.empty?
      begin
        genuine << @errors.pop(true)
      rescue StandardError
        nil
      end
    end
    genuine = genuine.reject { |message| message.start_with?("IOError") }
    raise "SMTP harness errors: #{genuine.inspect}" unless genuine.empty?
  end

  def deliver(to:, from: "sender@example.com", body: "hello postal")
    Net::SMTP.start("127.0.0.1", listen_port) do |smtp|
      smtp.send_message(
        "From: #{from}\r\nTo: #{to}\r\nSubject: loopback\r\n\r\n#{body}\r\n",
        from, to
      )
    end
  end

  it "delivers a message for a known route into the message database" do
    deliver(to: "#{route.name}@#{domain.name}")

    queued = QueuedMessage.last
    expect(queued).not_to be_nil
    expect(queued.server).to eq server_record
    message = server_record.message(queued.message_id)
    expect(message.rcpt_to).to eq "#{route.name}@#{domain.name}"
    expect(message.scope).to eq "incoming"
  end

  it "refuses an unknown recipient without storing anything" do
    expect {
      begin
        deliver(to: "nobody@#{domain.name}")
      rescue Net::SMTPAuthenticationError, Net::SMTPFatalError
        nil
      end
    }.not_to(change { QueuedMessage.count })
  end

  it "sends through the outbound endpoint session API" do
    server = SMTPClient::Server.new("127.0.0.1", port: listen_port, ssl_mode: SMTPClient::SSLModes::NONE)
    endpoint = SMTPClient::Endpoint.new(server, "127.0.0.1")
    endpoint.start_smtp_session
    endpoint.send_message(
      "From: sender@example.com\r\nTo: #{route.name}@#{domain.name}\r\nSubject: endpoint\r\n\r\nhi\r\n",
      "sender@example.com", "#{route.name}@#{domain.name}"
    )
    endpoint.finish_smtp_session

    queued = QueuedMessage.last
    expect(queued).not_to be_nil
    expect(server_record.message(queued.message_id).rcpt_to).to eq "#{route.name}@#{domain.name}"
  end

  it "accepts pipelined commands in one segment" do
    sock = TCPSocket.new("127.0.0.1", listen_port)
    sock.gets
    sock.write("EHLO test\r\nMAIL FROM: <a@example.com>\r\n")
    ehlo_lines = []
    while (line = sock.gets)
      ehlo_lines << line
      break if line.start_with?("250 ")
    end
    mail_reply = sock.gets
    sock.write("QUIT\r\n")
    sock.gets
    sock.close

    expect(ehlo_lines.last).to start_with("250 ")
    expect(mail_reply).to start_with("250 ")
  end

  it "rejects an over-long command line" do
    sock = TCPSocket.new("127.0.0.1", listen_port)
    sock.gets
    sock.write("EHLO test\r\n")
    sock.gets while (line = sock.gets) && !line.start_with?("250 ")
    sock.write("X" * 600 + "\r\n")
    reply = sock.gets
    sock.close

    expect(reply).to start_with("500 ")
  end

  it "ends DATA only on a bare dot line" do
    sock = TCPSocket.new("127.0.0.1", listen_port)
    sock.gets
    sock.write("EHLO test\r\n")
    sock.gets while (line = sock.gets) && !line.start_with?("250 ")
    sock.write("MAIL FROM: <a@example.com>\r\n")
    sock.gets
    sock.write("RCPT TO: <#{route.name}@#{domain.name}>\r\n")
    sock.gets
    sock.write("DATA\r\n")
    expect(sock.gets).to start_with("354")
    sock.write("Subject: dots\r\n\r\n..not the end\r\n.\r\n")
    reply = sock.gets
    sock.write("QUIT\r\n")
    sock.gets
    sock.close

    expect(reply).to start_with("250 ")
    queued = QueuedMessage.last
    expect(server_record.message(queued.message_id).raw_message).to include(".not the end")
  end
end
