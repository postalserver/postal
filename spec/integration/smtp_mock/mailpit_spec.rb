# frozen_string_literal: true

require "rails_helper"
require "socket"

#
# Postal's outbound sender against a scripted non-Postal SMTP peer: a minimal
# in-process fake speaks just enough SMTP (greeting, EHLO with SIZE, MAIL,
# RCPT, DATA, QUIT, plus programmable refusals) for SMTPSender and
# SMTPClient::Endpoint to drive real sessions over a real socket. This is the
# interop side of the testing: the peer is deliberately not Postal, so the
# specs prove the sender works against foreign servers without needing an
# external mock such as Mailpit, and they run in the default suite with no
# network beyond loopback.
#
# Isolated namespace: nothing here is shared with the Postal-to-Postal specs.
#
RSpec.describe "Mock-peer SMTP", type: :integration do
  # A scripted SMTP peer. Each script entry maps a command regexp to either a
  # reply line or an array of reply lines; commands with no entry get a
  # generic 250. Received commands and DATA bodies are recorded for
  # assertions. DATA content lines are consumed until the bare-dot
  # terminator; dot-stuffed lines are unstuffed the way a real server would.
  class ScriptedPeer

    attr_reader :commands, :bodies

    def initialize(scripts = {})
      @scripts = scripts
      @commands = Queue.new
      @bodies = Queue.new
    end

    def serve(port)
      tcp = TCPServer.new("127.0.0.1", port)
      @tcp = tcp
      @sockets = Queue.new
      @thread = Thread.new do
        loop do
          io = tcp.accept
          @sockets << io
          Thread.new(io) do |sock|
            sock.puts "220 mock ESMTP FakePeer"
            while (line = sock.gets)
              line = line.delete_suffix("\n").delete_suffix("\r")
              @commands << line
              if line =~ /\ADATA/i
                sock.puts "354 Go ahead"
                read_data(sock)
                sock.puts "250 2.0.0 OK: queued"
              else
                reply = reply_for(line)
                Array(reply).each { |r| sock.puts r } unless reply.nil?
              end
              break if line =~ /\AQUIT/i
            end
            sock.close
          rescue StandardError
            sock.close rescue nil
          end
        end
      end
      self
    end

    def stop
      until @sockets.empty?
        begin
          @sockets.pop(true)&.close
        rescue StandardError
          nil
        end
      end
      @thread&.kill
      @thread&.join(2)
      @tcp&.close rescue nil
    end

    def received_commands
      commands = []
      commands << @commands.pop(true) until @commands.empty?
      commands
    end

    private

    def reply_for(line)
      @scripts.each do |pattern, reply|
        return reply unless line !~ pattern
      end

      "250 2.0.0 OK"
    end

    def read_data(sock)
      body = +String.new
      while (line = sock.gets)
        line = line.delete_suffix("\n").delete_suffix("\r")
        break if line == "."
        body << "#{line.sub(/\A\.\./, ".")}\r\n"
      end
      @bodies << body
    end

  end

  let(:listen_port) { 12526 }
  let(:peers) { [] }

  def serve_peer(script, port)
    ScriptedPeer.new(script).serve(port).tap { |peer| peers << peer }
  end

  let(:peer) { serve_peer(peer_script, listen_port) }
  let(:peer_script) { {} }

  after do
    peers.each(&:stop)
  end

  def endpoint_for(hostname = "127.0.0.1")
    server = SMTPClient::Server.new(hostname, port: listen_port, ssl_mode: SMTPClient::SSLModes::NONE)
    SMTPClient::Endpoint.new(server, "127.0.0.1")
  end

  it "delivers a message the peer accepts" do
    endpoint = endpoint_for
    endpoint.start_smtp_session
    endpoint.send_message(
      "From: a@example.com\r\nTo: b@example.com\r\nSubject: t\r\n\r\nhi\r\n",
      "a@example.com", "b@example.com"
    )
    endpoint.finish_smtp_session

    expect(peer.bodies.pop(true)).to include("hi")
    expect(peer.received_commands.grep(/\AMAIL FROM/i)).not_to be_empty
  end

  it "reads the peer's SIZE limit from its EHLO reply" do
    peer_with_size = serve_peer({ /\AEHLO/i => ["250-mock", "250-SIZE 123456", "250 PIPELINING"] }, 12527)
    server = SMTPClient::Server.new("127.0.0.1", port: 12527, ssl_mode: SMTPClient::SSLModes::NONE)
    endpoint = SMTPClient::Endpoint.new(server, "127.0.0.1")
    endpoint.start_smtp_session
    limit = endpoint.message_size_limit
    endpoint.finish_smtp_session

    expect(limit).to eq 123_456
  end

  it "refuses to transfer when the message exceeds the peer's limit" do
    serve_peer({ /\AEHLO/i => ["250-mock", "250-SIZE 10", "250 PIPELINING"] }, 12528)
    server = SMTPClient::Server.new("127.0.0.1", port: 12528, ssl_mode: SMTPClient::SSLModes::NONE)
    endpoint = SMTPClient::Endpoint.new(server, "127.0.0.1")
    endpoint.start_smtp_session
    expect {
      endpoint.send_message("From: a@example.com\r\nTo: b@example.com\r\n\r\n" + ("x" * 100) + "\r\n",
                            "a@example.com", "b@example.com")
    }.to raise_error(SMTPClient::Endpoint::MessageTooLargeError)
    endpoint.finish_smtp_session
  end

  context "when the peer refuses the recipient" do
    let(:peer_script) { { /\ARCPT TO/i => "550 5.1.1 User unknown" } }

    it "maps the refusal to a HardFail result" do
      server = SMTPClient::Server.new("127.0.0.1", port: listen_port, ssl_mode: SMTPClient::SSLModes::NONE)
      endpoint = SMTPClient::Endpoint.new(server, "127.0.0.1")
      allow(server).to receive(:endpoints).and_return([endpoint])
      sender = SMTPSender.new("example.com", nil, servers: [server])
      expect(sender.start).to be_truthy

      message = instance_double(Postal::MessageDB::Message,
                                bounce: true,
                                rcpt_to: "nobody@example.com",
                                raw_message: "Subject: t\r\n\r\nhi\r\n")
      result = sender.send_message(message)
      sender.finish

      expect(result.type).to eq "HardFail"
    end
  end

  context "when no peer is listening" do
    it "returns false from start with no host to try" do
      server = SMTPClient::Server.new("127.0.0.1", port: 19999, ssl_mode: SMTPClient::SSLModes::NONE)
      endpoint = SMTPClient::Endpoint.new(server, "127.0.0.1")
      allow(server).to receive(:endpoints).and_return([endpoint])
      sender = SMTPSender.new("example.com", nil, servers: [server])

      expect(sender.start).to be false
    end
  end
end
