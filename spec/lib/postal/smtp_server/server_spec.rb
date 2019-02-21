require 'rails_helper'

describe Postal::SMTPServer::Server do
  let(:credential) do
    s = Server.first
    c = create(:credential, server: s)
    create :domain, owner: c.server, name: 'example.com'
    c.to_smtp_plain
  end

  let(:sender) { TCPSocket.open 'localhost', 2525 }

  before :all do
    Thread.new do
      Postal::SMTPServer::Server.new(debug: true).run
    end
  end

  it 'should receive message' do
    client = sender
    send_mail client, credential
    answers = []
    8.times do
      line = client.gets
      answers << line.chomp
    end
    expect_answers answers
  end

  it 'should receive mutiple messages' do
    begin_time = Time.now
    puts "Start time: #{begin_time}"
    cred = credential
    queue = Queue.new
    connections = 20
    connections.times.each do |n|
      Thread.new do
        client = TCPSocket.open 'localhost', 2525
        send_mail client, cred, n
        answers = []
        8.times { answers << client.gets.chomp }
        queue.push answers
      end
    end

    timeout = connections / 10 + 10
    while queue.size < connections
      sleep 0.1
      next if (Time.now - begin_time) < timeout

      raise 'Conection timeout!'
    end
    connections.times { expect_answers queue.pop }
    end_time = Time.now
    puts "Stop time: #{end_time}"
    puts("#{connections} connections in: #{(end_time - begin_time).floor}sec")
  end

  def send_mail(client, cred, msg_id = 1)
    client.puts 'HELO'
    client.puts "AUTH PLAIN #{cred}"
    client.puts "MAIL FROM:<test_from_#{msg_id}@example.com>"
    client.puts 'RCPT TO:<test_to@example.com>'
    client.puts 'DATA'
    client.puts 'From: Test Sender <test_from@example.com'
    client.puts 'To: "Test Receiver" <test_to@example.com'
    client.puts "Date: #{Time.now}"
    client.puts 'Subject: Test messages'
    client.puts 'Hello Receiver.'
    client.puts 'Hello Receiver.'
    client.puts 'This is a test message.'
    client.puts 'Bye.'
    client.puts '.'
    client.puts 'QUIT'
  end

  def expect_answers(answers)
    expect(answers[0]).to include '220 postal.example.com ESMTP Postal'
    expect(answers[1]).to eq '250 postal.example.com'
    expect(answers[2]).to include '235 Granted for org'
    expect(answers[3]).to eq '250 OK'
    expect(answers[4]).to eq '250 OK'
    expect(answers[5]).to eq '354 Go ahead'
    expect(answers[6]).to eq '250 OK'
    expect(answers[7]).to eq '221 Closing Connection'
  end
end
