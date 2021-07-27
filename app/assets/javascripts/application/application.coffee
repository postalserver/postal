#= require jquery
#= require jquery_ujs
#= require turbolinks
#= require_tree ./vendor/.
#= require_self
#= require_tree .

$ ->

  isFirefox = -> !!navigator.userAgent.match(/firefox/i)

  $('html').addClass('browser-firefox') if isFirefox()

  $(document).on 'turbolinks:load', ->
    $('.js-multibox').multibox({inputCount: 6, classNames: {container: "multibox", input: 'input input--text multibox__input'}})

  $(document).on 'keyup', (event)->
    return if $(event.target).is('input, select, textarea')
    if event.keyCode == 83
      $('.js-focus-on-s').focus()
      event.preventDefault()
    if event.keyCode == 70
      $('.js-focus-on-f').focus()
      event.preventDefault()

  $(document).on 'click', 'html.main .flashMessage', ->
    $(this).hide 'fast', ->
      $(this).remove()

  $(document).on 'click', '.js-toggle-helpbox', ->
    helpBox = $('.js-helpbox')
    if helpBox.hasClass('is-hidden')
      helpBox.removeClass('is-hidden')
    else
      helpBox.addClass('is-hidden')
    return false

  $(document).on 'input', 'input[type=range]', ->
    value = $(this).val()
    updateAttr = $(this).attr('data-update')
    if updateAttr && updateAttr.length
      $("." + $(this).attr('data-update')).text(parseFloat(value, 10).toFixed(1))

  $(document).on 'change', '.js-checkbox-list-toggle', ->
    $this = $(this)
    value = $this.val()
    $list = $this.parent().find('.checkboxList')
    if value == 'false' then $list.show() else $list.hide()

  $(document).on 'click', '.js-toggle', ->
    $link = $(this)
    element = $link.attr('data-element')
    $(element, $link.parent()).toggle()
    false

  toggleCredentialInputs = (type)->
    $('[data-credential-key-type]').hide()
    $('[data-credential-key-type] input').attr('disabled', true)
    if type == 'SMTP-IP'
      $('[data-credential-key-type=smtp-ip]').show()
      $('[data-credential-key-type=smtp-ip] input').attr('disabled', false)
    else
      $('[data-credential-key-type=all]').show()

  $(document).on 'change', 'select#credential_type', ->
    value = $(this).val()
    toggleCredentialInputs(value)

  $(document).on 'turbolinks:load', ->
    credentialTypeInput = $('select#credential_type')
    if credentialTypeInput.length
      toggleCredentialInputs(credentialTypeInput.val())
