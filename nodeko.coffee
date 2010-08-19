sys = require 'sys'
connect = require 'connect'
express = require 'express'

models = require './models/models'
[Team, Person, Vote] = [models.Team, models.Person, models.Vote]

pub = __dirname + '/public';
app = express.createServer(
  connect.compiler({ src: pub, enable: ['sass'] }),
  connect.staticProvider(pub)
)

app.use connect.logger()
app.use connect.bodyDecoder()
app.use connect.methodOverride()
app.use connect.cookieDecoder()

Hoptoad = require('./lib/hoptoad-notifier/lib/hoptoad-notifier').Hoptoad
Hoptoad.key = 'b76b10945d476da44a0eac6bfe1aeabd'
process.on 'uncaughtException', (e) ->
  Hoptoad.notify e

request = (type) ->
  (path, fn) ->
    app[type] path, (req, res, next) ->
      Person.firstByAuthKey req.cookies.authkey, (error, person) =>
        ctx = {
          sys: sys
          req: req
          res: res
          next: next
          redirect: __bind(res.redirect, res),
          cookie: (key, value, options) ->
            value ||= ''
            options ||= {}
            cookie = "#{key}=#{value}"
            for k, v of options
              cookie += "; #{k}=#{v}"
            res.header('Set-Cookie', cookie)
          render: (file, opts) ->
            opts ||= {}
            opts.locals ||= {}
            opts.locals.view = file.replace(/\..*$/,'').replace(/\//,'-')
            opts.locals.ctx = ctx
            res.render file, opts
          currentPerson: person
          setCurrentPerson: (person, options) ->
            @cookie 'authKey', person?.authKey(), options
          redirectToTeam: (person, alternatePath) ->
            Team.first { 'members._id': person._id }, (error, team) =>
              if team?
                @redirect '/teams/' + team.toParam()
              else
                @redirect (alternatePath or '/')
          redirectToLogin: ->
            @redirect "/login?return_to=#{@req.url}"
          logout: (fn) ->
            @currentPerson.logout (error, resp) =>
              @setCurrentPerson null
              fn()
          canEditTeam: (team) ->
            req.cookies.teamauthkey is team.authKey() or
              team.hasMember(@currentPerson) or
              (@currentPerson? and @currentPerson.admin())
          ensurePermitted: (other, fn) ->
            permitted = (@currentPerson? and @currentPerson.admin() or
              other.hasMember? and @canEditTeam(other) or
              !other.hasMember? and @currentPerson? and other.id() is @currentPerson.id())
            if permitted then fn()
            else
              unless @currentPerson?
                @redirectToLogin()
              else
                # TODO flash "Oops! You don't have permissions to see that. Try logging in as somebody else."
                @logout =>
                  @redirectToLogin()}
        try
          __bind(fn, ctx)()
        catch e
          e.action = e.url = req.url
          Hoptoad.notify e
          next e
get = request 'get'
post = request 'post'
put = request 'put'
del = request 'del'

get /.*/, ->
  [host, path] = [@req.header('host'), @req.url]
  if host == 'www.nodeknockout.com' or host == 'nodeknockout.heroku.com'
    @redirect "http://nodeknockout.com#{path}", 301
  else
    @next()

get '/', ->
  @render 'index.html.haml'

get '/me', ->
  if @currentPerson?
    @redirect "/people/#{@currentPerson.toParam()}/edit"
  else
    @redirectToLogin()

get '/*.js', ->
  try
    @render "#{@req.params[0]}.js.coffee", { layout: false }
  catch e
    @next()

get '/register', ->
  if @currentPerson?
    @redirectToTeam @currentPerson, '/'
  else
    @redirect "/login?return_to=#{@req.url}"

get '/error', ->
  throw new Error('Foo')

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    [@teams, @unverifiedTeams] = [[], []]
    for team in teams
      if team.members.length == team.invited.length
        @unverifiedTeams.push team
      else
        @teams.push team
    @yourTeams = if @currentPerson?
      _.select teams, (team) =>
        # TODO this is gross
        _ids = _.pluck(team.members, '_id')
        _.include _.pluck(_ids, 'id'), @currentPerson._id.id
    else []
    @render 'teams/index.html.haml'

get '/teams/attending', ->
  Team.all (error, teams) =>
    @joyentTotal = Team.joyentTotal teams
    @teams = _.select teams, (team) ->
      parseInt(team.joyent_count) > 0
    @render 'teams/index.html.haml'

# new team
get '/teams/new', ->
  unless @currentPerson? and @currentPerson.admin()
    @redirect '/'
  else
    Team.all (error, teams) =>
      @joyentTotal = Team.joyentTotal teams
      @team = new Team {}, =>
        @render 'teams/new.html.haml'

# create team
post '/teams', ->
  unless @currentPerson? and @currentPerson.admin()
    @redirect '/'
  else
    @req.body.joyent_count = parseInt(@req.body.joyent_count) || 0
    @team = new Team @req.body, =>
      @team.save (errors, res) =>
        if errors?
          @errors = errors
          @render 'teams/new.html.haml'
        else
          @cookie 'teamAuthKey', @team.authKey()
          @redirect '/teams/' + @team.toParam()

# show team
get '/teams/:id', ->
  Team.fromParam @req.param('id'), (error, team) =>
    if team?
      Team.all (error, teams) =>
        @joyentTotal = Team.joyentTotal teams
        @team = team
        people = team.members or []
        @members = _.select people, (person) -> person.name
        @invites = _.without people, @members...
        @editAllowed = @canEditTeam team
        @render 'teams/show.html.haml'
    else
      # TODO make this a 404
      @redirect '/'

# edit team
get '/teams/:id/edit', ->
  Team.fromParam @req.param('id'), (error, team) =>
    Team.all (error, teams) =>
      @ensurePermitted team, =>
        @joyentTotal = Team.joyentTotal teams
        @team = team
        @render 'teams/edit.html.haml'

# update team
put '/teams/:id', ->
  Team.fromParam @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.joyent_count ||= 0
      @req.body.joyent_count = parseInt(@req.body.joyent_count) || 0
      team.update @req.body
      save = =>
        team.save (errors, result) =>
          if errors?
            @errors = errors
            @team = team
            if @req.xhr
              @res.send 'ERROR', 500
            else
              @render 'teams/edit.html.haml'
          else
            if @req.xhr
              @res.send 'OK', 200
            else
              @redirect '/teams/' + team.toParam()
      # TODO shouldn't need this
      if @req.body.emails
        team.setMembers @req.body.emails, save
      else save()

# delete team
del '/teams/:id', ->
  Team.fromParam @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.remove (error, result) =>
        @redirect '/'

# resend invitation
get '/teams/:teamId/invite/:personId', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    @ensurePermitted team, =>
      Person.fromParam @req.param('personId'), (error, person) =>
        person.inviteTo team, =>
          if @req.xhr
            @res.send 'OK', 200
          else
            # TODO flash "Sent a new invitation to $@person.email"
            @redirect '/teams/' + team.toParam()

# new vote
get '/votes/new', ->
  # @vote = new Vote()
  @render 'votes/new.html.jade', { layout: 'layout.haml' }

# create vote
post '/votes', ->
  @vote = new Vote @req.body
  @vote.save (errors, res) =>
    if errors?
      @errors = errors
      @render 'votes/new.html.haml'
    else
      @redirect '/votes.json'

Serializer = require('./models/mongo').Serializer
get '/votes.json', ->
  Vote.all {}, {sort: [['modifiedAt', 1]]}, (error, votes) =>
    @res.send JSON.stringify Serializer.pack(votes)

# sign in
get '/login', ->
  @person = new Person()
  @render 'login.html.haml'

post '/login', ->
  Person.login @req.body, (error, person) =>
    if person?
      if @req.param 'remember'
        d = new Date()
        d.setTime(d.getTime() + 1000 * 60 * 60 * 24 * 180)
        options = { expires: d }
      @setCurrentPerson person, options
      if person.name
        if returnTo = @req.param('return_to')
          @redirect returnTo
        else @redirectToTeam person
      else
        @redirect '/people/' + person.toParam() + '/edit'
    else
      @errors = error
      @person = new Person(@req.body)
      @render 'login.html.haml'

get '/logout', ->
  @redirect '/' unless @currentPerson?
  @logout =>
    @redirect '/'

# reset password
post '/reset_password', ->
  Person.first { email: @req.param('email') }, (error, person) =>
    # TODO assumes xhr
    unless person?
      @res.send 'Email not found', 404
    else
      person.resetPassword =>
        @res.send 'OK', 200

# new judge
get '/judges/new', ->
  @person = new Person({ type: 'Judge' })
  @ensurePermitted @person, =>
    @render 'judges/new.html.haml'

get '/judges|/judging', ->
  Person.all { type: 'Judge' }, {sort: [['name', 1]]}, (error, judges) =>
    @judges = judges
    @render 'judges/index.html.jade', { layout: 'layout.haml' }

# create person
post '/people', ->
  @person = new Person @req.body
  @ensurePermitted @person, =>
    @person.save (error, res) =>
      # TODO send confirmation email
      @redirect '/people/' + @person.toParam() + '/edit'

# edit person
get '/people/:id/edit', ->
  Person.fromParam @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      @person = person
      @render 'people/edit.html.haml'

# update person
put '/people/:id', ->
  Person.fromParam @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      attributes = @req.body

      # TODO this shouldn't be necessary
      person.setPassword attributes.password if attributes.password
      delete attributes.password

      attributes.link = '' unless /^https?:\/\/.+\./.test attributes.link

      if attributes.email? && attributes.email != person.email
        person.confirmed = attributes.confimed = false

      person.github ||= ''
      person.update attributes
      person.save (error, resp) =>
        @redirectToTeam person

get '/*', ->
  try
    @render "#{@req.params[0]}.html.haml"
  catch e
    throw e if e.errno != 2
    @next()

markdown = require 'markdown'
app.helpers {
  pluralize: (n, str) ->
    if n == 1
      n + ' ' + str
    else
      n + ' ' + str + 's'

  markdown: (s) ->
    markdown.toHTML s
}

# has to be last
app.use '/', express.errorHandler({ dumpExceptions: true, showStack: true })

server = app.listen parseInt(process.env.PORT || 8000), null
