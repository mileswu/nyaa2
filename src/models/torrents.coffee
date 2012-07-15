Schema = mongoose.Schema
ObjectId = Schema.ObjectId

Comment = new Schema {
  body      : String,
  author_id : ObjectId,
  date      : Date
}

File = new Schema {
  path  : String,
  size  : Number
}

Torrent = new Schema {
  uploader     : String,
  title        : String,
  size         : Number,
  snatches     : {type: Number, default: 0},
  dateUploaded : {type: Date, default: new Date},
  files        : [File],
  description  : String,
  comments     : [Comment],
  category     : String,
  external_tracker: String,
  infohash     : {type: String, index: {unique:true}}
  permalink    : {type: String, index: {unique:true}}
}

DROP_COUNT = 3
ANNOUNCE_INTERVAL = 300

Torrent.statics.findTorrents = (q, callback) ->
  q.select { title : 1, size : 1, dateUploaded : 1, category : 1, permalink : 1, snatches : 1, infohash :1 }, { _id : 0 }
  q.sort 'dateUploaded', -1
  q.exec (err, docs) ->
    multi = redis.multi()
    t = Date.now()
    t_ago = t - ANNOUNCE_INTERVAL * DROP_COUNT * 1000
    for doc in docs
      key_seed = 'torrent:' + doc.infohash + ':seeds'
      key_peer = 'torrent:' + doc.infohash + ':peers'
      multi.ZREMRANGEBYSCORE key_peer, 0, t_ago
      multi.ZREMRANGEBYSCORE key_seed, 0, t_ago
      multi.ZCARD key_peer
      multi.ZCARD key_seed

    multi.exec (err, replies) ->
      for doc in docs
        replies.shift()
        replies.shift()
        doc.peers = replies.shift()
        doc.seeds = replies.shift()
      callback(docs)

Torrent.method 'generatePermalink', (callback) ->
  baseurl = @title.substring(0, 75).replace(`/ /g`, '_')
  # check for collisions
  checkFunc = (base, endno) =>
    if endno > 0
      url = base + '-' + endno
    else
      url = base
    (mongoose.model 'Torrent').findOne {'permalink' : url}, (err, doc) =>
      if doc
        checkFunc base, endno+1
      else
        @permalink = url
        callback ''
  checkFunc baseurl, 0

module.exports = mongoose.model 'Torrent', Torrent

