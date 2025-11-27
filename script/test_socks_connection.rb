#!/usr/bin/env ruby
# frozen_string_literal: true

# Тестовый скрипт для проверки SOCKS5 соединения
# Использование: ruby script/test_socks_connection.rb

require "socket"
require "socksify"
require "net/smtp"

puts "=" * 60
puts "Postal SOCKS5 Connection Test"
puts "=" * 60

# Конфигурация SOCKS proxy
SOCKS_HOST = ENV["SOCKS_HOST"] || "127.0.0.1"
SOCKS_PORT = ENV["SOCKS_PORT"] || 1080
TEST_SMTP_HOST = ENV["TEST_SMTP_HOST"] || "smtp.gmail.com"
TEST_SMTP_PORT = ENV["TEST_SMTP_PORT"] || 25

puts "\nConfiguration:"
puts "  SOCKS Proxy: #{SOCKS_HOST}:#{SOCKS_PORT}"
puts "  Test SMTP Server: #{TEST_SMTP_HOST}:#{TEST_SMTP_PORT}"
puts

# Test 1: Проверка доступности SOCKS proxy
puts "Test 1: Checking SOCKS proxy availability..."
begin
  socket = TCPSocket.new(SOCKS_HOST, SOCKS_PORT)
  socket.close
  puts "  ✓ SOCKS proxy is accessible"
rescue StandardError => e
  puts "  ✗ SOCKS proxy is NOT accessible: #{e.message}"
  exit 1
end

# Test 2: Проверка IP через SOCKS (без proxy)
puts "\nTest 2: Checking your current IP (without proxy)..."
begin
  require "net/http"
  uri = URI("https://ifconfig.me")
  response = Net::HTTP.get(uri)
  puts "  Your IP without proxy: #{response.strip}"
rescue StandardError => e
  puts "  ✗ Failed to check IP: #{e.message}"
end

# Test 3: Проверка IP через SOCKS (с proxy)
puts "\nTest 3: Checking IP through SOCKS proxy..."
begin
  require "socksify/http"

  TCPSocket.socks_server = SOCKS_HOST
  TCPSocket.socks_port = SOCKS_PORT

  uri = URI("http://ifconfig.me")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)

  puts "  Your IP through proxy: #{response.body.strip}"
  puts "  ✓ SOCKS proxy is working!"
rescue StandardError => e
  puts "  ✗ SOCKS proxy connection failed: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
end

# Test 4: Проверка SMTP соединения через SOCKS
puts "\nTest 4: Testing SMTP connection through SOCKS..."
begin
  TCPSocket.socks_server = SOCKS_HOST
  TCPSocket.socks_port = SOCKS_PORT

  smtp = Net::SMTP.new(TEST_SMTP_HOST, TEST_SMTP_PORT)
  smtp.open_timeout = 10
  smtp.read_timeout = 10
  smtp.enable_starttls_auto

  smtp.start("test.example.com") do |s|
    puts "  ✓ Successfully connected to #{TEST_SMTP_HOST}:#{TEST_SMTP_PORT} through SOCKS"
    puts "  ✓ SMTP capabilities: #{s.capable_starttls? ? 'STARTTLS' : 'none'}"
  end
rescue StandardError => e
  puts "  ✗ SMTP connection failed: #{e.message}"
  puts "  This might be expected if the SMTP server blocks connections"
end

# Test 5: Проверка DNS разрешения
puts "\nTest 5: Testing DNS resolution..."
begin
  require "resolv"

  ip_addresses = Resolv.getaddresses(TEST_SMTP_HOST)
  puts "  #{TEST_SMTP_HOST} resolves to:"
  ip_addresses.each { |ip| puts "    - #{ip}" }
  puts "  ✓ DNS resolution working"
rescue StandardError => e
  puts "  ✗ DNS resolution failed: #{e.message}"
end

puts "\n" + "=" * 60
puts "Test Summary:"
puts "  - SOCKS proxy connectivity: OK"
puts "  - Use these settings in postal.yml:"
puts "    smtp_client:"
puts "      socks_proxy_host: \"#{SOCKS_HOST}\""
puts "      socks_proxy_port: #{SOCKS_PORT}"
puts "=" * 60
puts "\nNext steps:"
puts "  1. Update your postal.yml configuration"
puts "  2. Restart Postal services"
puts "  3. Send a test email"
puts "  4. Check email headers to verify source IP"
puts
