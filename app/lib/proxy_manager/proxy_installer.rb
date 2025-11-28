# frozen_string_literal: true

module ProxyManager
  class ProxyInstaller

    def self.install(ip_address)
      new(ip_address).install
    end

    def initialize(ip_address)
      @ip_address = ip_address
      @log = []
    end

    def install
      @ip_address.update_columns(proxy_status: "installing", updated_at: Time.current)

      log "Starting Dante SOCKS server installation..."
      log "Target server: #{@ip_address.proxy_ssh_host}:#{@ip_address.proxy_ssh_port}"

      begin
        require "net/ssh"
        require "timeout"

        Net::SSH.start(
          @ip_address.proxy_ssh_host,
          @ip_address.proxy_ssh_username,
          password: @ip_address.proxy_ssh_password,
          port: @ip_address.proxy_ssh_port,
          timeout: 30,
          verify_host_key: :never  # В продакшене лучше использовать proper verification
        ) do |ssh|
          # Step 1: Check OS
          log "Checking operating system..."
          os_info = ssh.exec!("cat /etc/os-release | grep -E '(^ID=|^VERSION_ID=)'")
          log "OS Info: #{os_info}"

          # Step 2: Update package list
          log "Updating package list..."
          update_result = exec_with_timeout(ssh, "apt-get update -qq || yum update -y -q", 180)
          log "Update result: #{update_result&.strip&.lines&.last(3)&.join}"

          # Step 3: Install Dante
          log "Installing Dante SOCKS server (this may take 2-3 minutes)..."
          # Use --force-confnew to automatically overwrite config files without prompting
          install_cmd = 'DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confnew" dante-server || yum install -y dante-server'
          result = exec_with_timeout(ssh, install_cmd, 300)
          log "Installation result: #{result&.strip&.lines&.last(5)&.join}"

          # Step 4: Configure Dante
          log "Configuring Dante..."
          dante_config = generate_dante_config
          ssh.exec!("cat > /etc/danted.conf << 'DANTE_EOF'\n#{dante_config}\nDANTE_EOF")

          # Step 5: Enable and start Dante
          log "Starting Dante service..."
          ssh.exec!("systemctl enable danted || chkconfig danted on")
          ssh.exec!("systemctl restart danted || service danted restart")

          # Step 6: Check if Dante is running
          log "Checking Dante status..."
          status = ssh.exec!("systemctl status danted || service danted status")
          log "Service status: #{status}"

          # Step 7: Configure firewall if present
          log "Configuring firewall..."
          postal_ip = get_postal_server_ip
          ssh.exec!("ufw allow from #{postal_ip} to any port 1080 2>/dev/null || true")
          ssh.exec!("firewall-cmd --permanent --add-rich-rule='rule family=\"ipv4\" source address=\"#{postal_ip}\" port port=\"1080\" protocol=\"tcp\" accept' 2>/dev/null || true")
          ssh.exec!("firewall-cmd --reload 2>/dev/null || true")

          log "Installation completed successfully!"

          # Update IP address record with proxy settings and auto-fill IPv4
          # Use update_columns to bypass callbacks and prevent re-triggering installation
          @ip_address.update_columns(
            proxy_status: "installed",
            proxy_host: @ip_address.proxy_ssh_host,
            proxy_port: 1080,
            ipv4: @ip_address.proxy_ssh_host,  # Auto-fill IPv4 with proxy server IP
            proxy_last_test_result: @log.join("\n"),
            updated_at: Time.current
          )

          {
            success: true,
            message: "Dante SOCKS server installed successfully!",
            log: @log.join("\n")
          }
        end
      rescue Net::SSH::AuthenticationFailed
        error_msg = "SSH authentication failed. Check username and password."
        log "ERROR: #{error_msg}"
        @ip_address.update_columns(
          proxy_status: "failed",
          proxy_last_test_result: @log.join("\n"),
          updated_at: Time.current
        )
        { success: false, message: error_msg, log: @log.join("\n") }
      rescue Net::SSH::ConnectionTimeout, Errno::ETIMEDOUT
        error_msg = "SSH connection timeout. Check IP address and firewall."
        log "ERROR: #{error_msg}"
        @ip_address.update_columns(
          proxy_status: "failed",
          proxy_last_test_result: @log.join("\n"),
          updated_at: Time.current
        )
        { success: false, message: error_msg, log: @log.join("\n") }
      rescue Timeout::Error => e
        error_msg = "Installation timeout: #{e.message}. The package installation took too long (>5 minutes). This may be due to slow internet or repository issues on the proxy server."
        log "ERROR: #{error_msg}"
        @ip_address.update_columns(
          proxy_status: "failed",
          proxy_last_test_result: @log.join("\n"),
          updated_at: Time.current
        )
        { success: false, message: error_msg, log: @log.join("\n") }
      rescue StandardError => e
        error_msg = "Installation failed: #{e.class} - #{e.message}"
        log "ERROR: #{error_msg}"
        log "Backtrace: #{e.backtrace.first(5).join("\n")}"
        @ip_address.update_columns(
          proxy_status: "failed",
          proxy_last_test_result: @log.join("\n"),
          updated_at: Time.current
        )
        { success: false, message: error_msg, log: @log.join("\n") }
      end
    end

    private

    def log(message)
      @log << "[#{Time.now.strftime('%H:%M:%S')}] #{message}"
      Rails.logger.info "[ProxyInstaller] #{message}"
    end

    def exec_with_timeout(ssh, command, timeout_seconds)
      output = ""
      error_output = ""
      exit_code = nil
      timed_out = false
      channel = nil

      # Create a thread to execute the command
      thread = Thread.new do
        channel = ssh.open_channel do |ch|
          ch.exec(command) do |ch, success|
            raise "Command execution failed" unless success

            ch.on_data do |_, data|
              output += data
            end

            ch.on_extended_data do |_, type, data|
              error_output += data if type == 1
            end

            ch.on_request("exit-status") do |_, data|
              exit_code = data.read_long
            end
          end
        end

        channel.wait
      end

      # Wait for the thread with timeout
      unless thread.join(timeout_seconds)
        timed_out = true

        # Try to close the channel gracefully
        begin
          channel&.close if channel
        rescue StandardError => e
          log "Warning: Could not close SSH channel: #{e.message}"
        end

        # Kill the thread
        thread.kill

        # Try to kill the remote process
        begin
          ssh.exec!("pkill -9 -f '#{command.gsub("'", "'\\''")}' 2>/dev/null || true")
        rescue StandardError => e
          log "Warning: Could not kill remote process: #{e.message}"
        end

        raise Timeout::Error, "Command timed out after #{timeout_seconds} seconds: #{command}"
      end

      # Return combined output
      result = output + error_output
      raise "Command failed with exit code #{exit_code}: #{result}" if exit_code && exit_code != 0

      result
    rescue Timeout::Error => e
      log "ERROR: #{e.message}"
      raise
    end

    def generate_dante_config
      postal_ip = get_postal_server_ip

      <<~DANTE_CONFIG
        # Dante SOCKS server configuration
        # Auto-generated by Postal IP Pool Manager

        logoutput: syslog

        # Internal interface (listen for connections)
        internal: 0.0.0.0 port = 1080

        # External interface (for outgoing connections)
        external: eth0

        # Authentication methods
        clientmethod: none
        socksmethod: none

        # Client access rules (only from Postal server)
        client pass {
            from: #{postal_ip}/32 to: 0.0.0.0/0
            log: connect disconnect error
        }

        # SOCKS rules
        socks pass {
            from: #{postal_ip}/32 to: 0.0.0.0/0
            protocol: tcp
            command: connect
            log: connect disconnect error
        }

        # Block everything else
        client block {
            from: 0.0.0.0/0 to: 0.0.0.0/0
            log: connect error
        }

        socks block {
            from: 0.0.0.0/0 to: 0.0.0.0/0
            log: connect error
        }
      DANTE_CONFIG
    end

    def get_postal_server_ip
      # Try to get the public IP of the Postal server
      require "net/http"
      require "timeout"

      begin
        Timeout.timeout(5) do
          uri = URI("http://ifconfig.me/ip")
          response = Net::HTTP.get_response(uri)
          return response.body.strip if response.code == "200"
        end
      rescue StandardError => e
        Rails.logger.warn "[ProxyInstaller] Could not determine Postal server IP: #{e.message}"
      end

      # Fallback: try to get from environment or config
      ENV["POSTAL_SERVER_IP"] || "0.0.0.0"
    end

  end
end
