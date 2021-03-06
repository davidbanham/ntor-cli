conf = require './conf/conf.coffee'
spawn = require('child_process').spawn
request = require 'request'
fs = require 'fs'
tar = require 'tar'
cookie = require 'cookie'
io = require 'socket.io-client'
EventEmitter = require('events').EventEmitter
messenger = new EventEmitter
dlProcs = {}
queue = []
socket = null

authUrl = "https://#{encodeURIComponent conf.ntor.username}:#{encodeURIComponent conf.ntor.password}@#{conf.ntor.domain}"
ntorUrl = "https://#{conf.ntor.domain}"

request "#{authUrl}/queue", (err, res, body) ->
  cook = cookie.parse res.headers['set-cookie'].toString()
  sessu = cook['ntor.sid']
  connectSocket(sessu)

console.log "Ntor client started"

connectSocket = (sessu) ->
  
  socket = io.connect "https://"+conf.ntor.domain+"?sessu="+sessu

  socket.on 'connect', () ->
    socket.on 'queueItem', (data) ->
      console.log "queueItem recieved", data
      if data.action == 'delete' && dlProcs[data.path]
        console.log "Item in progress deleted from queue, ending.", data
        dlProcs[data.path].end()
        delete dlProcs[data.path]
      updateQueue()
    console.log "Socket connected"
    updateQueue()
     
  socket.on 'error', (err) ->
    console.log "Socket error", err

updateQueue = () ->
  request "#{ntorUrl}/queue", (err, res, body) ->
    console.log err if err?
    queue = JSON.parse body
    console.log "queue length is ", queue.length
    grab queue[0] if queue[0]?

grab = (item) ->
  if dlProcs[item.path]
    console.log "Grab already in progress", item
    return null
  item.totalDown = 0
  item.lastPercentage = 0
  item.req = req
  untar = (spawn 'tar', ['--extract', '--directory', conf.dl.incoming, '--file', '-']).stdin if conf.systemTar
  untar = tar.Extract({ path: conf.dl.incoming }) if !conf.systemTar
  req = request.get("#{ntorUrl}/tar?path=#{encodeURIComponent item.path}")
  req.pipe untar
  messenger.emit "start", item
  req.on 'data', (data) ->
    messenger.emit 'data', item, data.length
  req.on 'end', () ->
    console.log "File complete!", item
    messenger.emit "finish", item
    request.post {url: "#{ntorUrl}/queue/remove", json: true, body: {path: item.path}}, (err, res, body) ->
      updateQueue()
  req.on 'error', (err) ->
    console.log err

messenger.on 'start', (item) ->
  dlProcs[item.path] = item.req
messenger.on 'finish', (item) ->
  delete dlProcs[item.path]
messenger.on 'data', (item, length) ->
  item.totalDown += length
  item.percentDown = (item.totalDown / item.size * 100).toFixed(2)
  if item.percentDown.split('.')[0] != item.lastPercentage
    socket.emit('progress', {name: item.name, totalDown: item.totalDown, percentDown: item.percentDown})
    item.lastPercentage = item.percentDown.split('.')[0]

if conf.xbmc.enabled
  messenger.on 'start', (item) ->
    xbmcMessage "ntor - Download started", item.name if conf.xbmc
  messenger.on 'finish', (item) ->
    xbmcMessage "ntor - Download complete!", item.name if conf.xbmc

xbmcMessage = (title, message) ->
  request.post "http://#{conf.xbmc.host}:#{conf.xbmc.port}/jsonrpc",
    json:
      id: '1'
      jsonrpc: '2.0'
      method: 'GUI.ShowNotification'
      params:
        title: title
        message: message
