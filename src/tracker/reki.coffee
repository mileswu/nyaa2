# includes
http = require 'http'
url  = require 'url'
qs   = require 'querystring'
fs   = require 'fs'

# defines
ANNOUNCE_INTERVAL = 60
MIN_INTERVAL      = 30

# helper functions
simple_response = (res, data) ->
  res.setHeader 'Content-Type', 'text/plain'
  res.end bencode data

compact = (ip, port) -> ip.split('.').concat([port >> 8 & 0xFF, port & 0xFF]).map((c) -> String.fromCharCode c).join('')

parse = (qs) ->
  obj = {}
  for kvp in qs.split '&'
    obj[kvp.substr(0, x)] = kvp.substr(x + 1) if ~(x = kvp.indexOf '=')
  obj

bencode = (o) ->
  bstring = (s) -> s.length + ':' + s
  bint = (n) -> "i#{n}e"
  blist = (l) ->
    buf = 'l'
    buf += bencode i for i in l
    buf + 'e'
  bdict = (d) ->
    buf = 'd'
    buf += bstring(k) + bencode(d[k]) for k in Object.keys(d).sort()
    buf + 'e'
  
  switch typeof o
    when 'string' then bstring o
    when 'number' then bint    o
    when 'object'
      if o instanceof Array
        blist o
      else if o?
        bdict o
      else
        throw new Error('cannot encode element null')
    else
      throw new Error('cannot encode element ' + o)

# Tracker class
class Tracker
  constructor: (port) ->
    # redis
    @redis = require('redis').createClient()
    @redis.on 'ready', -> console.log 'connected to redis'
    
    # mongodb
    @torrents = null
    mongo = require('mongodb')
    db = new mongo.Db 'nyaa2', new mongo.Server('localhost', mongo.Connection.DEFAULT_PORT, {native_praser: true})
    db.open (err, db) =>
      throw new Error('could not open db') if err?
      console.log 'connected to mongodb'
      db.collection 'torrents', (err, @torrents) =>
        throw new Error('could not open collection') if err?
    
    # http server
    http.createServer (req, res) =>
      req_url = url.parse req.url
      if req_url.pathname.substr(-9) is '/announce'
        if query = req_url.query
          @announce query, req, res
        else
          res.end '!?'
      else
        res.end '!?'
    
    # HEY! LISTEN!
    .listen port
  
  announce: (query, req, res) ->
    get_vars = parse query
    return simple_response res, {'failure reason': 'Invalid Request'} unless get_vars['info_hash']? and get_vars['peer_id']?
    
    # GET requests of interest are:
    #   info_hash, peer_id, port, uploaded, downloaded, left,   <--- REQUIRED
    #   compact, no_peer_id, event, ip, numwant, key, trackerid <--- optional
    
    info_hash = decodeURIComponent get_vars['info_hash']
    peer_id = decodeURIComponent get_vars['peer_id']
    
    port = parseInt get_vars['port']
    left = parseInt get_vars['left']
    if info_hash == '' or peer_id == '' or isNaN(port) or isNaN(left)
      return simple_response res, {'failure reason': 'Invalid Request'}
    
    @torrents.findOne {info_hash}, (err, exists) =>
      if err? then return simple_response res, {'failure reason': 'wat'}
      if !exists then return simple_response res, {'failure reason': 'This torrent does not exist'}
      
      event = get_vars['event']
      if event == 'stopped' or event == 'paused'
        return simple_response res, 'Nani?'
      
      t = Date.now()
      key = 'torrent:' + info_hash
      multi = @redis.multi()
        .ZREMRANGEBYSCORE(key + ':seeds', 0, t - ANNOUNCE_INTERVAL * 6000)
        .ZREMRANGEBYSCORE(key + ':peers', 0, t - ANNOUNCE_INTERVAL * 6000)
      
      ip = get_vars['ip']
      ip = req.client.remoteAddress if !ip?
      ip = process.env['HTTP_X_REAL_IP'] if ip is '127.0.0.1'
      
      peer = JSON.stringify [peer_id, ip, port, compact(ip, port)]
      suffix = if (left == 0) then ":seeds" else ":peers"
      multi.ZADD key + suffix, t, peer
      
      if event == 'completed' #increment snatch
        @torrents.update {info_hash}, {$inc: {snatches: 1}}
      
      # Output now. Fields are:
      #   interval, complete, incomplete, peers (dict|bin) <--- REQUIRED
      #   min interval, tracker id, warning message        <--- optional
      
      numwant = parseInt get_vars['numwant']
      numwant = 50 if isNaN(numwant) or numwant < 0 or numwant > 50
      
      multi
        .ZCOUNT(key + ':seeds', 0, t)
        .ZCOUNT(key + ':peers', 0, t)
        .ZRANGE(key + ':seeds', 0, numwant)
        .ZRANGE(key + ':peers', 0, numwant)
        .exec (err, replies) =>
          if err? then return simple_response res, {'failure reason': 'wat'}
          doCompact = get_vars['compact'] is '1'
          
          peerlist = replies[5].concat(replies[6])
            .slice(0, numwant)
            .map (p) ->
              [peer_id, ip, port, compacted] = JSON.parse p
              if doCompact then compacted else {'peer id': peer_id, ip, port}
          peerlist = peerlist.join '' if doCompact
          
          return simple_response res,
            'interval'     : ANNOUNCE_INTERVAL
            'complete'     : replies[3]
            'incomplete'   : replies[4]
            'min interval' : MIN_INTERVAL
            'peers'        : peerlist

console.log 'Starting tracker on 127.0.0.1:6969...'
new Tracker 6969
