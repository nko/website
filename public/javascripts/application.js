(function() {
  var Stars;
  $(function() {
    var _a, countdown, d, h, i, m, ms, s, tick, y;
    $('a.resend').click(function() {
      var a;
      a = $(this);
      a.hide().after('<span>Resending&hellip;</span>');
      $.get(this.href, function() {
        return a.next('span').html('Sent!').fadeOut('slow', function() {
          a.next('span').remove();
          return a.fadeIn();
        });
      });
      return false;
    });
    $('a.delete').click(function() {
      return confirm('Are you sure?');
    });
    $('a.reveal').click(function() {
      $(this).hide().next('.hidden').slideDown(function() {
        return $(this).find('input').select();
      });
      return false;
    });
    $(':input:visible:first:not([rel=nofollow])').focus();
    $('input.url').click(function() {
      if (this.value === this.defaultValue) {
        return this.select();
      }
    });
    $('form.reset_password').submit(function() {
      var email, form;
      form = $(this);
      email = form.find('input.email').val();
      $.ajax({
        type: form.attr('method'),
        url: form.attr('action'),
        data: form.serialize(),
        success: function(data) {
          return form.replaceWith("<h2>" + email + " has been sent a new password</h2>\n<p>It should arrive shortly.</p>");
        },
        error: function(xhr) {
          return $('#errors').append("<li>" + xhr.responseText + "</li>");
        }
      });
      return false;
    });
    $('form').submit(function(evt) {
      var errors, form, hasError, highlightError;
      form = $(this).closest('form');
      errors = $('#errors').html('');
      form.find('input').removeClass('error');
      hasError = false;
      highlightError = function(selector, message, fn) {
        var invalid;
        invalid = form.find(selector).filter(fn);
        if (invalid.length) {
          errors.append(("<li>" + (message) + "</li>"));
          invalid.addClass('error');
          invalid.blur();
          return (hasError = true);
        }
      };
      highlightError('input.email', 'Invalid email address', function() {
        var val;
        val = $(this).val();
        return val && !/^[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test(val);
      });
      highlightError('input[name=name]', 'Name is required', function() {
        return !$(this).val();
      });
      highlightError('input#github', 'GitHub username is required', function() {
        return !$(this).val();
      });
      highlightError('input.email:first', 'Email is required', function() {
        return !$(this).val();
      });
      highlightError('input[type=password]:visible', 'Password required', function() {
        return !$(this).val();
      });
      highlightError('input.url', 'Invalid link', function() {
        var val;
        val = $(this).val();
        return val && val !== this.defaultValue && !/^https?:\/\/.*\./.test(val);
      });
      !(hasError) ? $('input.url').each(function() {
        if (this.value === this.defaultValue) {
          return (this.value = '');
        }
      }) : null;
      return !hasError;
    });
    if ($('.body.index time').length > 0) {
      _a = $('time').attr('datetime').split(/[-:TZ]/);
      y = _a[0];
      m = _a[1];
      d = _a[2];
      h = _a[3];
      i = _a[4];
      s = _a[5];
      ms = Date.UTC(y, m - 1, d, h, i, s);
      countdown = $('#date .about');
      tick = function() {
        var days, diff, hours, minutes, secs;
        diff = (ms - new Date().getTime()) / 1000;
        days = Math.floor(diff % 604800 / 86400);
        hours = Math.floor(diff % 86400 / 3600);
        minutes = Math.floor(diff % 3600 / 60);
        secs = Math.floor(diff % 60);
        countdown.html(days + ' days ' + hours + ' hours ' + minutes + ' minutes ' + secs + ' seconds');
        return setTimeout(tick, 1000);
      };
      tick();
    }
    return $('time').live('hover', function(e) {
      var $this, _b, dt;
      if (e.type === 'mouseout') {
        return $('.localtime').remove();
      }
      $this = $(this);
      _b = $this.attr('datetime').split(/[-:TZ]/);
      y = _b[0];
      m = _b[1];
      d = _b[2];
      h = _b[3];
      i = _b[4];
      s = _b[5];
      ms = Date.UTC(y, m - 1, d, h, i, s);
      dt = new Date(ms);
      return $('<div class="localtime blue">').css({
        left: e.pageX,
        top: $(this).position().top + 25
      }).html((" \
" + (dt.strftime('%a %b %d, %I:%M%P %Z').replace(/\b0/, '')) + " \
")).appendTo(document.body);
    });
  });
  $('.judge img').each(function() {
    var r;
    r = 'rotate(' + new String(Math.random() * 6 - 3) + 'deg)';
    return $(this).css('-webkit-transform', r).css('-moz-transform', r);
  });
  Stars = {
    value: function(elem) {
      return elem.attr('data-value');
    },
    input: function(elem) {
      return elem.closest('.stars').prev('input[type=hidden]');
    },
    set: function(elem) {
      var newVal, oldVal;
      newVal = this.value(elem);
      oldVal = this.input(elem).val();
      return this.input(elem).val(newVal === oldVal ? 0 : newVal);
    },
    highlight: function(elem, hover) {
      var score;
      score = parseInt(hover ? this.value(elem) : this.input(elem).val());
      return elem.closest('.stars').children().each(function(i, star) {
        var $star, fill;
        $star = $(star);
        fill = $star.attr('data-value') <= score;
        $star.find('.filled').toggle(fill);
        return $star.find('.empty').toggle(!fill);
      });
    }
  };
  $('.votes-new, #your_vote').delegate('.star', 'hover', function(e) {
    return Stars.highlight($(this), e.type === 'mouseover');
  }).delegate('.star', 'click', function(e) {
    return Stars.set($(this));
  });
  (function() {
    $('.votes time').each(function() {
      var _a, d, h, i, m, ms, s, y;
      _a = $(this).attr('datetime').split(/[-:TZ]/);
      y = _a[0];
      m = _a[1];
      d = _a[2];
      h = _a[3];
      i = _a[4];
      s = _a[5];
      ms = Date.UTC(y, m - 1, d, h, i, s);
      return $(this).text(prettyDate(new Date(ms)));
    });
    return setTimeout(arguments.callee, 10 * 1000);
  })();
  $('.votes .more').each(function() {
    var $more, loadMoreNow, page;
    $more = $(this);
    loadMoreNow = $more.position().top - $(window).height() + 10;
    page = 1;
    return $(window).scroll(function(e) {
      if (loadMoreNow && this.scrollY > loadMoreNow) {
        loadMoreNow = null;
        return $.get(window.location.pathname + ("/votes.js?page=" + (++page)), function(html) {
          var moreVotes;
          moreVotes = $('<div class="page">').html(html);
          $more.remove();
          $('.votes').append(moreVotes);
          if (moreVotes.find('li').length === 51) {
            $('.votes').append($more);
            return (loadMoreNow = $more.position().top - $(window).height() + 10);
          }
        });
      }
    });
  });
  $('#your_vote a[href$=draft]').click(function() {
    var _a;
    return (typeof (_a = window.localStorage) !== "undefined" && _a !== null) ? (localStorage['draft'] = JSON.stringify($(this).closest('form').serializeArray())) : null;
  });
  $('.teams-show #your_vote').each(function() {
    var _a, _b, _c, _d, _e, el;
    if (!((typeof (_a = window.localStorage == undefined ? undefined : window.localStorage.draft) !== "undefined" && _a !== null) && window.location.hash === '#draft')) {
      return null;
    }
    try {
      _b = []; _d = JSON.parse(localStorage.draft);
      for (_c = 0, _e = _d.length; _c < _e; _c++) {
        el = _d[_c];
        _b.push($(this[el.name]).val(el.value));
      }
      return _b;
    } finally {
      delete localStorage.draft;
    }
  });
  $('.votes-new .stars, #your_vote .stars').each(function() {
    return Stars.highlight($(this));
  });
})();
