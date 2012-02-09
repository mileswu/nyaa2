User = require('../models/users')
Torrent = require('../models/torrents')

exports.register = (req, res) ->
  if req.session.user?
    res.redirect '/'
  else
    res.render 'users/register', {title: 'Register'}

exports.register_post = (req, res) ->
  if !req.body.username.match /^[a-z0-9_-]+$/i
    req.flash 'error', 'Invalid characters in username.'
    res.redirect '/register'
    return
  if req.body.password1 isnt req.body.password2
    req.flash 'error', 'Passwords do not match.'
    res.redirect '/register'
    return
  user = new User {name: req.body.username, pass: req.body.password1}
  user.set 'email', req.body.email if req.body.email
  user.save (err) ->
    if err
      req.flash 'error', 'That username is already taken.'
      res.redirect '/register'
    else
      req.flash 'info', 'Successfuly created user "' + req.body.username + '".'
      res.redirect '/login'

exports.login = (req, res) ->
  if req.session.user?
    res.redirect '/'
  else
    res.render 'users/login', {title: 'Login'}

exports.login_post = (req, res) ->
  if req.body.username is '' or req.body.password is ''
    req.flash 'error', 'You must specify a username and password'
    res.redirect '/login'
    return
  User.findOne {name_lc: req.body.username.toLowerCase()}, (err, user) ->
    if err or !user or !user.verifyPass req.body.password
      req.flash 'error', 'Invalid username or password.'
      res.redirect '/login'
    else
      user.lastLogin = new Date
      user.save()
      req.session.user = user
      if user.admin
        req.session.admin = true
      else
        req.session.admin = false
      res.redirect '/'

exports.logout = (req, res) ->
  if req.session.user?
    req.flash 'info', 'You were logged out successfully'
    delete req.session.user
  res.redirect '/'

exports.list = (req, res) ->
  User.find {}, (err, users) ->
    res.render 'users/list', {title: 'Listing users', users}

exports.show = (req, res) ->
  User.findOne {name_lc: req.params.name.toLowerCase()}, (err, user) ->
    return res.send 500 if err
    return res.send 404 if !user?
    query = { uploader: user.name }
    q = Torrent.find query
    Torrent.findTorrents q, (torrents) ->
      res.render 'users/show', {title: user.name, user, torrents}
