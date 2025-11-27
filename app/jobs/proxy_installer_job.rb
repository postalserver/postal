# frozen_string_literal: true

class ProxyInstallerJob < ApplicationJob
  queue_as :default

  def perform(ip_address_id)
    ip_address = IPAddress.find(ip_address_id)

    Rails.logger.info "[ProxyInstallerJob] Starting installation for IP Address ##{ip_address_id}"

    result = ProxyManager::ProxyInstaller.install(ip_address)

    if result[:success]
      Rails.logger.info "[ProxyInstallerJob] Installation successful for IP Address ##{ip_address_id}"

      # Automatically test the proxy after installation
      test_result = ProxyManager::ProxyTester.test(ip_address)

      if test_result[:success]
        Rails.logger.info "[ProxyInstallerJob] Proxy test successful for IP Address ##{ip_address_id}"
        ip_address.update(proxy_status: "active")
      else
        Rails.logger.warn "[ProxyInstallerJob] Proxy test failed for IP Address ##{ip_address_id}: #{test_result[:message]}"
        ip_address.update(proxy_status: "installed")
      end
    else
      Rails.logger.error "[ProxyInstallerJob] Installation failed for IP Address ##{ip_address_id}: #{result[:message]}"
    end
  rescue StandardError => e
    Rails.logger.error "[ProxyInstallerJob] Error installing proxy for IP Address ##{ip_address_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    if ip_address
      ip_address.update(
        proxy_status: "failed",
        proxy_last_test_result: "Job error: #{e.message}"
      )
    end

    raise e if Rails.env.development?
  end
end
