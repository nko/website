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

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    @teams: teams
    @render 'teams/list.html.haml'

# new team
get '/teams/new', ->
  @team: new Team {}, =>
    @render 'teams/new.html.haml'

# create team
post '/teams', ->
  @team: new Team @params.post, =>
    @team.save (errors, res) =>
      if errors?
        @errors: errors
        @render 'teams/new.html.haml'
      else
        @cookie 'teamAuthKey', @team.authKey()
        @redirect '/teams/' + @team.id()

# show team
get '/teams/:id', ->
  Team.first @param('id'), (error, team) =>
    if team?
      @team: team
      people: team.members or []
      @members: _.select people, (person) -> person.name
      @invites: _.without people, @members...
      @editAllowed: @canEditTeam team
      @render 'teams/show.html.haml'
    else
      # TODO make this a 404
      @redirect '/'

# edit team
get '/teams/:id/edit', ->
  Team.first @param('id'), (error, team) =>
    @ensurePermitted team, =>
      @team: team
      @render 'teams/edit.html.haml'

# update team
put '/teams/:id', ->
  Team.first @param('id'), (error, team) =>
    team.update @params.post

    # TODO shouldn't need this
    team.setMembers @params.post.emails, =>
      team.save (errors, result) =>
        if errors?
          @errors: errors
          @team: team
          @render 'teams/edit.html.haml'
        else
          @redirect '/teams/' + team.id()

# delete team
del '/teams/:id', -> # delete not working
  Team.first @param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.remove (error, result) =>
        @redirect '/teams'

# resend invitation
get '/teams/:teamId/invite/:personId', ->
  Team.first @param('teamId'), (error, team) =>
    @ensurePermitted team, =>
      Person.first @param('personId'), (error, person) =>
        person.inviteTo team, =>
          if @isXHR
            @respond 200, 'OK'
          else
            # TODO flash "Sent a new invitation to $@person.email"
            @redirect '/teams/' + team.id()

# edit person
get '/people/:id/edit', ->
  Person.first @param('id'), (error, person) =>
    @ensurePermitted person, =>
      @person: person
      @render 'people/edit.html.haml'

# update person
put '/people/:id', ->
  Person.first @param('id'), (error, person) =>
    @ensurePermitted person, =>
      attributes: @params.post
      delete attributes.password if attributes.password is ''
      attributes.link: '' unless /^https?:\/\//.test attributes.link
      person.update attributes
      person.save (error, resp) =>
        @redirectToTeam person

# sign in
get '/login', ->
  @person: new Person()
  @render 'login.html.haml'

post '/login', ->
  Person.login @params.post, (error, person) =>
    if person?
      @setCurrentPerson person
      if person.name?
        if returnTo: @param('return_to')
          @redirect returnTo
        else @redirectToTeam person
      else
        @redirect '/people/' + person.id() + '/edit'
    else
      @errors: error
      @person: new Person(@params.post)
      @render 'login.html.haml'

get '/logout', ->
  @redirect '/' unless @currentPerson?
  @logout =>
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

Request.include {
  redirectToTeam: (person) ->
    Team.first { 'members._id': person._id }, (error, team) =>
      if team?
        @redirect '/teams/' + team.id()
      else
        @redirect '/'

  redirectToLogin: ->
    @redirect "/login?return_to=$@url.href"

  logout: (fn) ->
    @currentPerson.logout (error, resp) =>
      @setCurrentPerson null
      fn()

  ensurePermitted: (other, fn) ->
    permitted: if other.hasMember?
      @canEditTeam other
    else
      @currentPerson? and (other.id() is @currentPerson.id())
    if permitted then fn()
    else
      unless @currentPerson?
        @redirectToLogin()
      else
        # TODO flash "Oops! You don't have permissions to see that. Try logging in as somebody else."
        @logout =>
          @redirectToLogin()

  canEditTeam: (team) ->
    @cookie('teamAuthKey') is team.authKey() or
      team.hasMember(@currentPerson)
}

server: run parseInt(process.env.PORT || 8000), null
