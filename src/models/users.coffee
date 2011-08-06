generateHash = (str, alg) ->
  alg ?= 'sha512'
  hash = require('crypto').createHash(alg)
  hash.update str
  alg + '-' + hash.digest 'hex'

Schema = mongoose.Schema

User = new Schema
  name:
    type: String
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
  admin:
    type: Boolean
    default: false
  joinDate:
    type: Date
    default: Date.now
  lastLogin:
    type: Date

User.pre 'save', (next) ->
  @name_lc = @name.toLowerCase()
  next()

User.method 'verifyPass', (test) ->
  alg = @pass.substr 0, @pass.indexOf '-'
  @pass is generateHash test, alg

module.exports = mongoose.model 'User', User

