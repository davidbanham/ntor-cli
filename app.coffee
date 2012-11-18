conf = require './conf/conf.coffee'
request = require 'request'
querystring = require 'querystring'
zlib = require 'zlib'
path = require 'path'
fs = require 'fs'
mkdirp = require 'mkdirp'
tar = require 'tar'

ntorUrl = "https://#{encodeURIComponent conf.ntor.username}:#{encodeURIComponent conf.ntor.password}@#{conf.ntor.domain}"

checkQueue = () ->
  request "#{ntorUrl}/showQueue", (err, res, body) ->
    queue = JSON.parse body
    for item in queue
      target = item if item.claimed == false
      break
    return delay checkQueue() if !target?
    console.log "Target is #{target.path}"
    target.claimed = true
    request.post { url: "#{ntorUrl}/claimItem", json: target }, (err, res, item) ->
      filePath = path.dirname item.path
      mkdirp.sync "#{conf.dl.incoming}/#{filePath}"
      grabTar = request.get("#{ntorUrl}/tar?path=#{item.path}").pipe tar.Extract {path: "#{conf.dl.incoming}"}
      grabTar.on 'close', () ->
        request.post { url: "#{ntorUrl}/removeFromQueue", json: item }, (err, res, body ) ->
          console.log "Removed #{item.path} from queue"
          delay checkQueue()

checkQueue()

delay = (ms, func) -> setTimeout func, ms || 15*1000
