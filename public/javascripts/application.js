// safe console usage
(function(b){function c(){}for(var d="assert,count,debug,dir,dirxml,error,exception,group,groupCollapsed,groupEnd,info, log,markTimeline,profile,profileEnd,time,timeEnd,trace,warn".split(","),a;a=d.pop();)b[a]=b[a]||c})(window.console=window.console||{});

//// a lil place for ourselves
var nko = { };


//// Vector
nko.Vector = function(x, y) {
  if (typeof(x) === 'undefined') return
  if (typeof(x) === 'number') {
    this.x = x || 0;
    this.y = y || 0;
  } else {
    this.x = x.x;
    this.y = x.y;
  }
};
nko.Vector.prototype = {
  constructor: nko.Vector,

  plus: function(other) {
    return new this.constructor(this.x + other.x, this.y + other.y);
  },

  minus: function(other) {
    return new this.constructor(this.x - other.x, this.y - other.y);
  },

  times: function(s) {
    return new this.constructor(this.x * s, this.y * s);
  },

  length: function() {
    return Math.sqrt(Math.pow(this.x, 2) + Math.pow(this.y, 2));
  },

  toString: function() {
    return this.x + 'px, ' + this.y + 'px';
  },

  cardinalDirection: function() {
    if (Math.abs(this.x) > Math.abs(this.y))
      return this.x < 0 ? 'w' : 'e';
    else
      return this.y < 0 ? 'n' : 's';
  }
};


//// Thing
nko.Thing = function(options) {
  if (!options) return;

  var self = this
    , options = options || {};

  this.name = options.name;
  this.pos = new nko.Vector(options.pos);
  this.size = new nko.Vector(options.size);

  this.div = $('<div class="thing">');
  this.img = $('<img>', { src: '/images/734m/' + this.name + '.png' })
    .load(function() {
      self.size = new nko.Vector(this.width, this.height);
      self.draw();
    });
};

nko.Thing.prototype.toJSON = function() {
  return {
    name: this.name,
    pos: this.pos,
    size: this.size
  };
};

nko.Thing.prototype.draw = function draw() {
  var offset = new nko.Vector(this.size.x * -0.5, -this.size.y + 20);
  this.div
    .css({
      left: this.pos.x,
      top: this.pos.y,
      width: this.size.x,
      height: this.size.y,
      'z-index': this.pos.y,
      transform: 'translate(' + offset.toString() + ')',
      background: 'url(' + this.img.attr('src') + ')'
    })
    .appendTo(document.body);
  this.animate();

  return this;
};

nko.Thing.prototype.animate = function() { };

nko.Thing.prototype.remove = function() {
  this.div.fadeOut(function() { $(this).remove(); });
};


//// Dude
nko.Dude = function(options) {
  nko.Thing.call(this, options);

  this.state = 'idle';
  this.frame = 0;
  this.bubbleFrame = 0;
};
nko.Dude.prototype = new nko.Thing();
nko.Dude.prototype.constructor = nko.Dude;

nko.Dude.prototype.draw = function draw() {
  this.idleFrames = (this.size.x - 640) / 80;
  this.size.x = 80;

  this.bubble = $('<div class="bubble">')
    .css('bottom', this.size.y + 10)
    .appendTo(this.div);

  return nko.Thing.prototype.draw.call(this);
};

nko.Dude.prototype.frameOffset = { w: 0, e: 2, s: 4, n: 6, idle: 8 };
nko.Dude.prototype.animate = function animate(state) {
  var self = this;

  clearTimeout(this.animateTimeout);
  if (state) this.state = state;

  var frames = this.state === 'idle' ? this.idleFrames : 2;
  this.frame = ((this.frame + 1) % frames) + this.frameOffset[this.state];
  this.div.css('background-position', (-this.frame * this.size.x) + 'px 0px');

  if (this.bubble.is(':visible')) {
    this.bubbleFrame = (this.bubbleFrame + 1) % 3;
    this.bubble.css('border-image', "url('/images/734m/talkbubble" + this.bubbleFrame + ".png') 21 20 42 21");
  }

  this.animateTimeout = setTimeout(function() { self.animate() }, 400);
};

nko.Dude.prototype.goTo = function(pos) {
  pos = new nko.Vector(pos);

  var self = this
    , delta = pos.minus(this.pos)
    , duration = delta.length() / 200 * 1000;
  this.animate(delta.cardinalDirection());
  this.div
    .stop()
    .animate({
      left: pos.x,
      top: pos.y
    }, {
      duration: duration,
      easing: 'linear',
      step: function(now, fx) {
        switch (fx.prop) {
          case 'left':
            self.pos.x = now;
            break;
          case 'top':
            self.pos.y = now;
            self.div.css('z-index', Math.floor(now));
            break;
        }
      },
      complete: function() {
        self.pos = pos;
        self.animate('idle');
      }
    });
};

