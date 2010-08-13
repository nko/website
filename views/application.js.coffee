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

    highlightError 'input.email', 'Invalid email address',->
      val = $(this).val()
      val and not /^[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test val

    highlightError 'input[name=name]', 'Name is required', -> !$(this).val()
    highlightError 'input.email:first', 'Email is required', -> !$(this).val()
    highlightError 'input[type=password]:visible', 'Password required', -> !$(this).val()
    highlightError 'input.url', 'Invalid link', ->
      val: $(this).val()
      val and val isnt @defaultValue and not /^https?:\/\/.*\./.test val

    unless hasError
      $('input.url').each ->
        @value = '' if @value is @defaultValue
    not hasError

  $('#attending').click (evt) ->
    if $(this).is(':checked')
      $memberInputs = $('#members li input')
      size = if $memberInputs.length
        _.compact($memberInputs.map( -> @value).get()).length
      else
        $('#members li').length

      $('#attending_count').slideDown('fast').find('input[type=text]').val(size).select()
    else
      $('#attending_count').slideUp('fast').find('input[type=text]').val(0)

  if $('.body.teams-show').length > 0
    getAttendingCount = ->
      if $('#attending').is(':checked')
        parseInt($('#attending_count').find('input[type=text]').val()) or 0
      else 0
    attendingCount = getAttendingCount()
    saveAttendingCount = ->
      ac = getAttendingCount()
      if ac == attendingCount
        setTimeout saveAttendingCount, 50
      else
        attendingCount = ac
        $('#attending_form .saving').show()
        $.ajax(
          type: 'PUT'
          url: window.location.pathname
          data: { joyent_count: ac }
          error: (xhr, status, err) ->
            $('#attending_form .saving').hide()
            $('#attending_form .error').show().delay('slow').fadeOut()
          success: (data, status, xhr) ->
            $('#attending_form .saving').hide()
            $('#attending_form .saved').show().delay('slow').fadeOut()
          complete: (xhr, status) ->
            setTimeout saveAttendingCount, 50)
    saveAttendingCount()

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
      countdown.html weeks + ' weeks ' + days + ' days ' + hours + ' hours ' + minutes + ' minutes ' + secs + ' seconds'
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

  $('.body.judging img').each ->
    r = 'rotate(' + new String(Math.random()*6-3) + 'deg)'
    $(this)
      .css('-webkit-transform', r)
      .css('-moz-transform', r)
