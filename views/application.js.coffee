$ ->
  $('a.resend').click ->
    a: $ this
    a.hide().after '<span>Resending&hellip;</span>'
    $.get @href, ->
      a.next('span').html('Sent!').fadeOut 'slow', ->
        a.next('span').remove()
        a.fadeIn()
    false

  $('a.delete').click ->
    confirm 'Are you sure?'

  if $('time').length > 0
    [y, m, d, h, i, s]: $('time').attr('datetime').split(/[-:TZ]/)...
    ms: Date.UTC y, m-1, d, h, i, s
    $('<div class="about">')
      .html(prettyDate(new Date(ms)))
      .appendTo('#date')

  $('time').hover ->
    $this: $(this)
    [y, m, d, h, i, s]: $this.attr('datetime').split(/[-:TZ]/)...
    ms: Date.UTC y, m-1, d, h, i, s
    dt: new Date(ms)
    $('<div class="localtime blue">')
      .html("
        ${dt.strftime('%a %b %d, %I%P %Z').replace(/\b0/,'')}
        <div>${prettyDate(dt)}</div>
        ")
      .appendTo($this)
  , ->
    $(this).find('.localtime').remove()
