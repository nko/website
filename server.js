var express = require('express')
  , io = require('socket.io')
  , util = require('util')
  , pub = __dirname + '/public'
  , port = process.env.PORT || 8000;

var app = express.createServer();

app.use(require('stylus').middleware(pub));
app.use(express.static(pub));
app.use(express.logger());
app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));

app.set('views', __dirname + '/views');
app.set('view engine', 'jade');

app.listen(port);

app.get('/', function(req, res) {
  res.render('index');
});

var ws = io.listen(app)
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
