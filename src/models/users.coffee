generateHash = (str, alg) ->
  alg ?= 'sha512'
  hash = require('crypto').createHash(alg)
  hash.update str
  alg + '-' + hash.digest 'hex'

# Load Mongoose
mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/nyaa2'

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

User = new Schema
  name:
    type: String
    set: (v) -> @name_lc = v.toLowerCase(); v
    required: true
  name_lc:
    type: String
    unique: true
  pass:
    type: String
    set: (v) -> generateHash v
    required: true
  email:
    type: String
  joinDate:
    type: Date
    default: Date.now
  lastLogin:
    type: Date

User.method 'verifyPass', (test) ->
  alg = @pass.substr 0, @pass.indexOf '-'
  @pass is generateHash test, alg

exports.User = mongoose.model 'User', User

