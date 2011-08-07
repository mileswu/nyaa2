fs = require 'fs'
bencode = require '../../lib/bencode'
crypto = require 'crypto'

Categories = require('../models/categories')

Torrent = require('../models/torrents')


exports.list = (req, res) -> 
  query = {}
  if req.query.searchcategory and req.query.searchtext
    query['category'] = req.query.searchcategory
    
    searchtext = req.query.searchtext
    searchterms = searchtext.split(' ')
    searchterms = searchterms.map (t) ->
      new RegExp t, 'i'
    
    query['title'] = {'$all' : searchterms}

  Torrent.find query, (err, docs) ->
    res.render 'torrents/list', {'title' : 'Listing torrents', 'torrents' : docs, 'searchcategory' : req.query.searchcategory, 'searchtext' : req.query.searchtext}

exports.upload = (req, res) ->
  res.render 'torrents/upload', {'title' : 'Upload a torrent'}

exports.upload_post = (req, res) ->
  if req.form
    req.form.complete (err, fields, files) ->
      if !files.torrent
        req.flash 'error', "There was an error with the upload form"
        res.redirect '/upload'
        return
      fs.readFile files.torrent.path, (err, data) ->
        # This needs full error checking to check .torrent is valid
        torrentInfo = bencode.bdecode data
        hasher = crypto.createHash 'sha1'
        hasher.update bencode.bencode(torrentInfo.info)
        infohash = hasher.digest 'hex'

        if !fields.category? or !Categories.categories[fields.category]?
          req.flash 'error', "There was an error with the upload form"
          res.redirect '/upload'
          return

        Torrent.findOne {'infohash' : infohash}, (err, doc) ->
          if doc
            req.flash 'error', 'This torrent is already uploaded'
            res.redirect ('/torrent/' + doc.permalink)
          else
            if fields.title
              title = fields.title
            else
              title = torrentInfo.info.name.toString 'utf8'

    
            torrentFiles = []
            if torrentInfo.info.files
              size = 0
              for file in torrentInfo.info.files
                torrentFiles.push {
                  'path' : (file.path.toString 'utf8'),
                  'size' : file.length
                }
                size += file.length
            else
              size = torrentInfo.info.length
              torrentFiles.push {
                'path' : (torrentInfo.info.name.toString 'utf8'),
                'size' : torrentInfo.info.length
              }
    
            torrent = new Torrent {
              'infohash' : infohash,
              'size'     : size,
              'title'    : title,
              'files'    : torrentFiles,
              'description' : fields.description,
              'category' : fields.category
            }
            if req.session.user
              torrent.uploader = req.session.user.name

            torrent.generatePermalink (err) ->
              torrent.save (err) ->
                fs.writeFile (__dirname+'/../../torrents/' + infohash + '.torrent'), data, (err) ->
                  fs.unlink files.torrent.path, (err) ->
                    res.redirect ('/torrent/' + torrent.permalink)
  else
    req.flash 'error', "There was an error with the upload form"
    res.redirect '/upload'

exports.download = (req, res) ->
  Torrent.findOne {'permalink' : req.params.permalink}, (err, doc) ->
    if doc
      infohash = doc.infohash
      fs.readFile (__dirname+'/../../torrents/' + infohash + '.torrent'), (err, data) ->
        if err
          console.log err
          res.send 'There was an error', 500
        else
          torrentInfo = bencode.bdecode data
          if torrentInfo['announce-list']
            delete torrentInfo['announce-list']
          torrentInfo.announce = 'mahtracker'
          
          output = bencode.bencode torrentInfo
          res.contentType 'application/x-bittorrent'

          res.header 'Content-Length', output.length
          res.attachment (doc.title + '.torrent')
          res.send output


          
      
    else
      res.send 'This torrent does not exist', 404


exports.show = (req, res) ->
  Torrent.findOne {'permalink' : req.params.permalink}, (err, doc) ->
    if doc
      res.render 'torrents/torrent', {'torrent': doc, 'title' : 'Showing ' + doc.title }
    else
      res.render 'torrents/torrent', {'torrent': null, 'title' : 'Invalid link' }




