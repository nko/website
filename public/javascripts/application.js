(function(b){function c(){}for(var d="assert,count,debug,dir,dirxml,error,exception,group,groupCollapsed,groupEnd,info, log,markTimeline,profile,profileEnd,time,timeEnd,trace,warn".split(","),a;a=d.pop();)b[a]=b[a]||c})(window.console=window.console||{});

var nko = { };

nko.Vector = function(x, y) {
  this.x = x || 0;
  this.y = y || 0;
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

nko.Thing = function(name, options) {
  if (!name) return;

  var self = this
    , options = options || {};

  this.div = $('<div class="thing">');

  this.name = name;
  this.img = $('<img>', { src: '/images/734m/' + this.name + '.png' })
    .load(function() {
      self.size = new nko.Vector(this.width, this.height);
      self.draw();
    });

  this.pos = options.pos || new nko.Vector(150, 150);
};
nko.Thing.prototype.draw = function draw() {
  var offset = new nko.Vector(this.size.x * -0.5, -this.size.y + 20);
  this.div
    .css({
      left: this.pos.x,
      top: this.pos.y,
      width: this.size.x,
      height: this.size.y,
      '-webkit-transform': 'translate(' + offset.toString() + ')',
      background: 'url(' + this.img.attr('src') + ')'
    })
    .appendTo(document.body);
  this.animate();
};
nko.Thing.prototype.animate = function() { };

nko.Dude = function(name, options) {
  nko.Thing.call(this, name, options);

  this.state = 'idle';
  this.frame = 0;
};
nko.Dude.prototype = new nko.Thing();
nko.Dude.prototype.constructor = nko.Dude;

nko.Dude.prototype.draw = function draw() {
  this.size.x = this.size.x / 10;
  nko.Thing.prototype.draw.call(this);
};

nko.Dude.prototype.frames = { w: 2, e: 4, s: 6, n: 8 };
nko.Dude.prototype.animate = function animate(state) {
  var self = this;
  clearTimeout(this.animateTimeout);

  if (state) this.state = state;
  this.frame = ((this.frame + 1) & 1) + (this.frames[this.state] || 0);
  this.div.css('background-position', '-' + (this.frame * this.size.x) + 'px 0px');
  this.animateTimeout = setTimeout(function() { self.animate() }, 500);
};

nko.Dude.prototype.goTo = function(pos) {
  this.pos = new nko.Vector(this.div.offset().left, this.div.offset().top);

  var self = this
    , delta = pos.minus(this.pos)
    , duration = delta.length() / 150 * 1000;
  this.animate(delta.cardinalDirection());
  this.div
    .stop()
    .animate({ left: pos.x, top: pos.y }, duration, 'linear', function() {
      self.pos = pos;
      self.animate('idle');
    });

  var $win = $(window)
    , left = $win.scrollLeft()
    , top = $win.scrollTop()
    , right = left + $win.width()
    , bottom = top + $win.height()
    , buffer = 200
    , newLeft = left, newTop = top;

  if (pos.x < left + buffer)
    newLeft = left - $win.width() + buffer;
  else if (pos.x > right - buffer)
    newLeft = right - buffer;

  if (pos.y < top + buffer)
    newTop = top - $win.height() + buffer;
  else if (pos.y > bottom - buffer)
    newTop = bottom - buffer;

  $('body')
    .stop()
    .animate({ scrollLeft: newLeft, scrollTop: newTop }, duration, 'linear');
};

$(function() {
  var parts, start;
  parts = $('time.start').attr('datetime').split(/[-:TZ]/);
  parts[1]--; // js dates :(
  start = Date.UTC.apply(null, parts);

  $('#countdown').each(function() {
    var $this = $(this);
    (function tick() {
      $this.html(countdownify((start - (new Date)) / 1000));
      return setTimeout(tick, 1000);
    })();

    function countdownify(secs) {
      var names = ['day', 'hour', 'minute', 'second'];
      return $.map([secs / 86400, secs % 86400 / 3600, secs % 3600 / 60, secs % 60], function(num, i) {
        return [Math.floor(num), pluralize(names[i], num)];
      }).join(' ');
    }

    function pluralize(str, count) {
      return str + (parseInt(count) !== 1 ? 's' : '');
    }
  });

  var me = new nko.Dude('suite', { pos: new nko.Vector(920, 400) });

  new nko.Thing('streetlamp', { pos: new nko.Vector(220, 190) });

  // mark the ends of the universe
  //new nko.Thing('streetlamp', { pos: new nko.Vector(-10000, -10000) });
  new nko.Thing('streetlamp', { pos: new nko.Vector(10000, 10000) });

  $(window).click(function(e) {
    me.goTo(new nko.Vector(e.pageX, e.pageY));
  });
});
