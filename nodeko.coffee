# this entire application is pretty gross, by our own judgement. we'd love to
# clean it up, but we'd probably just rewrite the whole thing anyway. you have
# been warned.

sys = require 'sys'
connect = require 'connect'
express = require 'express'

models = require './models/models'
[Team, Person, Vote, ScoreCalculator] = [models.Team, models.Person, models.Vote, models.ScoreCalculator]

pub = __dirname + '/public'
app = express.createServer(
  connect.compiler({ src: pub, enable: ['sass', 'coffee'] }),
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
          isAdmin: person? && person.admin()
          isJudge: person? && person.type is 'Judge'
          setCurrentPerson: (person, options) ->
            @cookie 'authKey', person?.authKey(), options
          redirectToTeam: (person, alternate) ->
            Team.first { 'members._id': person._id }, (error, team) =>
              if team?
                @redirect '/teams/' + team.toParam()
              else if alternate
                alternate()
              else
                @redirect '/'
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
              team.hasMember(@currentPerson) or @isAdmin
          ensurePermitted: (other, fn) ->
            permitted = @isAdmin
            if other.hasMember?
              permitted ||= @canEditTeam(other)
            else if other.person?
              permitted ||= (@currentPerson? and other.person.id() is @currentPerson.id())
            else
              permitted ||= (@currentPerson? and other.id() is @currentPerson.id())
            if permitted then fn()
            else @redirectToLogin()}
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
  Team.count (error, teamCount) =>
    @teamCount = teamCount
    Team.all { validDeploy: true }, { deep: false }, (error, teams) =>
      @teams = _.shuffle(teams).slice(0, 10)
      @entryCount = teams.length
      @render 'index.html.haml'

get '/me', ->
  if @currentPerson?
    @redirect "/people/#{@currentPerson.toParam()}/edit"
  else
    @redirectToLogin()

get '/team', ->
  if @currentPerson?
    @redirectToTeam @currentPerson, __bind(@redirectToLogin, this)
  else
    @redirectToLogin()

get '/register', ->
  if @currentPerson?
    @redirectToTeam @currentPerson
  else
    @redirect "/login?return_to=#{@req.url}"

get '/error', ->
  throw new Error('Foo')

get '/scores', ->
  Team.all { validDeploy: true }, { deep: false }, (error, teams) =>
    @teams = teams
    @teams.sort (a, b) -> (b?.score?.overall || 0) - (a?.score?.overall || 0)
    @render 'scores.html.haml'

post '/scores/refresh', ->
  ScoreCalculator.calculate (scores) =>
    res = @res
    team_ids = k for k, v of scores
    save = (error, saved) ->
      return res.send error.join("\n"), 500 if error?
      if team_id = team_ids.pop()
        Team.updateAll team_id, { $set: { score: scores[team_id] }}, save
      else
        res.send 'OK', 200
    save()

# list teams
get '/teams', ->
  q = if @req.param('invalid') then { url: /\w/, validDeploy: false } else { validDeploy: true }
  Team.all q, { deep: false }, (error, teams) =>
    @teams = _.shuffle teams
    @render 'teams/index.html.haml'

# new team
get '/teams/new', ->
  return @redirect '/' unless @isAdmin

  @team = new Team {}, =>
    @render 'teams/new.html.haml'

# create team
post '/teams', ->
  return @redirect '/' unless @isAdmin

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
  @requestAt = Date.now()
  Team.fromParam @req.param('id'), (error, team) =>
    if team?
      @team = team
      @title = @team.name
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
          @vote = vote or new Vote(null, @req)
          @vote.person = @currentPerson
          @vote.email = @vote.person.email
          renderVotes()
      else
        @vote = new Vote(null, @req)
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
      delete @req.body.score
      team.update @req.body
      team.validDeploy = @req.body.validDeploy == '1'
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

saveVote = ->
  @vote.save (errors, res) =>
    if errors?
      if errors[0] is 'Unauthorized'
        # TODO flash "You must login to vote as #{@vote.email}."
        @res.send 'Unauthorized', 403
      else
        @res.send JSON.stringify(errors), 400
    else
      # TODO flash "You are now logged into Node Knockout as #{@vote.email}."
      @setCurrentPerson @vote.person if @vote.person? and !@currentPerson?
      @votes = [@vote]
      @render 'partials/votes/index.html.jade', { layout: false }

# create vote
post '/teams/:teamId/votes', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    # TODO: handle error
    @vote = new Vote @req.body, @req
    @vote.team = @team = team
    @vote.person = @currentPerson
    @vote.email ?= @vote.person?.email
    @vote.responseAt = Date.now()
    saveVote.call(this)

put '/teams/:teamId/votes/:voteId', ->
  Team.fromParam @req.param('teamId'), (error, team) =>
    Vote.fromParam @req.param('voteId'), (error, vote) =>
      @ensurePermitted vote, =>
        @noHeader = true
        @vote = vote
        vote.update @req.body
        saveVote.call(this)

# list votes
get '/teams/:teamId/votes', ->
  @redirect '/teams/' + @req.param('teamId')

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
        else @redirect '/people/' + person.toParam()
      else
        @redirect '/people/' + person.toParam() + '/edit'
    else
      @errors = error
      @person = new Person(@req.body)
      @render 'login.html.haml'

get '/logout', ->
  @logout => @redirect(@req.param('return_to') || @req.headers.referer || '/')

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
      @redirect '/people/' + @person.toParam()

# edit person
get '/people/:id/edit', ->
  Person.fromParam @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      @person = person
      @render 'people/edit.html.haml'

# show person
get '/people/:id', ->
  Person.fromParam @req.param('id'), (error, person) =>
    @person = person
    @isCurrentPerson = @person.id() is @currentPerson?.id()
    @person.loadTeams =>
      @person.loadVotes =>
        @showTeam = true
        @votes = @person.votes
        @render 'people/show.html.haml'

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
        @redirect '/people/' + person.toParam()

# delete person
del '/people/:id', ->
  Person.fromParam @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      person.remove (error, result) =>
        @redirect '/'

# TODO security
post '/deploys', ->
  # user: 'visnupx@gmail.com'
  # head: '87eaeb6'
  # app: 'visnup-nko'
  # url: 'http://visnup-nko.heroku.com'
  # git_log: ''
  # prev_head: ''
  # head_long: '87eaeb69d726593de6a47a5f38ff6126fd3920fa'
  query = {}
  deployedTo = if /\.no\.de$/.test(@req.param('url')) then 'joyent' else 'heroku'
  query[deployedTo + 'Slug'] = @req.param('app')
  Team.first query, (error, team) =>
    if team
      team.url = @req.param('url')
      team.lastDeployedTo = deployedTo
      team.lastDeployedAt = new Date()
      team.lastDeployedHead = @req.param('head')
      team.lastDeployedHeadLong = @req.param('head_long')
      team.deployHeads.push team.lastDeployedHeadLong
      team.save(->)
  @render 'deploys/ok.html.haml', { layout: false }

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

  firstParagraph: (md) ->
    markdown = require 'markdown'
    tree = markdown.parse md
    p = _.detect tree, (e) -> e[0] == 'para'
    if p then markdown.toHTML p else ''

  gravatar: (p, s) ->
    return '' unless p?
    if p.type is 'Judge'
      "<img src=\"/images/judges/#{p.name.replace(/\W+/g, '_')}.jpg\" width=#{s || 40} />"
    else
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
