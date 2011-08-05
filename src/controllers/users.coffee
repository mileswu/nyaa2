User = require('../models/users').User

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
      req.session.user = user
      res.redirect '/'

exports.list = (req, res) ->
  User.find {}, (err, docs) ->
    res.render 'users/list', {title: 'Listing users', users: docs}

