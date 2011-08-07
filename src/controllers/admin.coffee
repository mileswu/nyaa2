Categories = require('../models/categories')

exports.categories = (req, res) ->
  res.render 'admin/categories', {'title' : 'Listing categories'}

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
    if oldname
      res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/category/new'
    return
  if !name? or !name
    req.flash 'error','You must specify an name'
    if oldname
      res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/category/new'
    return
  if name != oldname and (Categories.categories[name]? or Categories.meta_categories[name]?)
    req.flash 'error','A category named ' + name + ' already exists'
    if oldname
      res.redirect '/admin/category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/category/new'
    return
  
  if oldname
    delete Categories.categories[oldname]
  Categories.categories[name] = {
    'icon' : req.body.icon
  }

  Categories.save()
  req.flash 'info', 'Succesfully edited'
  res.redirect '/admin/categories'


exports.meta_category_edit = (req, res) ->
  name = req.params.name
  if name?
    cat_list = Categories.meta_categories[name]
    if !cat_list?
      req.flash 'error', 'Invalid meta-category'
      res.redirect '/admin/categories'
      return
    res.render 'admin/meta_category_edit', {'title' : 'Editing meta category' + name, 'name' : name, 'cat_list' : cat_list}
  else #this is a new cat
    res.render 'admin/meta_category_edit', {'title' : 'New meta category', 'name' : null, 'cat_list' : []}

exports.meta_category_edit_post = (req, res) ->
  oldname = req.body.oldname
  name = req.body.name
  if oldname and !Categories.meta_categories[oldname]?
    req.flash 'error', 'Invalid meta-category'
    res.redirect '/admin/categories'
    return
  
  if !name? or !name
    req.flash 'error','You must specify an name'
    if oldname
      res.redirect '/admin/meta-category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/meta-category/new'
    return
  if name != oldname and (Categories.categories[name]? or Categories.meta_categories[name]?)
    req.flash 'error','A category named ' + name + ' already exists'
    if oldname
      res.redirect '/admin/meta-category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/meta-category/new'
    return
    
  cats = req.body.categories
  if !cats
    req.flash 'error','You must select one category'
    if oldname
      res.redirect '/admin/meta-category/' + encodeURIComponent(oldname) + '/edit'
    else
      res.redirect '/admin/meta-category/new'
    return
    
  if !Array.isArray(cats)
    cats = [cats]
  for i in cats
    if !Categories.categories[i]?
      req.flash 'error','Form error'
      if oldname
        res.redirect '/admin/meta-category/' + encodeURIComponent(oldname) + '/edit'
      else
        res.redirect '/admin/meta-category/new'
      return
 
  if oldname
    delete Categories.meta_categories[oldname]
  Categories.meta_categories[name] = cats

  Categories.save()
  req.flash 'info', 'Succesfully edited'
  res.redirect '/admin/categories'
  
