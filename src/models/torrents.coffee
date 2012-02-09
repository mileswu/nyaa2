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

