// This is nicer than having to compile the coffeescript all the time, and doesn't require coffee installed globally
// Include the CoffeeScript interpreter so that .coffee files will work
var coffee = require('coffee-script');

// Include our application file
var app = require('./app.coffee');
