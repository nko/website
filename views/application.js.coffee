$ ->
  $('time').hover ->
    $this: $(this)
    [y, m, d, h, i, s]: $this.attr('datetime').split(/[-:TZ]/)...
    m--
    ms: Date.UTC y, m, d, h, i, s
    dt: new Date(ms)
    $('<div class="localtime">')
      .html("""
        ${dt.strftime('%a %b %d, %I%P %Z').replace(/\b0/,'')}
        <div>${prettyDate(dt)}</div>
        """)
      .appendTo($this);
  , ->
    $(this).find('.localtime').remove()
