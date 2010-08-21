$ ->
  $('a.resend').click ->
    a = $ this
    a.hide().after '<span>Resending&hellip;</span>'
    $.get @href, ->
      a.next('span').html('Sent!').fadeOut 'slow', ->
        a.next('span').remove()
        a.fadeIn()
    false

  $('a.delete').click ->
    confirm 'Are you sure?'

  $('a.reveal').click ->
    $(this).hide().next('.hidden').slideDown ->
      $(this).find('input').select()
    false

  $(':input:visible:first').focus()

  $('input.url').click ->
    this.select() if @value is @defaultValue

  $('form.reset_password').submit ->
    form = $ this
    email = form.find('input.email').val()
    $.ajax(
      type: form.attr('method')
      url: form.attr('action')
      data: form.serialize()
      success: (data) ->
        form.replaceWith """
          <h2>#email has been sent a new password</h2>
          <p>It should arrive shortly.</p>"""
      error: (xhr) ->
        $('#errors').append "<li>#xhr.responseText</li>")
    false

  $('form').submit (evt) ->
    form = $(this).closest('form')
    errors = $('#errors').html('')
    form.find('input').removeClass 'error'

    hasError = false
    highlightError = (selector, message, fn) ->
      invalid = form.find(selector).filter fn
      if invalid.length
        errors.append "<li>#{message}</li>"
        invalid.addClass 'error'
        invalid.blur()
        hasError = true

    highlightError 'input.email', 'Invalid email address', ->
      val = $(this).val()
      val and not /^[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test val

    highlightError 'input[name=name]', 'Name is required', -> !$(this).val()
    highlightError 'input#github', 'GitHub username is required', -> !$(this).val()
    highlightError 'input.email:first', 'Email is required', -> !$(this).val()
    highlightError 'input[type=password]:visible', 'Password required', -> !$(this).val()
    highlightError 'input.url', 'Invalid link', ->
      val = $(this).val()
      val and val isnt @defaultValue and not /^https?:\/\/.*\./.test val

    unless hasError
      $('input.url').each ->
        @value = '' if @value is @defaultValue
    not hasError

  if $('time').length > 0
    [y, m, d, h, i, s] = $('time').attr('datetime').split(/[-:TZ]/)...
    ms = Date.UTC y, m-1, d, h, i, s
    countdown = $('#date .about')
    tick = ->
      diff = (ms - new Date().getTime()) / 1000
      weeks = Math.floor diff / 604800
      days = Math.floor diff % 604800 / 86400
      hours = Math.floor diff % 86400 / 3600
      minutes = Math.floor diff % 3600 / 60
      secs = Math.floor diff % 60
      countdown.html weeks + ' week ' + days + ' days ' + hours + ' hours ' + minutes + ' minutes ' + secs + ' seconds'
      setTimeout tick, 1000
    tick()

  $('time').hover ->
    $this = $(this)
    [y, m, d, h, i, s] = $this.attr('datetime').split(/[-:TZ]/)...
    ms = Date.UTC y, m-1, d, h, i, s
    dt = new Date(ms)
    $('<div class="localtime blue">')
      .html("
        #{dt.strftime('%a %b %d, %I%P %Z').replace(/\b0/,'')}
        ")
      .appendTo($this)
  , ->
    $(this).find('.localtime').remove()

  $('.judge img').each ->
    r = 'rotate(' + new String(Math.random()*6-3) + 'deg)'
    $(this)
      .css('-webkit-transform', r)
      .css('-moz-transform', r)

  Stars = {
    value: (elem) ->
      elem.attr('data-value')
    input: (elem) ->
      elem.closest('.stars').prev('input[type=hidden]')
    set: (elem) ->
      newVal = @value(elem)
      oldVal = @input(elem).val()
      @input(elem).val(if newVal is oldVal then 0 else newVal)
    highlight: (elem, hover) ->
      score = if hover then @value(elem) else @input(elem).val()
      elem.parent().children().each (i, star) ->
        $star = $(star)
        fill = $star.attr('data-value') <= score
        $star.find('.filled').toggle(fill)
        $star.find('.empty').toggle(!fill)
  }

  $('.star').hover (-> Stars.highlight $(this), true),
    (-> Stars.highlight $(this))
  $('.star').click -> Stars.set($(this))