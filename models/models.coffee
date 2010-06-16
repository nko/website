Mongo: require('./mongo').Mongo
sys: require 'sys'
require '../public/javascripts/Math.uuid'

nko: {}

class Team
  constructor: (options, fn) ->
    @name: options?.name
    @setMembers _.compact(options?.members or []), fn

  validate: ->
    unless @members?.length
      ['Team needs at least one member']
    else
      _.compress _.flatten [member.validate() for member in @members]

  beforeSave: (fn) ->
    threads: @members.length
    for member in @members
      member.save (error, res) ->
        fn() if --threads is 0

  beforeInstantiate: (fn) ->
    query: { _id: { $in: _.pluck @members, '_id' }}
    Person.all query, (error, members) =>
      @members: members
      fn()

  setMembers: (emails, fn) ->
    return fn() unless emails?.length
    @members: []
    threads: emails.length
    for email in emails
      Person.firstOrCreate { email: email }, (error, member) =>
        @members.push member
        fn() if --threads is 0
nko.Team: Team

class Person
  constructor: (options) ->
    @name: options?.name or ''
    @email: options?.email or ''
    @link: options?.link or ''
    @password: options?.password or @randomPassword()

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
    syllables: for i in [0..3]
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