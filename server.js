var http = require('http'), fs = require('fs');
http.createServer(function (req, res) {
  console.log('-> ' + req.url);
  stream(req.url, res);
}).listen(parseInt(process.env.PORT || 8000), null);

function stream(url, res) {
  var path, start, end;

  start = new Date;

  path = 'public' + url.replace(/\?.*/, '');
  if (path === 'public/') {
    path = 'public/index.html';
  }

  fs.createReadStream(path)
    .on('error', function(e) {
      var location = 'http://2010.nodeknockout.com' + url;
      if (e.code === 'ENOENT') { // file not found
        res.writeHead(301, { 'Location': location });
        res.end('Redirecting to ' + location);
        console.log('Redirecting to ' + location);
      } else {
        console.log(e);
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end(e.message);
      }
    }).on('end', function() {
      end = new Date;
      console.log('<- ' + path + ' (' + (end - start) + ' ms)');
    }).pipe(res);
}

