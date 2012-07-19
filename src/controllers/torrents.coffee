fs = require 'fs'
bencode = require '../../lib/bencode'
crypto = require 'crypto'
http = require 'http'
url = require 'url'
md = require('markdown').markdown
RSS = require 'rss'

# data structure: sorted set -> key: 'rss', score: 'dateUploaded', member 'rss:@infohash'
#                 Hash       -> key: 'rss:infohash', title: @title, url: @permalink, ...
# On torrent creation, add it to the sorted set. Whenever torrent is uploaded or edited,
# modify the hash. Prune the sorted set when new torrents are uploaded or removed, and
# regenerate and cache the xml whenever the actual rss feed is requested.

feed = new RSS {
  title       : 'uguu~tracker',
  description : 'RSS'
  feed_url    : '/rss'
  site_url    : '/'
}

feed.generate = (callback) ->
  feed.items = []
  redis.ZREVRANGE 'rss', 0, 49, (err, data) ->
    multi = redis.multi()
    for key in data
      multi.HGETALL key
    multi.exec (err, hdata) ->
      for entry in hdata
        feed.item entry
      console.log feed
      conv = feed.xml()
      redis.SET 'rss:xml', conv, (err, data) ->
        callback(conv)

exports.rss = (req, res) ->
	redis.GET 'rss:xml', (err, data) ->
		if data == null
			feed.generate (xml) ->
				res.contentType 'application/rss+xml'
				res.send xml
		else
			res.contentType 'text/xml'
			res.send data

DROP_COUNT = 3
ANNOUNCE_INTERVAL = 300

Categories = require('../models/categories')

Torrent = require('../models/torrents')
regex_escape = (str) -> str.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")

exports.list = (req, res) -> 
  query = {}
  if req.query.searchcategory and req.query.searchtext
    query['category'] = req.query.searchcategory
    
    searchtext = req.query.searchtext
    searchterms = searchtext.split(' ')
    searchterms = searchterms.map (t) ->
      new RegExp regex_escape(t), 'i'
    
    query['title'] = {'$all' : searchterms}

  Torrent.count query, (err, count) ->
    q = Torrent.find query
    resperpage = 50 #50 per page
    q.limit(resperpage)
    page = parseInt(req.query.page)
    if !isNaN(page)
      q.skip((page-1)*resperpage)
    else
      page = 1
      q.skip(0)

    Torrent.findTorrents q, (docs) ->
      res.render 'torrents/list', {'title' : 'Listing torrents', 'torrents' : docs, 'searchcategory' : req.query.searchcategory, 'searchtext' : req.query.searchtext, 'page' : page, 'count' : count, 'lastpage' : Math.ceil(count/resperpage) }

exports.upload = (req, res) ->
  res.render 'torrents/upload', {'title' : 'Upload a torrent'}

exports.upload_post = (req, res) ->
  fields = req.body
  files = req.files
  process_file = (f_path) ->
    fs.readFile f_path, (err, data) ->
      # This needs full error checking to check .torrent is valid
      try
        torrentInfo = bencode.bdecode data
      catch err
        console.log data
        console.log err
        return

      hasher = crypto.createHash 'sha1'
      hasher.update bencode.bencode(torrentInfo.info)
      infohash = hasher.digest 'hex'
  
      if !fields.category? or !Categories.categories[fields.category]?
        req.flash 'error', "You have somehow selected a nonexistent category."
        res.redirect '/upload'
        return
  
      Torrent.findOne {'infohash' : infohash}, (err, doc) ->
        if doc
          req.flash 'error', 'This torrent has already been uploaded.'
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
            'infohash'    : infohash,
            'size'        : size,
            'title'       : title,
            'files'       : torrentFiles,
            'description' : fields.description,
            'markuplang'  : fields.markuplang
            'category'    : fields.category,
            'dateUploaded': new Date
          }
          if req.session.user
            torrent.uploader = req.session.user.name
          if fields.useexternaltracker
            torrent.external_tracker = torrentInfo.announce
          redis.SET 'torrent:'+infohash+':desc', md.toHTML(fields.description), (err, data) ->
            console.log err
            console.log data
          torrent.generatePermalink (err) ->
            torrent.save (err) ->
              fs.writeFile (__dirname+'/../../torrents/' + infohash + '.torrent'), data, (err) ->
                fs.unlink f_path, (err) ->
                  res.redirect ('/torrent/' + torrent.permalink)

  if files.torrent.size > 0
    console.log "bad things are happening"
    process_file files.torrent.path
  else if fields.torrenturl
    h_url = url.parse fields.torrenturl
    http_opt = {'host' : h_url.host, 'path' : h_url.pathname + (h_url.search ? ''), 'port' : (h_url.port ? 80)}
    console.log http_opt
    h_req = http.get http_opt, (h_res) ->
      f_path = '/tmp/herp.torrent'
      write_stream = fs.createWriteStream f_path

      h_res.on 'data', (chunk) ->
        write_stream.write chunk

      h_res.on 'end', ->
        write_stream.end()
        process_file f_path

    h_req.on 'error', (err) ->
      console.log err
      req.flash 'error', 'There was some error with the download of your torrent'
      req.redirect '/upload'
  else
    req.flash 'error', "There was an error with the upload form"
    res.redirect '/upload'
    return

