require "net/ssh"

module LegacyAPI
  class NetplanController < BaseController
    HOST = "172.17.0.1"
    USER = "netplanuser"

    # Add an IP address to the netplan configuration
    def add_ip
      ip_address = api_params["ip_address"]
      logger.info "NetplanController: Received request to add IP address: #{ip_address}"

      begin
        output = ssh_exec!("add_ip #{ip_address}")
        if output.include?("success")
          logger.info "NetplanController: IP address #{ip_address} added successfully and netplan applied"
          render_success(message: "IP address #{ip_address} added and netplan applied")
        else
          logger.error "NetplanController: Failed to add IP address: #{output}"
          render_error("IPAddressNotAdded", message: "Failed to add IP address", status: :unprocessable_entity)
        end
      rescue => e
        logger.error "NetplanController: Exception occurred while adding IP address: #{e.message}"
        render_error("IPAddressNotAdded", message: "Failed to add IP address", status: :unprocessable_entity)
      end
    end

    # Query the list of IP addresses in the netplan configuration
    def query_ips
      logger.info "NetplanController: Received request to query IP addresses"
      begin
        output = ssh_exec!("query_ips")
        ip_list = output.strip.split("\n")
        if ip_list.any?
          logger.info "NetplanController: Found the following IP addresses: #{ip_list.join(", ")}"
          render_success(ips: ip_list)
        else
          logger.warn "NetplanController: No IP addresses found in the netplan configuration"
          render_error("NoIPsFound", message: "No IP addresses found", status: :not_found)
        end
      rescue => e
        logger.error "NetplanController: Failed to query IP addresses: #{e.message}"
        render_error("QueryFailed", message: "Failed to query IP addresses", status: :internal_server_error)
      end
    end

    # Apply the netplan configuration manually
    def apply
      logger.info "NetplanController: Received request to apply netplan configuration"
      begin
        output = ssh_exec!("apply")
        if output.include?("success")
          logger.info "NetplanController: Netplan configuration applied successfully"
          render_success(message: "Netplan configuration applied successfully")
        else
          logger.error "NetplanController: Failed to apply netplan configuration: #{output}"
          render_error("NetplanApplyFailed", message: "Failed to apply netplan", status: :unprocessable_entity)
        end
      rescue => e
        logger.error "NetplanController: Exception occurred while applying netplan configuration: #{e.message}"
        render_error("NetplanApplyFailed", message: "Failed to apply netplan", status: :unprocessable_entity)
      end
    end

    private

    # Helper method to execute SSH commands and handle output
    def ssh_exec!(args)
      private_key = OpenSSL::PKey::RSA.new(Postal::Config.netmap_ssh.private)
      logger.info "NetplanController: Attempting to connect to #{HOST} as #{USER} with args: #{args}"

      Net::SSH.start(HOST, USER, key_data: [private_key.to_pem], keys_only: true, auth_methods: ["publickey"]) do |ssh|
        # Log before executing the command
        logger.info "NetplanController: Executing command: netplan_manager.sh #{args}"

        output = ssh.exec!("netplan_manager.sh #{args}")

        # Log the raw output
        logger.info "NetplanController: Command output: #{output}"

        if output.include?("Usage") || output.include?("Failed")
          raise "Command failed: #{output}"
        end

        output
      end
    rescue StandardError => e
      logger.error "NetplanController: SSH command execution failed: #{e.message}"
      raise
    end

    # Strong parameters for API requests
    def api_params
      params.permit(:ip_address)
    end
  end
end
