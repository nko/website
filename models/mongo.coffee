sys: require 'sys'
url: require 'url'
require '../public/javascripts/underscore'
MongoDb: require('../lib/node-mongodb-native/lib/mongodb/db').Db
MongoServer: require('../lib/node-mongodb-native/lib/mongodb/connection').Server
MongoId: require('../lib/node-mongodb-native/lib/mongodb/bson/bson').ObjectID

class Mongo
  localUrl: 'http://localhost:27017/nodeko'
  constructor: ->
    @parseUrl process.env['MONGOHQ_URL'] or @localUrl
    @server: new MongoServer @host, @port
    @db: new MongoDb @dbname, @server
    if @user?
      @db.open =>
        @db.authenticate @user, @password, -> # no callback
    else @db.open -> # no callback

  parseUrl: (urlString)->
    uri: url.parse urlString
    @host: uri.hostname
    @port: parseInt(uri.port)
    @dbname: uri.pathname.replace(/^\//,'')
    [@user, @password]: uri.auth.split(':') if uri.auth?
exports.Mongo: Mongo

_.extend Mongo, {
  db: (new Mongo()).db

  bless: (klass) ->
    Serializer.bless klass
    _.extend klass.prototype, Mongo.InstanceMethods
    _.extend klass, Mongo.ClassMethods
    klass

  blessAll: (namespace) ->
    for name, klass of namespace
      klass::serialize: or name
      @bless klass

  queryify: (query) ->
    return {} unless query?
    if _.isString query
      { _id: MongoId.createFromHexString(query) }
    else query

  instantiate: (data, fn) ->
    unpacked: Serializer.unpack data
    if unpacked?.beforeInstantiate?
      unpacked.beforeInstantiate ->
        fn null, unpacked
    else
      fn null, unpacked

  InstanceMethods: {
    collection: (fn) ->
      Mongo.db.collection @serializer.name, fn

    id: -> @_id.toHexString()

    save: (fn) ->
      if @beforeSave?
        @beforeSave => @_save fn
      else
        @_save fn

    _save: (fn) ->
      @collection (error, collection) =>
        return fn error if error?
        serialized: Serializer.pack this
        collection.save serialized, (error, saved) =>
          @_id: saved._id
          fn error, saved

    update: (attributes) ->
      for k, v of attributes when @hasOwnProperty(k)
        this[k]: v

    remove: (fn) ->
      @collection (error, collection) =>
        return fn error if error?
        collection.remove Mongo.queryify(@id()), fn
  }

  ClassMethods: {
    firstOrCreate: (query, fn) ->
      @first query, (error, item) =>
        return fn error if error?
        return fn null, item if item?
        created: new @prototype.serializer.klass(query)
        fn null, created

    first: (query, fn) ->
      [query, fn]: [null, query] unless fn?
      @prototype.collection (error, collection) ->
        return fn error if error?
        collection.findOne Mongo.queryify(query), (error, item) ->
          return fn error if error?
          Mongo.instantiate item, fn

    all: (query, fn) ->
      [query, fn]: [null, query] unless fn?
      @prototype.collection (error, collection) ->
        return fn error if error?
        collection.find Mongo.queryify(query), (error, cursor) ->
          return fn error if error?
          cursor.toArray (error, array) ->
            return fn error if error?
            # TODO call beforeInstantiate on these?
            fn null, Serializer.unpack array
  }
}

class Serializer
  constructor: (klass, name, options) ->
    [@klass, @name]: [klass, name]

    @allowed: {}
    for i in _.compact _.flatten [options?.exclude]
      @allowed[i]: false

    # constructorless copy of the class
    @copy: -> # empty constructor
    @copy.prototype: @klass.prototype # same prototype

  shouldSerialize: (name, value, nested) ->
    return false unless value?
    return false if nested and name isnt '_id'
    @allowed[name] ?= _.isString(value) or
      _.isNumber(value) or
      _.isBoolean(value) or
      _.isArray(value) or
      value.serializer? or
      name is '_id'

  pack: (instance, nested) ->
    packed: { serializer: @name }
    for k, v of instance when @shouldSerialize(k, v, nested)
      packed[k]: Serializer.pack v, true
    packed

  unpack: (data) ->
    unpacked: new @copy()
    for k, v of data when k isnt 'serializer'
      unpacked[k]: Serializer.unpack v
    unpacked

_.extend Serializer, {
  instances: {}

  pack: (data, nested) ->
    if s: data?.serializer
      s.pack data, nested
    else if _.isArray(data)
      Serializer.pack i, true for i in data
    else
      data

  unpack: (data) ->
    if s: Serializer.instances[data?.serializer]
      s.unpack data
    else if _.isArray(data)
      Serializer.unpack i for i in data
    else
      data

  bless: (klass) ->
    [name, options]: _.flatten [ klass::serialize ]
    klass::serializer: new Serializer(klass, name, options)
    Serializer.instances[name]: klass::serializer

  blessAll: (namespace) ->
    for k, v of namespace when v::serialize?
      Serializer.bless v
}