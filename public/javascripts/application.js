(function(b){function c(){}for(var d="assert,count,debug,dir,dirxml,error,exception,group,groupCollapsed,groupEnd,info, log,markTimeline,profile,profileEnd,time,timeEnd,trace,warn".split(","),a;a=d.pop();)b[a]=b[a]||c})(window.console=window.console||{});

var nko = { };

nko.Vector = function(x, y) {
  this.x = x || 0;
  this.y = y || 0;
};
nko.Vector.prototype = {
  constructor: nko.Vector,

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

nko.Dude = function(name) {
  var self = this;

  this.world = $('body');
  this.div = $('<div class="dude">');

  this.name = name || 'littleguy';
  this.img = $('<img>', { src: '/images/734m/' + this.name + '.png' })
    .bind('load', function() {
      self.size = new nko.Vector(this.width / 10, this.height);
      self.draw();
    });

  this.pos = new nko.Vector(150, 150);

  this.state = 'idle';
  this.frame = 0;
};
nko.Dude.prototype = {
  constructor: nko.Dude,

  draw: function draw() {
    this.div
      .css({
        left: this.pos.x,
        top: this.pos.y,
        width: this.size.x,
        height: this.size.y,
        '-webkit-transform': 'translate(' + this.size.times(-0.5).toString() + ')',
        background: 'url(' + this.img.attr('src') + ')'
      })
      .appendTo(this.world);
    this.animate();
  },

  frames: { w: 2, e: 4, s: 6, n: 8 },
  animate: function animate(state) {
    var self = this;
    clearTimeout(this.animateTimeout);

    if (state) this.state = state;
    this.frame = ((this.frame + 1) & 1) + (this.frames[this.state] || 0);
    this.div.css('background-position', '-' + (this.frame * this.size.x) + 'px 0px');
    this.animateTimeout = setTimeout(function() { self.animate() }, 500);
  },

  goTo: function(pos) {
    var self = this
      , delta = pos.minus(this.pos)
      , duration = delta.length() / 150 * 1000;
    this.animate(delta.cardinalDirection());
    this.div.animate({ left: pos.x, top: pos.y }, duration, 'linear', function() {
      self.pos = pos;
      self.animate('idle');
    });
  }
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

  $(window).click(function(e) {
    me.goTo(new nko.Vector(e.pageX, e.pageY));
  });

  var me = new nko.Dude();
});
