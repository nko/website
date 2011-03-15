var express = require('express')
  , pub = __dirname + '/public';

var app = express.createServer();

app.use(require('stylus').middleware(pub));
app.use(express.static(pub));
app.use(express.logger());
app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));

app.set('views', __dirname + '/views');
app.set('view engine', 'jade');

app.listen(process.env.PORT || 8000);

app.get('/', function(req, res) {
  res.render('index');
});
