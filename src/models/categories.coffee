configFile = __dirname + '/../../config/categories.json'
fs = require 'fs'

class Categories
  constructor: (@configPath) ->
    json = fs.readFileSync(@configPath)
    obj = JSON.parse json
    @categories = obj.categories
    @meta_categories = obj.meta_categories
  
  save: ->
    json = JSON.stringify {'categories' : @categories, 'meta_categories' : @meta_categories}
    res = fs.writeFileSync @configPath, json

module.exports = new Categories(configFile)

