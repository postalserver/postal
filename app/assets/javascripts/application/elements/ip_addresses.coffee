$ ->
  # IP Address form proxy settings handlers
  # These need to be wrapped in turbolinks:load to work properly with Turbolinks

  $(document).on 'turbolinks:load', ->
    # Toggle proxy settings visibility when checkbox changes
    $('#use-proxy-checkbox').off('change').on 'change', ->
      if $(this).is(':checked')
        $('#proxy-settings').slideDown()
      else
        $('#proxy-settings').slideUp()

    # Toggle auto-install vs manual settings
    $('#auto-install-checkbox').off('change').on 'change', ->
      if $(this).is(':checked')
        $('#manual-proxy-settings').slideUp()
        $('#auto-install-settings').slideDown()
      else
        $('#auto-install-settings').slideUp()
        $('#manual-proxy-settings').slideDown()

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