exports.delete = (req, res) ->
  Torrent.findOne {'permalink' : req.params.permalink}, (err, doc) ->
    if doc
      if req.session.admin == true or (doc.uploader != undefined and req.session.user and doc.uploader == req.session.user.name)
        key = 'torrent:'+doc.infohash
        redis.DEL key+':seeds', key+':peers', key+':desc'
        doc.remove()
        req.flash 'info', "Your torrent was successfully deleted"
        res.redirect '/'
      else
        res.send 'Not authorized to do this', 400
    else
      res.send 'This torrent does not exist', 404

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
          torrentInfo.announce = 'http://bt-tracker.uguu-subs.org:9001/announce'
          
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
      multi = redis.multi()
      t = Date.now()
      t_ago = t - ANNOUNCE_INTERVAL * DROP_COUNT * 1000
      key_seed = 'torrent:' + doc.infohash + ':seeds'
      key_peer = 'torrent:' + doc.infohash + ':peers'
      multi.ZREMRANGEBYSCORE key_peer, 0, t_ago
      multi.ZREMRANGEBYSCORE key_seed, 0, t_ago
      multi.ZCARD key_peer
      multi.ZCARD key_seed
      multi.exec (err, replies) ->
        replies.shift()
        replies.shift()
        doc.peers = replies.shift()
        doc.seeds = replies.shift()
        redis.GET 'torrent:' + doc.infohash + ':desc', (err, data) -> # not part of the multi because that does weird things with arrays
          if data == null # this is probably completely unnecessary
            conv = md.toHTML doc.description
            redis.SET key_desc, conv
            doc.convdesc = conv
          else
            doc.convdesc = data
          if req.session.admin == true or (doc.uploader != undefined and req.session.user and doc.uploader == req.session.user.name)
            res.render 'torrents/torrent', {'torrent': doc, 'title' : 'Showing ' + doc.title, 'js' : ['torrent_show.js']}
          else
            res.render 'torrents/torrent', {'torrent': doc, 'title' : 'Showing ' + doc.title}
    else
      res.render 'torrents/torrent', {'torrent': null, 'title' : 'Invalid link' }

exports.categories_json = (req, res) ->
  output = {}
  output[cat] = cat for cat, p of Categories.categories
  if req.query.selected
    output["selected"] = req.query.selected
  res.send JSON.stringify(output)

exports.getmarkup = (req, res) ->
  Torrent.findOne {'permalink' : req.params.permalink}, (err, doc) ->
    res.send doc.description

exports.edit = (req, res) ->
  #perhaps send proper error codes, but then dunno how to do AJAX end
  Torrent.findOne {'permalink' : req.params.permalink}, (err, doc) ->
    if doc
      if req.session.admin == true or (doc.uploader != undefined and req.session.user and doc.uploader == req.session.user.name)
      else
        res.send 'Not authorized to do this'
        return
      
      if req.body.id == 'description'
        doc.description = req.body.value
        doc.save (err) ->
          conv = md.toHTML req.body.value
          redis.SET 'torrent:'+doc.infohash+':desc', conv, (err, data) ->
            res.send conv
      else if req.body.id == 'title'
        doc.title = req.body.value
        doc.save (err) ->
          res.send doc.title
      else if req.body.id == 'category'
        doc.category = req.body.value
        doc.save (err) ->
          res.send doc.category
      else
        res.send 'Invalid request'
    else
      res.send 'Torrent not found'
