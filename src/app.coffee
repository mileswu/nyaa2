#!/usr/bin/env coffee

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
admin = require './controllers/admin'
Categories = require './models/categories'

# Helpers

app.dynamicHelpers
  req: (req, res) -> return req
  categories: (req, res) -> return Categories.categories

# Routes

app.get '/', torrents.list

app.get '/upload', torrents.upload
app.post '/upload', torrents.upload_post

app.get '/torrent/:permalink', torrents.show
app.get '/torrent/:permalink/download', torrents.download


app.get '/register', users.register
app.post '/register', users.register_post

app.get '/login', users.login
app.get '/logout', users.logout
app.post '/login', users.login_post

app.get '/user', (req, res) ->
  return res.redirect '/' if !req.session.user?
  req.params.name = req.session.user.name
  users.show req, res
app.get '/user/:name', users.show

app.get '/admin/categories', admin.categories
app.get '/admin/category/:name/edit', admin.category_edit
app.get '/admin/category/new', admin.category_edit
app.post '/admin/category_edit', admin.category_edit_post

# Listen

app.listen 3000
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env

