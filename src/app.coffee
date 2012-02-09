#!/usr/bin/env coffee

# Module dependencies.

require 'coffee-script'
express = require 'express'
form = require 'connect-form'
util = require 'util'
qs = require 'querystring'

app = module.exports = express.createServer()

global.mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/nyaa2'

global.redis = require('redis').createClient 6379, '127.0.0.1' #, {'return_buffers' : true})

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
  util: (req, res) -> return util
  meta_categories: (req, res) -> return Categories.meta_categories

app.helpers
  humanize_size: (size) ->
    if size < 1024
      return size + ' B'
    size /= 1024
    
    if size < 1024
      return size.toFixed(0) + ' KB'
    size /= 1024

    if size < 1024
      return size.toFixed(1) + ' MB'
    size /= 1024
    
    if size < 1024
      return size.toFixed(1) + ' GB'
    size /= 1024
    return size.toFixed(2) + ' TB'

  humanize_date: (date) ->
    now = new Date
    deltat = (now - date)/1000 #javascript uses ms
    
    if deltat < 60
      return "Less than a minute ago"
    deltat /= 60
    if deltat < 60
      return deltat.toFixed(0) + " minutes ago"
    deltat /= 60
    if deltat < 24
      return deltat.toFixed(0) + " hours ago"
    deltat /= 24
    if deltat < 30
      return deltat.toFixed(0) + " days ago"
    deltat /= 30
    return deltat.toFixed(0) + " months ago"

  paginate: (page, lastpage, req) ->
    numlinks = 7
    if lastpage == 1
      return ''

    bound = (i, min, max) ->
      if i < min
        i = min
      else if i > max
        i = max
      i

    if lastpage <= numlinks
       start = 1
       end = lastpage
    else
       start = bound page - (numlinks + 1) >> 1, 1, lastpage - numlinks
       end = start + numlinks

    pagestr = ''

    q = {}
    q[k] = v for k, v of req.query
    make_url = (pagen) ->
      q['page'] = pagen
      req.route.path + '?' + qs.stringify q

    if page != 1
      pagestr += "<a href=\"#{make_url 1}\">&lArr; First</a>"
      pagestr += "<a href=\"#{make_url start - 1}\">&larr; Prev</a>"
    
    for i in [start..end] by 1
      if i isnt page
        pagestr += "<a href=\"#{make_url i}\">#{i}</a>"
      else
        pagestr += "#{i}"
    
    if page != lastpage
      pagestr += "<a href=\"#{make_url page + 1}\">Next &rarr;</a>"
      pagestr += "<a href=\"#{make_url lastpage}\">Last &rArr;</a>"
    
    "<div class=\"pagination\">#{pagestr}</div>"
    

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
app.get '/admin/users', users.list

app.get '/admin/categories', admin.categories
app.get '/admin/category/:name/edit', admin.category_edit
app.get '/admin/category/new', admin.category_edit
app.post '/admin/category_edit', admin.category_edit_post
app.get '/admin/meta-category/:name/edit', admin.meta_category_edit
app.get '/admin/meta-category/new', admin.meta_category_edit
app.post '/admin/meta-category_edit', admin.meta_category_edit_post
# Listen

app.listen 3000
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env

