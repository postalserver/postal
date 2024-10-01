# app/controllers/legacy_api/netplan_controller.rb

module LegacyAPI
  class NetplanController < BaseController
    # Add an IP address to the netplan configuration
    def add_ip
      ip_address = api_params["ip_address"]

      # Logging and console output
      logger.info("Received request to add IP address: #{ip_address}")
      puts "Received request to add IP address: #{ip_address}"

      if ip_exists?(ip_address)
        logger.warn("IP address #{ip_address} already exists in the netplan configuration")
        puts "IP address #{ip_address} already exists in the netplan configuration"
        render_error("IPAddressExists", message: "IP address already exists", status: :conflict)
      else
        if append_ip(ip_address)
          apply_netplan
          logger.info("IP address #{ip_address} added successfully and netplan applied")
          puts "IP address #{ip_address} added successfully and netplan applied"
          render_success(message: "IP address #{ip_address} added and netplan applied")
        else
          logger.error("Failed to add IP address #{ip_address}")
          puts "Failed to add IP address #{ip_address}"
          render_error("IPAddressNotAdded", message: "Failed to add IP address", status: :unprocessable_entity)
        end
      end
    end

    # Query the list of IP addresses in the netplan configuration
    def query_ips
      logger.info("Received request to query IP addresses")
      puts "Received request to query IP addresses"
      ip_list = extract_ips

      if ip_list.any?
        logger.info("Found the following IP addresses: #{ip_list.join(", ")}")
        puts "Found the following IP addresses: #{ip_list.join(", ")}"
        render_success(ips: ip_list)
      else
        logger.warn("No IP addresses found in the netplan configuration")
        puts "No IP addresses found in the netplan configuration"
        render_error("NoIPsFound", message: "No IP addresses found", status: :not_found)
      end
    end

    # Apply the netplan configuration manually
    def apply
      logger.info("Received request to apply netplan configuration")
      puts "Received request to apply netplan configuration"

      if apply_netplan
        logger.info("Netplan configuration applied successfully")
        puts "Netplan configuration applied successfully"
        render_success(message: "Netplan configuration applied successfully")
      else
        logger.error("Failed to apply netplan configuration")
        puts "Failed to apply netplan configuration"
        render_error("NetplanApplyFailed", message: "Failed to apply netplan", status: :unprocessable_entity)
      end
    end

    private

    # Check if an IP address already exists in the netplan configuration
    def ip_exists?(ip_address)
      netplan_file = "/etc/netplan/60-floating-ip.yaml"
      exists = File.read(netplan_file).include?(ip_address)

      logger.info("Checked if IP #{ip_address} exists: #{exists}")
      puts "Checked if IP #{ip_address} exists: #{exists}"

      exists
    end

    # Append the new IP address to the netplan file
    def append_ip(ip_address)
      netplan_file = "/etc/netplan/60-floating-ip.yaml"

      logger.info("Appending IP address #{ip_address} to netplan configuration")
      puts "Appending IP address #{ip_address} to netplan configuration"

      system("sudo sed -i '/addresses:/a\\       - #{ip_address}/32' #{netplan_file}")
    end

    # Apply the netplan configuration
    def apply_netplan
      logger.info("Applying netplan configuration")
      puts "Applying netplan configuration"

      system("sudo netplan apply")
    end

    # Extract the current IPs from the netplan configuration
    def extract_ips
      netplan_file = "/etc/netplan/60-floating-ip.yaml"

      logger.info("Extracting IP addresses from netplan configuration")
      puts "Extracting IP addresses from netplan configuration"

      File.read(netplan_file).scan(/\d+\.\d+\.\d+\.\d+/)
    end

    # Strong parameters for API requests
    def api_params
      params.permit(:ip_address)
    end
  end
end
