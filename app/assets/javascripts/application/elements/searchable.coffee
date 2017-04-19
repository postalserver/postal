ENTER = 13
DOWN_ARROW = 40
UP_ARROW = 38

filterList = ($container, query) ->
  $items = getItems($container)
  index = $container.data('searchifyIndex')
  re = new RegExp(query, 'g')
  $matches = $items.filter (i, item) ->
    value = $(item).data('value')
    re.test(value)
  $items.addClass('is-hidden').filter($matches).removeClass('is-hidden')
  toggleState($container, $matches.length > 0)
  if index?
    index = 0
    $container.data('searchifyIndex', index)
  highlightItem($container, $matches, index)

getContainer = ($el) ->
  $el.closest('.js-searchable')

getEmpty = ($container) ->
  $('.js-searchable__empty', $container)

getList = ($container) ->
  $('.js-searchable__list', $container)

getItems = ($container) ->
  $('.js-searchable__item', $container)

highlightItem = ($container, $scope, index) ->
  $items = getItems($container)
  $items.removeClass('is-highlighted')
  $scope.eq(index).addClass('is-highlighted') if index? && $scope.length

highlightNext = ($container) ->
  $matches = getMatches($container)
  index = $container.data('searchifyIndex')
  return unless $matches.length
  if index?
    return if index == $matches.length - 1
    newIndex = index + 1
  else
    newIndex = 0
  $container.data('searchifyIndex', newIndex)
  highlightItem($container, $matches, newIndex)

highlightPrev = ($container) ->
  $matches = getMatches($container)
  index = $container.data('searchifyIndex')
  return unless $matches.length
  if index?
    return if index == 0
    newIndex = index - 1
  else
    newIndex = 0
  $container.data('searchifyIndex', newIndex)
  highlightItem($container, $matches, newIndex)

getMatches = ($container) ->
  $items = getItems($container)
  $items.filter(':not(.is-hidden)')

searchify = (str) ->
  str.toLowerCase().replace(/\W/g, '')

selectHighlighted = ($container) ->
  index = $container.data('searchifyIndex')
  $matches = getMatches($container)
  return unless index? && $matches.length
  url = $matches.eq(index).data('url')
  Turbolinks.visit(url)

showAll = ($container) ->
  $items = getItems($container)
  index = $container.data('searchifyIndex')
  $items.removeClass('is-hidden')
  toggleState($container, true)
  if index?
    index = 0
    $container.data('searchifyIndex', index)
    highlightItem($container, $items, index)

toggleState = ($container, predicate) ->
  $empty = getEmpty($container)
  $list = getList($container)
  $empty.toggleClass('is-hidden', predicate)
  $list.toggleClass('is-hidden', !predicate)

# Event Handlers

handleInput = (event) ->
  $input = $(event.target)
  $container = getContainer($input)
  query = searchify($input.val())
  if query.length then filterList($container, query) else showAll($container)

handleKeydown = (event) ->
  $container = getContainer($(event.target))
  keyCode = event.keyCode
  if keyCode == DOWN_ARROW
    event.preventDefault()
    highlightNext($container)
  else if keyCode == ENTER
    event.preventDefault()
    selectHighlighted($container)
  else if keyCode == UP_ARROW
    event.preventDefault()
    highlightPrev($container)
$ ->
  $(document)
    .on('input', '.js-searchable__input', handleInput)
    .on('keydown', '.js-searchable__input', handleKeydown)
