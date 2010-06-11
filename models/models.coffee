Mongo: require('./mongo').Mongo

class exports.Team
  constructor: (options) ->
    @name: options?.name
    @invites: _.compact(options?.invites or [])

# class Person extends MongoModel
#   type: 'Person'
# 
#   constructor: (options) ->
#     @email: options?.email
#     @password: options?.password
#     @team: options?.team

Mongo.blessAll exports
