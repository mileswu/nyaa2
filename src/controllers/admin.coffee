Categories = require('../models/categories')

exports.categories = (req, res) ->
  res.render 'admin/categories', {'title' : 'Listing categories', 'Categories' : Categories}

exports.category_edit = (req, res) ->
  name = req.params.name
  if name?
    category_opt = Categories.categories[name]
    if !category_opt?
      req.flash 'error', 'Invalid category'
      res.redirect '/admin/categories'
      return
    res.render 'admin/category_edit', {'title' : 'Editing category' + name, 'name' : name, 'cat_options' : category_opt}
  else #this is a new cat
    res.render 'admin/category_edit', {'title' : 'New category', 'name' : null, 'cat_options' : {}}

exports.category_edit_post = (req, res) ->
  oldname = req.body.oldname
  name = req.body.name
  if oldname and !Categories.categories[oldname]?
    req.flash 'error', 'Invalid category'
    res.redirect '/admin/categories'
    return
  

  if !req.body.icon? or !req.body.icon
    req.flash 'error','You must specify an icon'
    res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    return
  if !name? or !name
    req.flash 'error','You must specify an name'
    res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    return
  if name != oldname and Categories.categories[name]?
    req.flash 'error','A category named ' + name + ' already exists'
    res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    return
    
    
  delete Categories.categories[oldname]
  Categories.categories[name] = {
    'icon' : req.body.icon
  }

  Categories.save()
  req.flash 'info', 'Succesfully edited'
  res.redirect '/admin/categories'
