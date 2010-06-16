sys: require 'sys'
Request: require('express/request').Request
models: require './models/models'
[Team, Person]: [models.Team, models.Person]

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
        @redirect '/teams/' + @team.id()

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    @teams: teams
    @render 'teams/list.html.haml'

# show team
get '/teams/:id', ->
  Team.first @param('id'), (error, team) =>
    if team?
      @team: team
      @members: team.members or []
      @render 'teams/show.html.haml'
    else
      @redirect '/'

# delete team
del '/teams/:id', -> # delete not working
  Team.first @param('id'), (error, team) =>
    team.remove (error, result) =>
      @redirect '/teams'

# edit person
get '/people/:id/edit', ->
  Person.first @param('id'), (error, person) =>
    @person: person
    @render 'people/edit.html.haml'

# update person
put '/people/:id', ->
  Person.first @param('id'), (error, person) =>
    attributes: @params.post
    delete attributes.password if attributes.password is ''
    person.update attributes
    person.save (error, resp) =>
      redirectToTeam this, person

# sign in
get '/login', ->
  @person: new Person()
  @render 'login.html.haml'

post '/login', ->
  Person.login @params.post, (error, person) =>
    if person?
      @setCurrentPerson person
      if person.name?
        redirectToTeam this, person
      else
        @redirect '/people/' + person.id() + '/edit'
    else
      @errors: error
      @person: new Person(@params.post)
      @render 'login.html.haml'

redirectToTeam: (request, person) ->
  Team.first { 'members._id': person._id }, (error, team) =>
    if team?
      request.redirect '/teams/' + team.id()
    else
      request.redirect '/'

get '/logout', ->
  @redirect '/' unless @currentPerson?
  @currentPerson.logout (error, resp) =>
    @setCurrentPerson null
    @redirect '/'

get '/*.js', (file) ->
  try
    @render "${file}.js.coffee", { layout: false }
  catch e
    @pass "/${file}.js"

get '/*.css', (file) ->
  @render "${file}.css.sass", { layout: false }

get '/*', (file) ->
  try
    @render "${file}.html.haml"
  catch e
    @pass "/${file}"

get '/*', (file) ->
  @pass "/public/${file}"

configure ->
  CurrentPerson: Plugin.extend {
    extend: {
      init: ->
        Request.include {
          setCurrentPerson: (person) ->
            @cookie 'authKey', person?.authKey()
          getCurrentPerson: (fn) ->
            Person.firstByAuthKey @cookie('authKey'), fn
        }
    }

    'on': {
      request: (event, fn) ->
        event.request.getCurrentPerson (error, person) ->
          event.request.currentPerson: person
          fn()
        true # wait for async completion
    }
  }
  use CurrentPerson

server: run parseInt(process.env.PORT || 8000), null
