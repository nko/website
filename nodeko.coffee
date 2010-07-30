sys = require 'sys'
connect = require 'connect'
express = require 'express'

models = require './models/models'
[Team, Person] = [models.Team, models.Person]

pub = __dirname + '/public';
app = express.createServer(
  connect.compiler({ src: pub, enable: ['sass'] }),
  connect.staticProvider(pub)
)

app.use connect.logger()
app.use connect.bodyDecoder()
app.use connect.methodOverride()
app.use connect.cookieDecoder()

app.enable 'show exceptions'

request = (type) ->
  (path, fn) ->
    app[type] path, (req, res, next) =>
      Person.firstByAuthKey req.cookies.authkey, (error, person) =>

        sys.puts "------\nreq:\n#{sys.inspect req}\n"
        sys.puts "------\nreq.body:\n#{sys.inspect req.body}\n"
        sys.puts "------\nres:\n#{sys.inspect res}\n"
        sys.puts "------\nnext:\n#{sys.inspect next}\n"
        sys.puts "------\nreq.cookies:\n#{sys.inspect req.cookies}\n"
        sys.puts "------\nauthkey:\n#{sys.inspect req.cookies.authkey}\n"
        sys.puts "------\nperson:\n#{sys.inspect person}\n"

        ctx = {
          sys: sys
          req: req
          res: res
          next: next
          redirect: __bind(res.redirect, res),
          cookie: (key, value) ->
            res.header('Set-Cookie', "#{key}=#{value}")
          render: (file, opts) ->
            opts ||= {}
            opts.locals ||= {}
            opts.locals.view = file.replace(/\..*$/,'').replace(/\//,'-')
            opts.locals.ctx = ctx
            res.render file, opts
          currentPerson: person
          setCurrentPerson: (person, options) ->
            @cookie 'authkey', person?.authKey(), options
          redirectToTeam: (person, alternatePath) ->
            Team.first { 'members._id': person._id }, (error, team) =>
              if team?
                @redirect '/teams/' + team.id()
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
              team.hasMember(@currentPerson)
          ensurePermitted: (other, fn) ->
            permitted = if other.hasMember?
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
                  @redirectToLogin()}
        __bind(fn, ctx)()
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
  Team.all (error, teams) =>
    @spotsLeft = 222 - teams.length
    @render 'index.html.haml'

get '/*.js', ->
  try
    @render "#{@req.params[0]}.js.coffee", { layout: false }
  catch e
    @next()

get '/register', ->
  if @currentPerson?
    @redirectToTeam @currentPerson, '/teams/new'
  else
    @redirect '/teams/new'

# list teams
get '/teams', ->
  Team.all (error, teams) =>
    @teams = teams
    @yourTeams = if @currentPerson?
      _.select teams, (team) =>
        # TODO this is gross
        _ids = _.pluck(team.members, '_id')
        _.include _.pluck(_ids, 'id'), @currentPerson._id.id
    else []
    @render 'teams/index.html.haml'

# new team
get '/teams/new', ->
  Team.all (error, teams) =>
    if teams.length >= 222
      @redirect '/'
    else
      @team = new Team {}, =>
        @render 'teams/new.html.haml'

# create team
post '/teams', ->
  @team = new Team @req.body, =>
    @team.save (errors, res) =>
      if errors?
        @errors = errors
        @render 'teams/new.html.haml'
      else
        @cookie 'teamauthkey', @team.authKey()
        @redirect '/teams/' + @team.id()

# show team
get '/teams/:id', ->
  Team.first @req.param('id'), (error, team) =>
    if team?
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
  Team.first @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      @team = team
      @render 'teams/edit.html.haml'

# update team
put '/teams/:id', ->
  Team.first @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.joyent_count ||= 0
      team.update @req.body
      save = =>
        team.save (errors, result) =>
          if errors?
            @errors = errors
            @team = team
            @render 'teams/edit.html.haml'
          else
            @redirect '/teams/' + team.id()
      # TODO shouldn't need this
      if @req.body.emails
        team.setMembers @req.body.emails, save
      else save()

# delete team
del '/teams/:id', ->
  Team.first @req.param('id'), (error, team) =>
    @ensurePermitted team, =>
      team.remove (error, result) =>
        @redirect '/'

# resend invitation
get '/teams/:teamId/invite/:personId', ->
  Team.first @req.param('teamId'), (error, team) =>
    @ensurePermitted team, =>
      Person.first @req.param('personId'), (error, person) =>
        person.inviteTo team, =>
          if @req.xhr
            @res.send 'OK', 200
          else
            # TODO flash "Sent a new invitation to $@person.email"
            @redirect '/teams/' + team.id()

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
        @redirect '/people/' + person.id() + '/edit'
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

# edit person
get '/people/:id/edit', ->
  Person.first @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      @person = person
      @render 'people/edit.html.haml'

# update person
put '/people/:id', ->
  Person.first @req.param('id'), (error, person) =>
    @ensurePermitted person, =>
      attributes = @req.body

      # TODO this shouldn't be necessary
      person.setPassword attributes.password if attributes.password
      delete attributes.password

      attributes.link = '' unless /^https?:\/\/.+\./.test attributes.link
      person.update attributes
      person.save (error, resp) =>
        @redirectToTeam person

# get '/*', (file) ->
#   try
#     @render "${file}.html.haml"
#   catch e
#     throw e if e.errno != 2
#     @next()

# # # 
# # # get '/*', (file) ->
# # #   @pass "/public/${file}"
# # # 
# # # # app.configure ->
# # # #   CurrentPerson: Plugin.extend {
# # # #     extend: {
# # # #       init: ->
# # # #         Request.include {
# # # #           setCurrentPerson: (person, options) ->
# # # #             @cookie 'authKey', person?.authKey(), options
# # # #           getCurrentPerson: (fn) ->
# # # #             Person.firstByAuthKey @cookie('authKey'), fn
# # # #         }
# # # #     }
# # # # 
# # # #     'on': {
# # # #       request: (event, fn) ->
# # # #         event.request.getCurrentPerson (error, person) ->
# # # #           event.request.currentPerson: person
# # # #           fn()
# # # #         true # wait for async completion
# # # #     }
# # # #   }
# # # #   use CurrentPerson
# # # # 
# # # # Request.include {
# # # #   redirectToTeam: (person, alternatePath) ->
# # # #     Team.first { 'members._id': person._id }, (error, team) =>
# # # #       if team?
# # # #         @redirect '/teams/' + team.id()
# # # #       else
# # # #         @redirect (alternatePath or '/')
# # # # 
# # # #   redirectToLogin: ->
# # # #     @redirect "/login?return_to=$@url.href"
# # # # 
# # # #   logout: (fn) ->
# # # #     @currentPerson.logout (error, resp) =>
# # # #       @setCurrentPerson null
# # # #       fn()
# # # # 
# # # #   ensurePermitted: (other, fn) ->
# # # #     permitted: if other.hasMember?
# # # #       @canEditTeam other
# # # #     else
# # # #       @currentPerson? and (other.id() is @currentPerson.id())
# # # #     if permitted then fn()
# # # #     else
# # # #       unless @currentPerson?
# # # #         @redirectToLogin()
# # # #       else
# # # #         # TODO flash "Oops! You don't have permissions to see that. Try logging in as somebody else."
# # # #         @logout =>
# # # #           @redirectToLogin()
# # # # 
# # # #   canEditTeam: (team) ->
# # # #     @cookie('teamAuthKey') is team.authKey() or
# # # #       team.hasMember(@currentPerson)
# # # # }
# # # 

get '/*', ->
  @render "#{@req.params[0]}.html.haml"

server = app.listen parseInt(process.env.PORT || 8000), null
