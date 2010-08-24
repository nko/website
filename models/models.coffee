Mongo = require('./mongo').Mongo
http = require('./http')
sys = require 'sys'
crypto = require 'crypto'
require '../public/javascripts/Math.uuid'
nko = {}

md5 = (str) ->
  hash = crypto.createHash 'md5'
  hash.update str
  hash.digest 'hex'

validEmail = (email) ->
  /^[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test email

escapeURL = require('querystring').escape

class Team
  build: (options) ->
    @name = options?.name or ''
    @createdAt = new Date()
    @application = options?.application or ''
    @description = options?.description or ''
    @colophon = options?.colophon or ''
    @link = options?.link or ''

  constructor: (options, fn) ->
    @build options
    @token = Math.uuid()
    @setMembers options?.emails, fn

  # TODO DRY
  authKey: ->
    @id() + ':' + @token

  hasMember: (member) ->
    return false unless member?
    _.include _.invoke(@members, 'id'), member.id()

  emails: ->
    _.pluck @members, 'email'

  validate: ->
    errors = []
    errors.push 'Must have team name' unless @name
    errors.push 'Team needs at least one member' unless @members?.length
    errors.concat _.compact _.flatten [member.validate() for member in @members]

  beforeSave: (fn) ->
    @generateSlug =>
      threads = @members.length
      return fn() unless threads
      for member in @members
        member.save (error, res) ->
          fn() if --threads is 0

  beforeInstantiate: (fn) ->
    query = { _id: { $in: _.pluck @members, '_id' }}
    Person.all query, (error, members) =>
      @members = members
      @invited = _.select @members, (m) -> m.name == ''
      fn()

  setMembers: (emails, fn) ->
    emails = _.compact emails or []
    @members = or []
    oldEmails = @emails()

    keepEmails = _.intersect emails, oldEmails
    @members = _.select @members, (m) ->
      _.include keepEmails, m.email

    newEmails = _.without emails, oldEmails...
    threads = newEmails.length
    return process.nextTick fn unless threads

    for email in newEmails
      Person.firstOrNew { email: email }, (error, member) =>
        @members.push member
        member.type = 'Participant'
        member.inviteTo this, ->
          fn() if --threads is 0

  generateSlug: (fn, attempt) ->
    @slug = attempt || @name.toLowerCase().replace(/\W+/g, '-')
    Team.fromParam @slug, (error, existing) =>
      if !existing? or existing.id() == @id()
        fn()  # no conflicts
      else
        @generateSlug fn, @slug + '-'  # try with another -

nko.Team = Team

class Person
  constructor: (options) ->
    @name = options?.name or ''
    @email = options?.email or ''

    @link = options?.link or ''
    @github = options?.github or ''
    @heroku = options?.heroku or ''
    @joyent = options?.joyent or ''

    @password = options?.password or @randomPassword()
    @new_password = !options?.password?
    @confirmed = options?.confirmed or false

    @type = options?.type # 'Judge', 'Voter', 'Participant'

    @description = options?.description or ''
    @signature = options?.signature or ''

    @token = Math.uuid()
    @calculateHashes()

  admin: ->
    @confirmed and /\@nodeknockout\.com$/.test(@email)

  displayName: ->
    @name or @email.replace(/\@.*$/,'')

  resetPassword: (fn) ->
    @password = @randomPassword()
    @new_password = true
    @calculateHashes()
    @save (error, res) =>
      # TODO get this into a view
      @sendEmail "Password reset for Node.js Knockout", """
        Hi,

        You (or somebody like you) reset the password for this email address.

        Here are your new credentials:
        email: #{@email}
        password: #{@password}

        Thanks!
        The Node.js Knockout Organizers
        """, fn

  inviteTo: (team, fn) ->
    @sendEmail "You've been invited to Node.js Knockout", """
      Hi,

      You've been invited to the #{team.name} Node.js Knockout team!

      Here are your credentials:
      email: #{@email}
      #{if @password then 'password: ' + @password else 'and whatever password you already set'}

      You still need to complete your registration.
      Please sign in at: http://nodeknockout.com/login?email=#{escapeURL @email}&password=#{@password} to do so.


      Thanks!
      The Node.js Knockout Organizers

      Node.js Knockout is a 48-hour programming contest using node.js from Aug 28-29, 2010.
      """, fn

  welcomeVoter: (fn) ->
    # TODO get this into a view
    @sendEmail "Thanks for voting in Node.js Knockout", """
      Hi,

      You (or somebody like you) used this email address to vote in Node.js Knockout, so we created an account for you.

      Here are your credentials:
      email: #{@email}
      password: #{@password}

      Please sign in to confirm your votes: http://nodeknockout.com/login?email=#{escapeURL @email}&password=#{@password}

      Thanks!
      The Node.js Knockout Organizers
      http://nodeknockout.com/
      """, fn

  sendEmail: (subject, message, fn) ->
    http.post 'http://www.postalgone.com/mail',
      { sender: '"Node.js Knockout" <mail@nodeknockout.com>',
      from: 'all@nodeknockout.com',
      to: @email,
      subject: subject,
      body: message }, (error, body, response) ->
        fn()

  confirmVotes: (fn) ->
    Vote.updateAll { 'person._id': @_id, confirmed: false }, { $set: { confirmed: true }}, fn

  authKey: ->
    @id() + ':' + @token

  logout: (fn) ->
    @token = null
    @save fn

  validate: ->
    ['Invalid email address'] unless validEmail @email

  beforeSave: (fn) ->
    @email = @email?.trim()?.toLowerCase()
    @calculateHashes()
    fn()

  setPassword: (password) ->
    # overwrite the default password
    @passwordHash = md5 password
    @password = ''

  calculateHashes: ->
    @emailHash = md5 @email
    @passwordHash = md5 @password if @password

  # http://e-huned.com/2008/10/13/random-pronounceable-strings-in-ruby/
  randomPassword: ->
    alphabet = 'abcdefghijklmnopqrstuvwxyz'.split('')
    vowels = 'aeiou'.split('')
    consonants = _.without alphabet, vowels...
    syllables = for i in [0..2]
      consonants[Math.floor consonants.length * Math.random()] +
      vowels[Math.floor vowels.length * Math.random()] +
      alphabet[Math.floor alphabet.length * Math.random()]
    syllables.join ''

_.extend Person, {
  login: (credentials, fn) ->
    return fn ['Invalid email address'] unless validEmail credentials.email
    @first { email: credentials.email.trim().toLowerCase() }, (error, person) ->
      return fn ['Unknown email'] unless person?
      return fn ['Invalid password'] unless person.passwordHash is md5 credentials.password
      person.token = Math.uuid()

      person.confirmed ?= true # grandfather old people in
      if person.new_password
        confirm_votes = true
        person.confirmed = true
        person.new_password = false

      person.save (errors, resp) ->
        if confirm_votes
          # TODO flash "your votes have been confirmed"
          person.confirmVotes (errors) ->
            fn errors, person
        else
          fn null, person

  firstByAuthKey: (authKey, fn) ->
    [id, token] = authKey.split ':' if authKey?
    return fn null, null unless id and token

    query = Mongo.queryify id
    query.token = token
    @first query, fn
}

nko.Person = Person

class Vote
  constructor: (options, request) ->
    @team = options?.team

    @usefulness = parseInt options?.usefulness
    @design = parseInt options?.design
    @innovation = parseInt options?.innovation
    @completeness = parseInt options?.completeness

    @comment = options?.comment
    @email = options?.email?.trim()?.toLowerCase()
    @person = options?.person
    @confirmed = !! options?.person?.confirmed

    @remoteAddress = request?.socket?.remoteAddress
    @remotePort = request?.socket?.remotePort
    @userAgent = request?.headers?['user-agent']
    @referer = request?.headers?['referer']
    #@accept = request?.headers?['accept']

    @requestAt = options?.requestAt
    @renderAt = options?.renderAt
    @responseAt = options?.responseAt

    @createdAt = @updatedAt = new Date()

  beforeSave: (fn) ->
    if !@person?
      Person.firstOrNew { email: @email }, (error, voter) =>
        return fn ['Unauthorized'] unless voter.isNew()
        @person = voter
        @person.type = 'Voter'
        @person.save =>
          @person.welcomeVoter fn
    else
      if @isNew()
        @email ?= @person?.email
        @checkDuplicate fn
      else fn()

  checkDuplicate: (fn) ->
    Vote.firstByTeamAndPerson @team, @person, (errors, existing) =>
      return fn errors if errors?.length
      return fn ["Duplicate"] if existing?
      fn()

  beforeInstantiate: (fn) ->
    Person.first @person.id(), (error, voter) =>
      @person = voter
      fn()

  validate: ->
    errors = []
    for dimension in [ 'Usefulness', 'Design', 'Innovation', 'Completeness' ]
      errors.push "#{dimension} should be between 1 and 5 stars" unless 1 <= this[dimension.toLowerCase()] <= 5
    errors

_.extend Vote, {
  firstByTeamAndPerson: (team, person, fn) ->
    Vote.first { 'team._id': team._id, 'person._id': person._id }, fn
}

nko.Vote = Vote

Mongo.blessAll nko
nko.Mongo = Mongo

Team::toParam = -> @slug
Team.fromParam = (id, options, fn) ->
  if id.length == 24
    @first { '$or': [ { slug: id }, Mongo.queryify(id) ] }, options, fn
  else
    @first { slug: id }, options, fn

_.extend exports, nko
