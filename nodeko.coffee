sys: require 'sys'
models: require './models/models'
Team: models.Team

get /.*/, ->
  [host, path]: [@headers.host, @url.href]
  if host == 'www.nodeknockout.com' or host == 'nodeknockout.heroku.com'
    @redirect 'http://nodeknockout.com' + path, 301
  else
    @pass()

get '/', ->
  @render 'index.html.haml'

# new team
get '/teams/new', ->
  @team: new Team {}, =>
    @render 'teams/new.html.haml'

# create team
post '/teams', ->
  @team: new Team @params.post, =>
    @team.save (error, res) =>
      if error?
        @error: error
        @render 'teams/new.html.haml'
      else
        @redirect '/teams'

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    @teams: teams
    @render 'teams/list.html.haml'

# show team
get '/teams/:id', ->
  Team.first @param('id'), (error, team) =>
    @team: team
    sys.puts sys.inspect @team
    @members: team.members or []
    @render 'teams/show.html.haml'

# delete team
post '/teams/:id', -> # delete not working
  Team.first @param('id'), (error, team) =>
    team.remove (error, result) =>
      @redirect '/teams'

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
