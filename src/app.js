
/**
 * Module dependencies.
 */
require("coffee-script");
var express = require('express');

var app = module.exports = express.createServer();

// Configuration

app.configure(function(){
  app.set('views', __dirname + '/views');
  app.set('view engine', 'jade');
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(__dirname + '/public'));
});

app.configure('development', function(){
  app.use(express.errorHandler({ dumpExceptions: true, showStack: true })); 
});

app.configure('production', function(){
  app.use(express.errorHandler()); 
});

// Load

var torrents = require('./controllers/torrents');
var userss = require('./controllers/users');

// Routes
app.get('/', torrents.list);



app.listen(3000);
console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
