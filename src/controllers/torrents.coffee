Torrent = require('../models/torrents').Torrent

exports.list = (req, res) -> 
  Torrent.find {}, (err, docs) ->
    res.render 'torrents/list', {'title' : 'Listing torrents', 'torrents' : docs}


