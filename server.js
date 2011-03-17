var express = require('express')
  , io = require('socket.io')
  , util = require('util')
  , pub = __dirname + '/public'
  , port = process.env.PORT || 8000;

// express
var app = express.createServer();
app.get('/', function(req, res) {
  res.render('index');
});
app.listen(port);

// socket.io
var ws = io.listen(app);
ws.on('connection', function(client) {
  client
    .on('message', function(data) {
      data = JSON.parse(data);
      data.sessionId = client.sessionId;

      ws.broadcast(JSON.stringify(data), client.sessionId);
    })
    .on('disconnect', function() {
      ws.broadcast(JSON.stringify({
        sessionId: client.sessionId, disconnect: true
      }));
    });
});

util.log("listening on 0.0.0.0:" + port + ".");

// config
app.configure(function() {
  app.use(require('stylus').middleware(pub));
  app.use(express.logger());
  app.set('views', __dirname + '/views');
  app.set('view engine', 'jade');
});

app.configure('development', function() {
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
  app.use(express.static(pub));
  app.set('view options', { scope: { development: true }});
});

app.configure('production', function() {
  app.use(express.errorHandler());
  app.use(express.static(pub, { maxAge: 1000 * 5 * 60 }));
  app.set('view options', { scope: { development: false }});
});
