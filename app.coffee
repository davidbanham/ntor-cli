conf = require './conf/conf.coffee'
request = require 'request'
fs = require 'fs'
mkdirp = require 'mkdirp'
tar = require 'tar'
cookie = require 'cookie'
io = require 'socket.io-client'
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

grab = (item) ->
  item.totalDown = 0
  lastPercentage = 0
  if dlProcs[item.path]
    console.log "Grab already in progress", item
    return null
  req = request.get("#{ntorUrl}/tar?path=#{encodeURIComponent item.path}").pipe(tar.Extract({ path: conf.dl.incoming }))
  dlProcs[item.path] = req
  req.on 'data', (data) ->
    item.totalDown += data.length
    item.percentDown = (item.totalDown / item.size * 100).toFixed(2)
    if item.percentDown.split('.')[0] != lastPercentage
      socket.emit('progress', {name: item.name, totalDown: item.totalDown, percentDown: item.percentDown})
      lastPercentage = item.percentDown.split('.')[0]
  req.on 'end', () ->
    remove item
    delete dlProcs[item.path]
    updateQueue()
    
updateQueue = () ->
  request "#{ntorUrl}/queue", (err, res, body) ->
    console.log err if err?
    queue = JSON.parse body
    console.log "queue length is ", queue.length
    grab queue[0] if queue[0]?

xbmcmessage = (title, message) ->
  id: '1'
  jsonrpc: '2.0'
  method: 'GUI.ShowNotification'
  params:
    title: title
    message: message
