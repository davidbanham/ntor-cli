conf = require './conf/conf.coffee'
request = require 'request'
querystring = require 'querystring'
zlib = require 'zlib'
path = require 'path'
fs = require 'fs'
mkdirp = require 'mkdirp'
tar = require 'tar'
spawn = require('child_process').spawn
lock = false

ntorUrl = "https://#{encodeURIComponent conf.ntor.username}:#{encodeURIComponent conf.ntor.password}@#{conf.ntor.domain}"

console.log "Ntor client started"

checkQueue = () ->
  return if lock
  lock = true
  request "#{ntorUrl}/showQueue", (err, res, body) ->
    queue = JSON.parse body
    for item in queue
      target = item if item.claimed == false
      break
    return lock = false if !target?
    console.log "Target is #{target.path}"
    target.claimed = true
    request.post { url: "#{ntorUrl}/claimItem", json: target }, (err, res, item) ->
      filePath = path.dirname item.path
      mkdirp.sync "#{conf.dl.incoming}/#{filePath}"
      fd = fs.createWriteStream "#{__dirname}/dl.tar"
      grabTar = request.get("#{ntorUrl}/tar?path=#{item.path}").pipe fd
      grabTar.on 'close', () ->
        console.log "called"
        extractTar = spawn "tar", ["xf", "#{__dirname}/dl.tar"], {cwd: conf.dl.incoming}
        extractTar.stdout.on 'data', (data) ->
          console.log data.toString()
        extractTar.stderr.on 'data', (data) ->
          console.log data.toString()
        extractTar.on 'exit', (code) ->
          console.error "Tar process failed with code: #{code}" if code > 0
          request.post { url: "#{ntorUrl}/removeFromQueue", json: item }, (err, res, body ) ->
            console.log "Removed #{item.path} from queue"
            lock = false

checkQueue()

setInterval checkQueue, 15*1000
