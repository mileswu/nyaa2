# Module dependencies.

require 'coffee-script'
express = require 'express'
form = require 'connect-form'

app = module.exports = express.createServer()

global.mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/nyaa2'

# Configuration

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.cookieParser()
  app.use express.session {secret: 'himitsu'}
  app.use form {keepExtensions: true}
  app.use app.router
  app.use express.static __dirname + '/public'

app.configure 'development', -> app.use express.errorHandler {dumpExceptions: true, showStack: true}
app.configure 'production', -> app.use express.errorHandler()

# Load

torrents = require './controllers/torrents'
users = require './controllers/users'

# Helpers

app.dynamicHelpers
  req: (req, res) -> return req
  userlink: (req, res) ->
    return '<a href="/login">Login</a>' if !req.session.user
    '<a href="/users/' + req.session.user.name + '">' + req.session.user.name + '</a>'

# Routes

app.get '/', torrents.list

app.get '/upload', torrents.upload
app.post '/upload', torrents.upload_post

app.get '/torrent/:permalink', torrents.show
app.get '/torrent/:permalink/download', torrents.download


app.get '/register', users.register
app.post '/register', users.register_post

app.get '/login', users.login
app.post '/login', users.login_post

app.get '/users', users.list

# Listen

app.listen 3000
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env

