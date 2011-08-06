configFile = __dirname + '/../../config/categories.json'
fs = require 'fs'

class Categories
  constructor: (@configPath) ->
    json = fs.readFileSync(@configPath)
    @categories = (JSON.parse json).config
  
  save: ->
    json = JSON.stringify {'config' : @categories}
    fs.writeFileSync @configPath

module.exports = new Categories(configFile)

