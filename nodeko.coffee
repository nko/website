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

get '/register', ->
  if @currentPerson?
    @redirectToTeam @currentPerson, '/teams/new'
  else
    @redirect '/teams/new'

get '/', ->
  Team.all (error, teams) =>
    @spotsLeft: 200 - teams.length
    @render 'index.html.haml'

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    @teams: teams
    @yourTeams: if @currentPerson?
      _.select teams, (team) =>
        # TODO this is gross
        _ids: _.pluck(team.members, '_id')
        _.include _.pluck(_ids, 'id'), @currentPerson._id.id
    else []
    @render 'teams/index.html.haml'

# new team
get '/teams/new', ->
  Team.all (error, teams) =>
    if teams.length >= 200
      @redirect '/'
    else
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
    @ensurePermitted team, =>
      team.joyent_count: or 0
      team.update @params.post
      save: =>
        team.save (errors, result) =>
          if errors?
            @errors: errors
            @team: team
            @render 'teams/edit.html.haml'
          else
            @redirect '/teams/' + team.id()
      # TODO shouldn't need this
      if @params.post.emails
        team.setMembers @params.post.emails, save
      else save()

# delete team
del '/teams/:id', -> # delete not working
  Team.first @param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.remove (error, result) =>
        @redirect '/'

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

      # TODO this shouldn't be necessary
      person.setPassword attributes.password if attributes.password
      delete attributes.password

      attributes.link: '' unless /^https?:\/\/.+\./.test attributes.link
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
      if @param 'remember'
        d: new Date()
        d.setTime(d.getTime() + 1000 * 60 * 60 * 24 * 180)
        options: { expires: d }
      @setCurrentPerson person, options
      if person.name
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

# reset password
post '/reset_password', ->
  Person.first { email: @param('email') }, (error, person) =>
    # TODO assumes xhr
    unless person?
      @respond 404, 'Email not found'
    else
      person.resetPassword =>
        @respond 200, 'OK'

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
    throw e if e.errno != 2
    @pass "/${file}"

get '/*', (file) ->
  @pass "/public/${file}"

configure ->
  CurrentPerson: Plugin.extend {
    extend: {
      init: ->
        Request.include {
          setCurrentPerson: (person, options) ->
            @cookie 'authKey', person?.authKey(), options
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
  redirectToTeam: (person, alternatePath) ->
    Team.first { 'members._id': person._id }, (error, team) =>
      if team?
        @redirect '/teams/' + team.id()
      else
        @redirect (alternatePath or '/')

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
