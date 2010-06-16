Mongo: require('./mongo').Mongo
http: require 'express/http'
sys: require 'sys'
require '../public/javascripts/Math.uuid'

nko: {}

class Team
  constructor: (options, fn) ->
    @name: options?.name or ''
    @token: Math.uuid()
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
    unless @members?.length
      ['Team needs at least one member']
    else
      _.compress _.flatten [member.validate() for member in @members]

  beforeSave: (fn) ->
    threads: @members.length
    return fn() unless threads
    for member in @members
      member.save (error, res) ->
        fn() if --threads is 0

  beforeInstantiate: (fn) ->
    query: { _id: { $in: _.pluck @members, '_id' }}
    Person.all query, (error, members) =>
      @members: members
      fn()

  setMembers: (emails, fn) ->
    emails: _.compact emails or []
    @members: or []
    oldEmails: @emails()

    keepEmails: _.intersect emails, oldEmails
    @members: _.select @members, (m) ->
      _.include keepEmails, m.email

    newEmails: _.without emails, oldEmails...
    threads: newEmails.length
    return setTimeout fn, 0 unless threads

    for email in newEmails
      Person.firstOrCreate { email: email }, (error, member) =>
        @members.push member
        member.inviteTo this, ->
          fn() if --threads is 0
nko.Team: Team

class Person
  constructor: (options) ->
    @name: options?.name or ''
    @email: options?.email or ''
    @link: options?.link or ''
    @password: options?.password or @randomPassword()

  inviteTo: (team, fn) ->
    message: """
      Hi,

      You've been invited to the $team.name Node.js Knockout team!

      Here are your credentials:
      email: $@email
      password: $@password

      Please sign in to http://nodeknockout.com/login to complete your registration.

      Thanks!
      The Node.js Knockout Organizers
      """
    http.post 'http://www.postalgone.com/mail', {
      # sender: '"Node.js Knockout" <all@nodeknockout.com>',
      from: 'all@nodeknockout.com',
      to: @email,
      subject: "You've been invited to Node.js Knockout",
      body: message }, (error, body, response) ->
        fn()

  authKey: ->
    @id() + ':' + @token

  logout: (fn) ->
    @token: null
    @save fn

  # http://e-huned.com/2008/10/13/random-pronounceable-strings-in-ruby/
  randomPassword: ->
    alphabet: 'abcdefghijklmnopqrstuvwxyz'.split('')
    vowels: 'aeiou'.split('')
    consonants: _.without alphabet, vowels...
    syllables: for i in [0..2]
      consonants[Math.floor consonants.length * Math.random()] +
      vowels[Math.floor vowels.length * Math.random()] +
      alphabet[Math.floor alphabet.length * Math.random()]
    syllables.join ''

_.extend Person, {
  login: (credentials, fn) ->
    @first { email: credentials.email }, (error, person) ->
      return fn ['Unknown email'] unless person?
      return fn ['Invalid password'] unless person.password is credentials.password
      person.token: Math.uuid()
      person.save (errors, resp) ->
        fn null, person

  firstByAuthKey: (authKey, fn) ->
    [id, token]: authKey.split ':' if authKey?
    return fn null, null unless id and token

    query: Mongo.queryify id
    query.token: token
    @first query, fn
}

nko.Person: Person

Mongo.blessAll nko

_.extend exports, nko