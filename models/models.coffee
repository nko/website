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

class Team
  constructor: (options, fn) ->
    @joyent_count = options?.joyent_count or 0
    @name = options?.name or ''
    @token = Math.uuid()
    @createdAt = new Date()
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
    return setTimeout fn, 0 unless threads

    for email in newEmails
      Person.firstOrCreate { email: email }, (error, member) =>
        @members.push member
        member.inviteTo this, ->
          fn() if --threads is 0

  generateSlug: (fn, attempt) ->
    @slug = attempt || @name.toLowerCase().replace(/\W+/g, '-')
    Team.fromParam @slug, (error, existing) =>
      if !existing? or existing.id() == @id()
        fn()  # no conflicts
      else
        @generateSlug fn, @slug + '-'  # try with another -

_.extend Team, {
  joyentTotal: (teams) ->
    _.reduce _.pluck(teams, 'joyent_count'), 0, (memo, num) ->
      memo + (parseInt(num) || 0)
}

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

    @calculateHashes()

  admin: ->
    @confirmed and /\@nodeknockout\.com$/.test(@email)

  resetPassword: (fn) ->
    @password = @randomPassword()
    @new_password = true
    @calculateHashes()
    @save (error, res) =>
      # TODO get this into a view
      message = """
        Hi,

        You (or somebody like you) reset the password for this email address.

        Here are your new credentials:
        email: #{@email}
        password: #{@password}

        Thanks!
        The Node.js Knockout Organizers
        """
      http.post 'http://www.postalgone.com/mail',
        { sender: '"Node.js Knockout" <mail@nodeknockout.com>',
        from: 'all@nodeknockout.com',
        to: @email,
        subject: "Password reset for Node.js Knockout",
        body: message }, (error, body, response) ->
          fn()

  inviteTo: (team, fn) ->
    # TODO get this into a view
    message = """
      Hi,

      You've been invited to the #{team.name} Node.js Knockout team!

      Here are your credentials:
      email: #{@email}
      #{if @password then 'password: ' + @password else 'and whatever password you already set'}

      You still need to complete your registration.
      Please sign in at: http://nodeknockout.com/login?email=#{@email}&password=#{@password} to do so.


      Thanks!
      The Node.js Knockout Organizers

      Node.js Knockout is a 48-hour programming contest using node.js from Aug 28-29, 2010.
      """
    http.post 'http://www.postalgone.com/mail',
      { sender: '"Node.js Knockout" <mail@nodeknockout.com>',
      from: 'all@nodeknockout.com',
      to: @email,
      subject: "You've been invited to Node.js Knockout",
      body: message }, (error, body, response) ->
        fn()

  authKey: ->
    @id() + ':' + @token

  logout: (fn) ->
    @token = null
    @save fn

  validate: ->
    ['Invalid email address'] unless /^[a-zA-Z0-9+._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test @email

  beforeSave: (fn) ->
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
    @first { email: /^#{credentials.email}$/i }, (error, person) ->
      return fn ['Unknown email'] unless person?
      return fn ['Invalid password'] unless person.passwordHash is md5 credentials.password
      person.token = Math.uuid()

      person.confirmed ?= true # grandfather old people in
      person.confirmed = true if person.new_password
      person.new_password = false

      person.save (errors, resp) ->
        fn null, person

  firstByAuthKey: (authKey, fn) ->
    [id, token] = authKey.split ':' if authKey?
    return fn null, null unless id and token

    query = Mongo.queryify id
    query.token = token
    @first query, fn
}

nko.Person = Person

Mongo.blessAll nko

Team.prototype.toParam = -> @slug

Team.fromParam = (id, options, fn) ->
  @first { slug: id }, options, fn

_.extend exports, nko
