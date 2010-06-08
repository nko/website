Mongo: require('./mongo').Mongo

class Team
  serialize: 'Team'

  constructor: (options) ->
    @name: options?.name
exports.Team: Mongo.bless Team

# class Person extends MongoModel
#   type: 'Person'
# 
#   constructor: (options) ->
#     @email: options?.email
#     @password: options?.password
#     @team: options?.team