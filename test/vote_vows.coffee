require.paths.unshift '../lib/eyes/lib'
require 'eyes'
vows = require '../lib/vows/lib/vows'
assert = require 'assert'
sys = require 'sys'


require '../lib/coffee/lib/coffee'

process.env['MONGOHQ_URL'] = 'http://localhost:27017/nodeknockout_test'
models = require '../models/models'
[Team, Person, Vote] = [models.Team, models.Person, models.Vote]


vows.describe('Vote').addBatch(
  'collections':
    topic: ->  models.Mongo.db.collectionNames @callback
    'dropped': (errors, collectionName) ->
      sys.puts collectionName
).addBatch(
  'empty':
    topic: new(Vote)
    'isNew': (vote) -> assert.equal vote.isNew(), true
    'save':
      topic: (vote) -> vote.save @callback
      'fails': (errors, res) -> assert.ok errors.length

  'full':
    topic: new Vote(
      usefulness: 1
      design: 2
      innovation: 3
      completeness: 4
      email: 'gerads@gmail.com')
    'save':
      topic: (vote) -> vote.save @callback
      'succeeds': (errors, res) -> assert.isNull errors

).addBatch(
  'close mongo': -> assert.isUndefined models.Mongo.db.close()
).run()
  