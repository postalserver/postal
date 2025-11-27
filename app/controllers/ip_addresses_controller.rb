# frozen_string_literal: true

class IPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }
  before_action { params[:id] && @ip_address = @ip_pool.ip_addresses.find(params[:id]) }

  def new
    @ip_address = @ip_pool.ip_addresses.build
  end

  def create
    @ip_address = @ip_pool.ip_addresses.build(safe_params)
    if @ip_address.save
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "new", @ip_address
    end
  end

  def update
    if @ip_address.update(safe_params)
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "edit", @ip_address
    end
  end

  def destroy
    @ip_address.destroy
    redirect_to_with_json [:edit, @ip_pool]
  end

  private

  def safe_params
    params.require(:ip_address).permit(
      :ipv4, :ipv6, :hostname, :priority,
      :use_proxy, :proxy_type, :proxy_host, :proxy_port,
      :proxy_username, :proxy_password,
      :proxy_auto_install, :proxy_ssh_host, :proxy_ssh_port,
      :proxy_ssh_username, :proxy_ssh_password
    )
  end

  # Test proxy connection
  def test_proxy
    result = ProxyTester.test(@ip_address)
    render json: result
  end

  # Install proxy on remote server
  def install_proxy
    if @ip_address.proxy_needs_installation?
      @ip_address.update(proxy_status: "installing")
      ProxyInstallerJob.perform_later(@ip_address.id)
      render json: { success: true, message: "Proxy installation started. Check status in a moment." }
    else
      render json: { success: false, message: "Proxy installation requirements not met." }
    end
  end

end
