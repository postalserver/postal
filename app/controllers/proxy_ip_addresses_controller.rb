# frozen_string_literal: true

class ProxyIPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }
  before_action { params[:id] && @ip_address = @ip_pool.ip_addresses.find(params[:id]) }

  def new_proxy
    @ip_address = @ip_pool.ip_addresses.build(use_proxy: true, proxy_auto_install: false)
  end

  def new_install
    @ip_address = @ip_pool.ip_addresses.build(use_proxy: true, proxy_auto_install: true)
  end

  def create_proxy
    @ip_address = @ip_pool.ip_addresses.build(safe_params.merge(use_proxy: true, proxy_auto_install: false, proxy_status: 'not_configured'))
    if @ip_address.save
      redirect_to_with_json [:edit, @ip_pool], notice: "Proxy IP has been added successfully."
    else
      render_form_errors "new_proxy", @ip_address
    end
  end

  def install_proxy
    # Check if there's already an installation in progress for this IP pool
    existing_installation = @ip_pool.ip_addresses.find_by(
      proxy_ssh_host: safe_params[:proxy_ssh_host],
      proxy_status: "installing"
    )

    if existing_installation
      render json: {
        success: false,
        errors: ["Installation already in progress for this server. Please wait..."]
      }, status: :unprocessable_entity
      return
    end

    # Check if this server is already installed
    already_installed = @ip_pool.ip_addresses.find_by(
      proxy_ssh_host: safe_params[:proxy_ssh_host],
      proxy_status: ["installed", "active"]
    )

    if already_installed
      render json: {
        success: false,
        errors: ["Proxy already installed on this server. Use the existing IP address."]
      }, status: :unprocessable_entity
      return
    end

    @ip_address = @ip_pool.ip_addresses.build(safe_params.merge(use_proxy: true, proxy_auto_install: true))
    if @ip_address.save
      # Start the installation process
      # Use update_columns to bypass callbacks and prevent re-triggering
      @ip_address.update_columns(proxy_status: "installing", updated_at: Time.current)
      ProxyInstallerService.install_async(@ip_address.id) if defined?(ProxyInstallerService)

      render json: { success: true, ip_address_id: @ip_address.id }
    else
      render json: { success: false, errors: @ip_address.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def installation_status
    # This is a mock implementation - you'll need to implement actual status checking
    # based on how your ProxyInstallerService works
    ip_address = @ip_pool.ip_addresses.where(proxy_status: "installing").last

    if ip_address.nil?
      # No installation in progress
      render json: { complete: false, error: true, message: "No installation in progress" }
    elsif ip_address.proxy_status == "active"
      render json: { complete: true, message: "Installation completed successfully" }
    elsif ip_address.proxy_status == "failed"
      render json: { complete: false, error: true, message: ip_address.proxy_last_test_result || "Installation failed" }
    else
      render json: { complete: false, message: "Installation in progress..." }
    end
  end

  private

  def safe_params
    params.require(:ip_address).permit(
      :hostname, :priority,
      :proxy_ssh_host, :proxy_ssh_port,
      :proxy_ssh_username, :proxy_ssh_password,
      :proxy_host, :proxy_port, :proxy_type,
      :proxy_username, :proxy_password
    )
  end

end
