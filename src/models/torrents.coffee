# Load Mongoose
mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/nyaa2'

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

Comment = new Schema {
  body  : String,
  author: ObjectId,
  date  : Date
}

File = new Schema {
  path  : String,
  size  : Number
}

Torrent = new Schema {
  uploader     : ObjectId,
  title        : String,
  size         : Number,
  dateUploaded : Date,
  files        : [File],
  description  : String,
  comments     : [Comment],
  infohash     : String
}

TorrentModel = mongoose.model 'Torrent', Torrent

exports.Torrent = TorrentModel

