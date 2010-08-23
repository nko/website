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
            options.path ||= '/'
            cookie = "#{key}=#{value}"
            for k, v of options
              cookie += "; #{k}=#{v}"
            res.header('Set-Cookie', cookie)
          render: (file, opts, fn) ->
            opts ||= {}
            opts.locals ||= {}
            opts.locals.view = file.replace(/\..*$/,'').replace(/\//,'-')
            opts.locals.ctx = ctx
            res.render file, opts, fn
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
            if @currentPerson?
              @currentPerson.logout (error, resp) =>
                @setCurrentPerson null
                fn()
            else fn()
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
    @render "#{@req.params[0]}.js.coffee", { layout: false }, (error, view) =>
      @res.send view, { 'Content-Type': 'text/javascript' }
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
    for team in _.shuffle(teams)
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

# new team
get '/teams/new', ->
  unless @currentPerson? and @currentPerson.admin()
    @redirect '/'
  else
    @team = new Team {}, =>
      @render 'teams/new.html.haml'

# create team
post '/teams', ->
  unless @currentPerson? and @currentPerson.admin()
    @redirect '/'
  else
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
      @team = team
      @editAllowed = @canEditTeam team

      people = team.members or []
      @members = _.select people, (person) -> person.name
      @invites = _.without people, @members...

      renderVotes = =>
        Vote.all { 'team._id': team._id }, { 'sort': [['createdAt', -1]], limit: 50 }, (error, votes) =>
          @votes = votes
          @render 'teams/show.html.haml'

      if @currentPerson
        Vote.firstByTeamAndPerson team, @currentPerson, (error, vote) =>
          @vote = vote or new Vote()
          @vote.person = @currentPerson
          @vote.email = @vote.person.email
          renderVotes()
      else
        @vote = new Vote()
        renderVotes()
    else
      # TODO make this a 404
      @redirect '/'

# edit team
get '/teams/:id/edit', ->
  Team.fromParam @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      @team = team
      @render 'teams/edit.html.haml'

# update team
put '/teams/:id', ->
  Team.fromParam @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
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
get '/teams/:teamId/votes/new', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    # TODO: handle error
    @team = team
    @vote = new Vote
    @email = @currentPerson?.email
    @render 'votes/new.html.jade', { layout: 'layout.haml' }

# create vote
post '/teams/:teamId/votes', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    # TODO: handle error
    @vote = new Vote @req.body, @req
    @vote.team = @team = team
    @vote.person = @currentPerson
    @vote.save (errors, res) =>
      if errors?
        @errors = errors
        @email = @vote.email
        @render 'votes/new.html.jade', { layout: 'layout.haml' }
      else
        # TODO flash "You are now logged into Node Knockout as #{@vote.email}."
        @setCurrentPerson @vote.person if @vote.person? and !@currentPerson?
        @redirect '/teams/' + @team.toParam()

# list votes
get '/teams/:teamId/votes', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    @redirect '/teams/' + team.toParam()

get '/teams/:teamId/votes.js', ->
  skip = 50 * ((@req.query['page'] || 1)-1)
  Team.fromParam @req.param('teamId'), (error, team) =>
    # TODO: handle error
    Vote.all { 'team._id': team._id }, { 'sort': [['createdAt', -1]], skip: skip, limit: 50 }, (error, votes) =>
      @votes = votes
      @render 'partials/votes/index.html.jade', { layout: false }

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
  @logout => @redirect(@req.param('return_to') || '/')

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
  Person.all { type: 'Judge' }, (error, judges) =>
    @judges = _.shuffle judges
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

get '/prizes', ->
  @render 'prizes.html.jade', { layout: 'layout.haml' }

get '/*', ->
  try
    @render "#{@req.params[0]}.html.haml"
  catch e
    throw e if e.errno != 2
    @next()

app.helpers {
  pluralize: (n, str) ->
    if n == 1
      n + ' ' + str
    else
      n + ' ' + str + 's'

  escapeURL: require('querystring').escape
  markdown: require('markdown').toHTML

  gravatar: (p, s) ->
    "<img src=\"http://www.gravatar.com/avatar/#{p.emailHash}?s=#{s || 40}&d=monsterid\" />"
}

_.shuffle = (a) ->
  r = _.clone a
  for i in [r.length-1 .. 0]
    j = parseInt(Math.random() * i)
    [r[i], r[j]] = [r[j], r[i]]
  r

# has to be last
app.use '/', express.errorHandler({ dumpExceptions: true, showStack: true })

server = app.listen parseInt(process.env.PORT || 8000), null
