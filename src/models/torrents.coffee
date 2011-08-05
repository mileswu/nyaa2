# Load Mongoose
mongoose = require 'mongoose'
mongoose.connect 'mongodb://localhost/nyaa2'

Schema = mongoose.Schema
ObjectId = Schema.ObjectId

Comments = new Schema {
  body  : String,
  author: ObjectId,
  date  : Date
}

Torrent = new Schema {
  uploader     : ObjectId,
  title        : String,
  size         : Number,
  dateUploaded : Date,
  fileList     : [String],
  description  : String,
  comments    : [Comments]
}

TorrentModel = mongoose.model 'Torrent', Torrent

exports.Torrent = TorrentModel

