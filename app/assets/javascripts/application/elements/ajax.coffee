onStart = (event) ->
  $('.flashMessage').remove()
  $('input, select, textarea').blur()
  $target = $(event.target)
  if $target.is('form')
    $('.js-form-submit', $target).addClass('is-spinning')
  if $target.hasClass('button')
    $($target).addClass('is-spinning')

onComplete = (event, xhr)->
  $target = $(event.target)
  if xhr.responseJSON
    data = xhr.responseJSON
    if data.redirect_to
      Turbolinks.clearCache()
      Turbolinks.visit(data.redirect_to, {"action":"replace"})
      console.log "Redirected to #{data.redirect_to}"

    if data.alert
      unSpin($target)
      alert(data.alert)

    if data.form_errors
      if $target.is('form')
        unSpin($target)
        handleErrors($target, data.form_errors)

    if data.flash
      unSpin($target)
      $('body .flashMessage').remove()
      for key, value of data.flash
        $message = $("<div class='flashMessage flashMessage--#{key}'>#{value}</div>")
        $('body').prepend($message)

    if data.region_html
      unSpin($target)
      $('.js-ajax-region').replaceWith(data.region_html)
      $('[autofocus]', '.js-ajax-region').focus()

  else
    console.log "Unsupported return."

unSpin = ($target)->
  $target.removeClass('is-spinning')
  $('.js-form-submit', $target).removeClass('is-spinning')


handleErrors = (form, errors)->
  html = $("<div class='formErrors errorExplanation'><ul></ul</div>")
  list = $('ul', html)
  $.each errors, ->
    list.append("<li>#{this}</li>")
  $('.formErrors', form).remove()
  form.prepend($(html))
  console.log errors

$ ->
  $.ajaxSettings.dataType = 'json'
  $(document)
    .on 'ajax:before', onStart
    .on 'ajax:complete', onComplete
