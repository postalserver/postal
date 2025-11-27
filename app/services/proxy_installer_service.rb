# frozen_string_literal: true

# Simple background proxy installer using Thread
# For production, this should be moved to Worker::Jobs
class ProxyInstallerService

  def self.install_async(ip_address_id)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ip_address = IPAddress.find(ip_address_id)
        install_sync(ip_address)
      end
    rescue StandardError => e
      Rails.logger.error "[ProxyInstallerService] Error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end
  end

  def self.install_sync(ip_address)
    Rails.logger.info "[ProxyInstallerService] Starting installation for IP Address ##{ip_address.id}"

    result = ProxyManager::ProxyInstaller.install(ip_address)

    if result[:success]
      Rails.logger.info "[ProxyInstallerService] Installation successful for IP Address ##{ip_address.id}"

      # Automatically test the proxy after installation
      test_result = ProxyManager::ProxyTester.test(ip_address)

      if test_result[:success]
        Rails.logger.info "[ProxyInstallerService] Proxy test successful for IP Address ##{ip_address.id}"
        ip_address.update(proxy_status: "active")
      else
        Rails.logger.warn "[ProxyInstallerService] Proxy test failed for IP Address ##{ip_address.id}: #{test_result[:message]}"
        ip_address.update(proxy_status: "installed")
      end
    else
      Rails.logger.error "[ProxyInstallerService] Installation failed for IP Address ##{ip_address.id}: #{result[:message]}"
    end
  rescue StandardError => e
    Rails.logger.error "[ProxyInstallerService] Error installing proxy for IP Address ##{ip_address.id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    if ip_address
      ip_address.update(
        proxy_status: "failed",
        proxy_last_test_result: "Installation error: #{e.message}"
      )
    end
  end

end
