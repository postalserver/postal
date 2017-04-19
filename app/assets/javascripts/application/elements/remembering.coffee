$ ->
  $(document).on 'click', '.js-remember a', ->
    $parent = $(this).parents('.js-remember')
    value = $(this).attr('data-remember')
    $parent.remove()
    if value == 'yes'
      $.post('/persist')
    false
