MongoDB: require('./lib/node-mongodb-native/lib/mongodb/db').Db
MongoServer: require('./lib/node-mongodb-native/lib/mongodb/connection').Server

get /.*/, ->
  [host, path]: [@headers.host, @url.href]
  if host == 'www.nodeknockout.com' or host == 'nodeknockout.heroku.com'
    @redirect 'http://nodeknockout.com' + path, 301
  else
    @pass()

get '/', ->
  @render 'index.html.haml'

get '/register', ->
  server: new MongoServer 'localhost', 27017
  db: new MongoDB 'nodeko', server
  @render 'register.html.haml'

get '/*.js', (file) ->
  try
    @render "${file}.js.coffee", { layout: false }
  catch e
    @pass "/${file}.js"

get '/*.css', (file) ->
  @render "${file}.css.sass", { layout: false }

get '/*', (file) ->
  @pass "/public/${file}"

server: run parseInt(process.env.PORT || 8000), null
