// bootstrap server config
require.paths.unshift('./lib/connect/lib', './lib/express/lib', './lib/coffee/lib')
require.paths.unshift('lib/express/lib/support/haml/lib/', 'lib/express/lib/support/sass/lib/', 'lib/express/support/jade/lib/', 'lib/express/support/jade/support/markdown/lib')
require('coffee'); // coffeescript!
require('./nodeko')
