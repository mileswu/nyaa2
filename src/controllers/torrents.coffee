fs = require 'fs'
bencode = require '../../lib/bencode'
crypto = require 'crypto'

Torrent = require('../models/torrents').Torrent


exports.list = (req, res) -> 
  Torrent.find {}, (err, docs) ->
    res.render 'torrents/list', {'title' : 'Listing torrents', 'torrents' : docs}

exports.upload = (req, res) ->
  res.render 'torrents/upload', {'title' : 'Upload a torrent'}

exports.upload_post = (req, res) ->
  if req.form
    req.form.complete (err, fields, files) ->
      if !files.torrent
        req.flash 'error', "There was an error with the upload form"
        res.redirect '/upload'
      fs.readFile files.torrent.path, (err, data) ->
        # This needs full error checking to check .torrent is valid
        torrentInfo = bencode.bdecode data
        hasher = crypto.createHash 'sha1'
        hasher.update bencode.bencode(torrentInfo.info)
        infohash = hasher.digest 'hex'

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
          'files'    : torrentFiles
        }
        torrent.generatePermalink (err) ->
          torrent.save (err) ->
            fs.writeFile (__dirname+'/../../torrents/' + infohash + '.torrent'), data, (err) ->
              fs.unlink files.torrent.path, (err) ->
                res.redirect '/'
  else
    req.flash 'error', "There was an error with the upload form"
    res.redirect '/upload'
 