nko.Dude.prototype.speak = function(text) {
  if (!text)
    this.bubble.fadeOut();
  else
    this.bubble
      .text(text)
      .scrollTop(this.bubble.attr("scrollHeight"))
      .fadeIn();
};


$(function() {
  // countdown
  var parts, start;
  parts = $('time.start').attr('datetime').split(/[-:TZ]/);
  parts[1]--; // js dates :( js dates are hot dates.
  start = Date.UTC.apply(null, parts);

  $('#countdown').each(function() {
    var $this = $(this);

    (function tick() {
      var names = ['day', 'hour', 'minute', 'second']
        , secs = (start - (new Date)) / 1000
        , left = $.map([secs / 86400, secs % 86400 / 3600, secs % 3600 / 60, secs % 60], function(num, i) {
          return [Math.floor(num), pluralize(names[i], num)];
        }).join(' ');

      $this.html(left + ' from now');
      return setTimeout(tick, 800);
    })();

    function pluralize(str, count) {
      return str + (parseInt(count) !== 1 ? 's' : '');
    }
  });

  // a dude
  var types = [ 'suit', 'littleguy', 'beast', 'gifter' ];
  var me = new nko.Dude({
    name: types[Math.floor(types.length * Math.random())],
    pos: new nko.Vector(4000 + Math.random() * 800, 4200 + Math.random() * 200)
  });

  // some flare
  new nko.Thing({ name: 'streetlamp', pos: new nko.Vector(4080, 4160) });
  new nko.Thing({ name: 'livetree', pos: new nko.Vector(3920, 4000) });
  new nko.Thing({ name: 'livetree', pos: new nko.Vector(4080, 3920) });

  new nko.Thing({ name: 'livetree', pos: new nko.Vector(3840, 4960) });
  new nko.Thing({ name: 'deadtree', pos: new nko.Vector(4000, 4960) });
  new nko.Thing({ name: 'portopotty', pos: new nko.Vector(4080, 4960) });

  // mark the ends of the universe
  //new nko.Thing({ name: 'streetlamp', pos: new nko.Vector(0, 0) });
  new nko.Thing({ name: 'streetlamp', pos: new nko.Vector(8000, 8000) });

  $(window)
    .load(function() { // center it
      var page = $('.page#index')
        , pos = page.position()
        , left = pos.left - ($(this).width() - page.width()) / 2
        , top = pos.top - ($(this).height() - page.height()) / 2;
      $(this).scrollLeft(left).scrollTop(top)
    })
    .click(function(e) { // move on click
      var pos = { x: e.pageX, y: e.pageY };
      me.goTo(pos);
      ws.send(JSON.stringify({
        obj: me,
        method: 'goTo',
        arguments: [ pos ]
      }));

      // TODO move into nko.Viewport
      var $win = $(this)
        , left = $win.scrollLeft()
        , top = $win.scrollTop()
        , right = left + $win.width()
        , bottom = top + $win.height()
        , buffer = 160
        , newLeft = left, newTop = top;

      if (pos.x < left + buffer)
        newLeft = left - $win.width()/2;
      else if (pos.x > right - buffer)
        newLeft = left + $win.width()/2;

      if (pos.y < top + buffer)
        newTop = top - $win.height()/2;
      else if (pos.y > bottom - buffer)
        newTop = top + $win.height()/2;

      $('body')
        .stop()
        .animate({ scrollLeft: newLeft, scrollTop: newTop }, 1000, 'linear');
    });
  $('body')
    .bind('touchstart', function(e) { // move on touch
      var t = e.originalEvent.touches.item(0);
      me.goTo(new nko.Vector(t.pageX, t.pageY));
    });

  // keyboard
  var speakTimeout, $text = $('<textarea>')
    .appendTo($('<div class="textarea-container">')
    .appendTo(me.div))
    .bind('keylisten keyup', function(e) {
      var text = $text.val();
      switch (e.keyName) {
        case "up":
        case "down":
        case "left":
        case "right":
          // TODO move
          return false;
        default:
          me.speak(text);
          ws.send(JSON.stringify({
            obj: me,
            method: 'speak',
            arguments: [ text ]
          }));
          clearTimeout(speakTimeout);
          speakTimeout = setTimeout(function() {
            $text.val('');
            me.speak();
            ws.send(JSON.stringify({
              obj: me,
              method: 'speak'
            }));
          }, 5000);
      }
    }).focus();
  $(document).keylisten(function() { $text.focus() });

  // socket
  var dudes = {};
  var ws = new io.Socket();
  ws.on('connect', function() {
    ws.send(JSON.stringify({ obj: me }));
  });
  ws.on('message', function(data) {
    var data = JSON.parse(data)
      , dude = dudes[data.sessionId];

    if (data.disconnect && dude) {
      dude.remove();
      delete dudes[data.sessionId];
    }

    if (data.obj && !dude)
      dude = dudes[data.sessionId] = new nko.Dude(data.obj).draw();

    if (data.method)
      nko.Dude.prototype[data.method].apply(dude, data.arguments);
  });

  ws.connect();
});
