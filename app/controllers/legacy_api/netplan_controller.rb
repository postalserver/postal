# app/controllers/legacy_api/netplan_controller.rb

module LegacyAPI
  class NetplanController < BaseController
    # Add an IP address to the netplan configuration
    def add_ip
      ip_address = api_params["ip_address"]

      if ip_exists?(ip_address)
        render_error("IPAddressExists", message: "IP address already exists", status: :conflict)
      else
        if append_ip(ip_address)
          apply_netplan
          render_success(message: "IP address #{ip_address} added and netplan applied")
        else
          render_error("IPAddressNotAdded", message: "Failed to add IP address", status: :unprocessable_entity)
        end
      end
    end

    # Query the list of IP addresses in the netplan configuration
    def query_ips
      ip_list = extract_ips
      if ip_list.any?
        render_success(ips: ip_list)
      else
        render_error("NoIPsFound", message: "No IP addresses found", status: :not_found)
      end
    end

    # Apply the netplan configuration manually
    def apply
      if apply_netplan
        render_success(message: "Netplan configuration applied successfully")
      else
        render_error("NetplanApplyFailed", message: "Failed to apply netplan", status: :unprocessable_entity)
      end
    end

    private

    # Check if an IP address already exists in the netplan configuration
    def ip_exists?(ip_address)
      netplan_file = '/etc/netplan/60-floating-ip.yaml'
      File.read(netplan_file).include?(ip_address)
    end

    # Append the new IP address to the netplan file
    def append_ip(ip_address)
      netplan_file = '/etc/netplan/60-floating-ip.yaml'
      system("sudo sed -i '/addresses:/a\\       - #{ip_address}/32' #{netplan_file}")
    end

    # Apply the netplan configuration
    def apply_netplan
      system("sudo netplan apply")
    end

    # Extract the current IPs from the netplan configuration
    def extract_ips
      netplan_file = '/etc/netplan/60-floating-ip.yaml'
      File.read(netplan_file).scan(/\d+\.\d+\.\d+\.\d+/)
    end

    # Strong parameters for API requests
    def api_params
      params.permit(:ip_address)
    end
  end
end
