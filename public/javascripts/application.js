(function(b){function c(){}for(var d="assert,count,debug,dir,dirxml,error,exception,group,groupCollapsed,groupEnd,info, log,markTimeline,profile,profileEnd,time,timeEnd,trace,warn".split(","),a;a=d.pop();)b[a]=b[a]||c})(window.console=window.console||{});

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
});
