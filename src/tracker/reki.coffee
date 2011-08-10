# includes
http = require 'http'
url  = require 'url'
qs   = require 'querystring'
fs   = require 'fs'
bencode = require '../../lib/bencode'

# defines
ANNOUNCE_INTERVAL = 60
MIN_INTERVAL      = 30

# helper functions
simple_response = (res, data) ->
  res.setHeader 'Content-Type', 'text/plain'
  res.end (bencode.bencode data)

#compact = (ip, port) -> ip.split('.').concat([port >> 8 & 0xFF, port & 0xFF]).map((c) -> String.fromCharCode c)
compact = (ip, port) -> new Buffer ip.split('.').concat([port >> 8, port & 0xFF])

parse = (qs) ->
  obj = {}
  for kvp in qs.split '&'
    obj[kvp.substr(0, x)] = kvp.substr(x + 1) if ~(x = kvp.indexOf '=')
  obj

#bencode.bencode = (o) -> new Buffer 1
#bencode = (o) ->
#  bstring = (s) -> s.length + ':' + s
#  bint = (n) -> "i#{n}e"
#  blist = (l) ->
#    buf = 'l'
#    buf += bencode i for i in l
#    buf + 'e'
#  bdict = (d) ->
#    buf = 'd'
#    buf += bstring(k) + bencode(d[k]) for k in Object.keys(d).sort()
#    buf + 'e'
#  
#  switch typeof o
#    when 'string' then bstring o
#    when 'number' then bint    o
#    when 'object'
#      if o instanceof Array
#        blist o
#      else if o?
#        bdict o
#      else
#        throw new Error('cannot encode element null')
#    else
#      throw new Error('cannot encode element ' + o)

decodeURLtoHex = (str) ->
  output = ''
  for i in [0..str.length-1]
    if (str.charCodeAt i)== 37
      output += str[i+1] + str[i+2]
      i += 2
    else
      output += (str.charCodeAt i).toString 16
  return output.toLowerCase()

decodeURLtoBinary = (str, len) ->
  b = new Buffer len
  j = 0
  for i in [0..str.length-1]
    if (str.charCodeAt i)== 37
      b[j] = parseInt(str[i+1] + str[i+2], 16)
      i+=2
    else
      b[j] = str.charCodeAt i
    j += 1
  return b

# Tracker class
class Tracker
  constructor: (port) ->
    # redis
    @redis = require('redis').createClient 6379, '127.0.0.1', {'return_buffers' : true}
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
      #req_url = url.parse req.url
      if req.url.substr(0, 9) is '/announce'
        if query = req.url.split('?', 2)[1]
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
    info_hash = decodeURLtoHex get_vars['info_hash']
    peer_id = decodeURLtoBinary get_vars['peer_id'], 20
    
    port = parseInt get_vars['port']
    left = parseInt get_vars['left']
    if info_hash == '' or peer_id == '' or isNaN(port) or isNaN(left)
      return simple_response res, {'failure reason': 'Invalid Request'}

    key = 'torrent:' + info_hash

    check_exists = (callback) =>
      @redis.ZCARD (key + ':seeds'), (err, data)=>
        if data != 0
          callback()
        else
          @redis.ZCARD (key + ':peers'), (err, data)=>
            if data != 0
              callback()
            else
              @torrents.findOne {'infohash' : info_hash}, (err, exists) =>
                if exists
                  callback()
                else
                  return simple_response res, {'failure reason': 'This torrent does not exist'}
    check_exists =>
      event = get_vars['event']
      if event == 'stopped' or event == 'paused'
        return simple_response res, 'Nani?'
      
      t = Date.now()
      multi = @redis.multi()
        .ZREMRANGEBYSCORE(key + ':seeds', 0, t - ANNOUNCE_INTERVAL * 6000)
        .ZREMRANGEBYSCORE(key + ':peers', 0, t - ANNOUNCE_INTERVAL * 6000)
      
      ip = get_vars['ip'] #REALLY SHOULD CHECK THIS IS A VALID IP
      ip = req.client.remoteAddress if !ip?
      #ip = process.env['HTTP_X_REAL_IP'] if ip is '127.0.0.1'

      peer_entry = new Buffer 46
      peer_id.copy peer_entry, 0, 0, 20
      compact(ip, port).copy peer_entry, 20, 0, 6
      if ip.length > 15
        console.log "You have major problems. Please seek help"
        return
      for i in [26..45]
        peer_entry[i] = 0
      peer_entry.write ip, 26
      peer_entry.write port.toString(), 41

      suffix = if (left == 0) then ":seeds" else ":peers"
      multi.ZADD key + suffix, t, peer_entry
      
      if event == 'completed' #increment snatch
        @torrents.update {'infohash': info_hash}, {$inc: {'snatches': 1}}
      
      # Output now. Fields are:
      #   interval, complete, incomplete, peers (dict|bin) <--- REQUIRED
      #   min interval, tracker id, warning message        <--- optional
      
      numwant = parseInt get_vars['numwant']
      numwant = 50 if isNaN(numwant) or numwant < 0 or numwant > 50
      
      multi
        .ZCARD(key + ':seeds')
        .ZCARD(key + ':peers')
        .ZRANGE(key + ':seeds', 0, numwant)
        .ZRANGE(key + ':peers', 0, numwant)
        .exec (err, replies) =>
          #res.end 'hi'
          #return
          if err? then return simple_response res, {'failure reason': 'wat'}
          doCompact = get_vars['compact'] is '1'
          
          peerlist = replies[5].concat(replies[6])
            .slice(0, numwant)
            .map (p) ->
              if doCompact
                return p.slice 20, 26
              else
                return {'peer id': p.slice(0, 20), 'ip' : p.slice(26,41) , 'port' : p.slice(41,46)}
          if doCompact
            out = new Buffer (peerlist.length*6)
            for i in [0..peerlist.length-1]
              peerlist[i].copy out, i*6, 0
            peerlist = out
          
          return simple_response res,
            'interval'     : ANNOUNCE_INTERVAL
            'complete'     : replies[3]
            'incomplete'   : replies[4]
            'min interval' : MIN_INTERVAL
            'peers'        : peerlist

console.log 'Starting tracker on 127.0.0.1:6969...'
new Tracker 6969
