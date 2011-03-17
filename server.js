var express = require('express')
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

console.log("listening on 0.0.0.0:" + port + ".");
