User = require('../models/users').User

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
  res.redirect '/login' if req.body.username is '' or req.body.password is ''
  User.findOne {name_lc: req.body.username.toLowerCase()}, (err, user) ->
    if err or !user.verifyPass req.body.password
      req.flash 'error', 'Invalid username or password.'
      res.redirect '/login'
    else
      user.lastLogin = new Date
      user.save()
      req.session.user = user
      res.redirect '/'

exports.list = (req, res) ->
  User.find {}, (err, docs) ->
    res.render 'users/list', {title: 'Listing users', users: docs}

