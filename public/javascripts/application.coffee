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

  $(':input:visible:first:not([rel=nofollow])').focus()

  $('input.url').click ->
    this.select() if @value is @defaultValue

  ajaxForm = (form, options) ->
    options.type = form.attr('method')
    options.url = form.attr('action')
    options.data = form.serialize()
    $.ajax(options)

  $('form.reset_password').submit ->
    form = $ this
    email = form.find('input.email').val()
    ajaxForm(form,
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

  $('.body.index .countdown').each ->
    start = Date.UTC 2010, 7, 30, 0, 0, 0
    countdown = $('#date .countdown')
    tick = ->
      diff = (start - new Date().getTime()) / 1000
      if diff <= 0
        countdown.html "TIME'S UP!"
      else
        hours = Math.floor diff / 3600
        minutes = Math.floor diff % 3600 / 60
        secs = Math.floor diff % 60
        countdown.html (if hours > 0 then hours + ' hours ' else '') + (if minutes > 0 || hours > 0 then minutes + ' minutes ' else minutes) + secs + ' seconds'
        setTimeout tick, 1000
    tick()

  $('.body.index time').live 'hover', (e) ->
    return $('.localtime').remove() if e.type == 'mouseout'

    $this = $(this)
    [y, m, d, h, i, s] = $this.attr('datetime').split(/[-:TZ]/)...
    ms = Date.UTC y, m-1, d, h, i, s
    dt = new Date(ms)
    $('<div class="localtime blue">').css({
      left: e.pageX
      top: $(this).position().top + 25
    }).html("#{dt.strftime('%a %b %d, %I:%M%P %Z').replace(/\b0/,'')}").appendTo(document.body)

  $('.judge img').each ->
    r = 'rotate(' + new String(Math.random()*6-3) + 'deg)'
    $(this)
      .css('-webkit-transform', r)
      .css('-moz-transform', r)

  $('.application .deployed .more a').click ->
    $('.deploy').slideToggle 'fast'
    false

  Stars = {
    hoverAt: null
    value: (elem) ->
      elem.attr('data-value')
    input: (elem) ->
      elem.closest('.stars').prev('input[type=hidden]')
    set: (elem) ->
      newVal = @value(elem)
      oldVal = @input(elem).val()
      @input(elem).val(if newVal is oldVal then 0 else newVal)
    highlight: (elem, hover) ->
      Stars.hoverAt or= +new Date()
      score = parseInt(if hover then @value(elem) else @input(elem).val())
      elem.closest('.stars').children().each (i, star) ->
        $star = $(star)
        fill = $star.attr('data-value') <= score
        $star.find('.filled').toggle(fill)
        $star.find('.empty').toggle(!fill)
  }

  $('#your_vote')
    .delegate('.edit .star', 'hover', (e) -> Stars.highlight $(this), e.type == 'mouseover')
    .delegate('.edit .star', 'click', (e) -> Stars.set $(this))

  (->
    $('.votes time').each ->
      [y, m, d, h, i, s] = $(this).attr('datetime').split(/[-:TZ]/)...
      ms = Date.UTC y, m-1, d, h, i, s
      $(this).text(prettyDate(new Date(ms)))
    setTimeout arguments.callee, 10 * 1000
  )()

  $('.votes .more').each ->
    $more = $(this)
    loadMoreNow = $more.position().top - $(window).height() + 10
    page = 1
    $(window).scroll (e) ->
      if loadMoreNow && this.scrollY > loadMoreNow
        loadMoreNow = null
        $.get window.location.pathname + "/votes.js?page=#{++page}", (html) ->
          moreVotes = $('<div class="page">').html(html)
          $more.remove()
          $('.votes').append(moreVotes)
          if moreVotes.find('li').length == 51
            $('.votes').append($more)
            loadMoreNow = $more.position().top - $(window).height() + 10

  saveDraft = (form) =>
    return unless window.localStorage?
    localStorage['draft'] = JSON.stringify form.serializeArray()

  $('#your_vote a[href$=draft]').click ->
    saveDraft $(this).closest('form')

  prependVote = (data) ->
    $(data).prependTo('ul.votes')
      .hide()
      .next('li.header').remove().end()
      .slideDown('fast')

  updateVote = (data) ->
    $newVote = $(data)
    id = $newVote.attr('id')
    $('#'+id).replaceWith($newVote)
    $newVote

  showVote = ($form, $vote) ->
    $form.find('.show .comment').html($vote.find('.comment').html())
    $form.find('.vote').removeClass('edit').addClass('show')

  changeForm = ($form, $vote) ->
    $form
      .attr('method', 'PUT')
      .attr('action', window.location.pathname + '/votes/' + $vote.attr('id'))
      .find('input[type=submit]').val('Save')
    showVote($form, $vote)

  $('#your_vote').submit (e) ->
    $form = $(this)
    $errors = $form.find('#errors')

    # error was caught in the prior on submit
    if $errors.find('li').length
      $errors.slideDown()
      return false

    $('<input type="hidden" name="hoverAt">').val(Stars.hoverAt).appendTo($form)
    ajaxForm $form,
      beforeSend: -> $form.find(':input').attr('disabled', true)
      complete: -> $form.find(':input').attr('disabled', false)
      success: (data) ->
        if $('#your_vote .email_input').length # not logged in
          window.location.reload()
        else
          if $form.attr('method') is 'POST'
            $vote = prependVote(data).eq(-1)
            changeForm($form, $vote)
          else
            $vote = updateVote(data)
            showVote($form, $vote)
      error: (xhr) ->
        if xhr.status is 403 # unauthorized
          # TODO flash you tried to use an email
          saveDraft $form
          email = encodeURIComponent $form.find('#email').val()
          path = encodeURIComponent window.location.pathname + '#save'
          window.location = "/login?return_to=#{path}&email=#{email}"
        else
          errors = JSON.parse(xhr.responseText)
          $errors.html(errors.map((error) -> "<li>#{error}</li>").join("\n"))
            .slideDown()
    false

  $('#your_vote').delegate '.vote.show .show a.change', 'click', ->
    $(this).closest('.vote').removeClass('show').addClass('edit')
    false

  $('#your_vote').delegate 'label .tip', 'hover', (e) ->
    tips = $('#your_vote').find('.tips div')
    stars = $('#your_vote').find('.stars')
    if e.type == 'mouseout'
      tips.hide()
      stars.show()
    else
      stars.hide()
      t = $(this).parent().next('input').attr('id')
      $('#your_vote .tips .' + t).show()

  $('.teams-show #your_vote').each ->
    hash = window.location.hash
    draft = window.localStorage?.draft?
    try
      return unless draft and (hash is '#save' or hash is '#draft')
      $(this[el.name]).val el.value for el in JSON.parse draft
      # $('#your_vote').submit() if window.location.hash is '#save'
    finally
      delete localStorage.draft
  $('.votes-new .stars, #your_vote .stars').each -> Stars.highlight $(this)
