$ ->
  # IP Address form handlers
  # These need to be wrapped in turbolinks:load to work properly with Turbolinks

  $(document).on 'turbolinks:load', ->
    # Toggle between Local IP and Proxy settings based on radio button selection
    $('input[name="ip_type"]').off('change').on 'change', ->
      if $(this).val() == 'local'
        $('#proxy-ip-settings').slideUp()
        $('#local-ip-settings').slideDown()
        $('#use-proxy-hidden').val('0')
      else if $(this).val() == 'proxy'
        $('#local-ip-settings').slideUp()
        $('#proxy-ip-settings').slideDown()
        $('#use-proxy-hidden').val('1')

  # Use delegated event handlers for buttons (works with Turbolinks)
  # Test proxy connection
  $(document).on 'click', '#test-proxy-btn', (e) ->
    e.preventDefault()
    btn = $(this)
    ipAddressId = btn.data('ip-address-id')
    ipPoolId = btn.data('ip-pool-id')
    resultSpan = $('#proxy-test-result')

    btn.prop('disabled', true).text('Testing...')
    resultSpan.html('<span style="color: #666;">⏳ Testing connection...</span>')

    $.ajax
      url: '/ip_pools/' + ipPoolId + '/ip_addresses/' + ipAddressId + '/test_proxy'
      method: 'POST'
      success: (data) ->
        if data.success
          resultSpan.html('<span style="color: green;">✅ ' + data.message + '</span>')
        else
          resultSpan.html('<span style="color: red;">❌ ' + data.message + '</span>')
      error: ->
        resultSpan.html('<span style="color: red;">❌ Test failed</span>')
      complete: ->
        btn.prop('disabled', false).text('🧪 Test Proxy Connection')
        setTimeout (-> resultSpan.fadeOut()), 10000

  # Install proxy
  $(document).on 'click', '#install-proxy-btn', (e) ->
    e.preventDefault()
    btn = $(this)
    ipAddressId = btn.data('ip-address-id')
    ipPoolId = btn.data('ip-pool-id')
    resultSpan = $('#proxy-test-result')

    return unless confirm('This will install Dante SOCKS server on the remote server. Continue?')

    btn.prop('disabled', true).text('Installing...')
    resultSpan.html('<span style="color: #666;">📦 Installation started...</span>')

    $.ajax
      url: '/ip_pools/' + ipPoolId + '/ip_addresses/' + ipAddressId + '/install_proxy'
      method: 'POST'
      success: (data) ->
        if data.success
          resultSpan.html('<span style="color: green;">✅ ' + data.message + '</span>')
        else
          resultSpan.html('<span style="color: red;">❌ ' + data.message + '</span>')
      error: ->
        resultSpan.html('<span style="color: red;">❌ Installation failed</span>')
      complete: ->
        btn.prop('disabled', false).text('📦 Install Proxy Now')
