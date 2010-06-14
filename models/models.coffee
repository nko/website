Mongo: require('./mongo').Mongo
sys: require 'sys'

nko: {}

randomPassword: ->
  alphabet: ['a'..'z']
  vowels: 'a e i o u'.split(' ')
  consonants: _.without alphabet, vowels...
  syllables: for i in [0..3]
    consonants[Math.floor consonants.length * Math.random()] +
    vowels[Math.floor vowels.length * Math.random()] +
    alphabet[Math.floor alphabet.length * Math.random()]
  syllables.join ''

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
    query: { email: { $in: _.pluck @members, 'email' }}
    sys.puts sys.inspect query
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
    @email: options?.email
    @password: options?.password
    @team: options?.team?._id
nko.Person: Person

Mongo.blessAll nko

_.extend exports, nko