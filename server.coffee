fs      = require('fs')
express = require('express')
spawn   = require('child_process').spawn

ipaddress = process.env.OPENSHIFT_NODEJS_IP
port      = process.env.OPENSHIFT_NODEJS_PORT || 8080

class Travian
  id: null

  ps: null

  constructor: (@logFile, @args) ->
    @start()

  log: (x) ->
    fs.appendFileSync @logFile, x

  logLn: (x) ->
    d = new Date()
    d.setTime d.getTime() + 8 * 3600000
    @log "<tr><td>#{x}</td><td>#{d.toUTCString()}</td></tr>"

  run: ->
    return if @ps
    @ps = spawn 'casperjs', ['travian.coffee', JSON.stringify @args]
    @log '<table>'
    @logLn 'begin'
    @ps.stdout.on 'data', (data) =>
      o = JSON.parse data
      @logLn o.msg if o.msg
    @ps.stderr.on 'data', (data) =>
      @logLn "<span style='color:red'>XXX#{data}XXX</span>"
    @ps.on 'exit', (code, signal) =>
      @logLn "exit with code[#{code}] and signal[#{signal}]"
    @ps.on 'close', (code, signal) =>
      @logLn "close with code[#{code}] and signal[#{signal}]"
      @log '</table><br>'
      @ps = null

  stop: ->
    clearInterval @id if @id
    @id = null

  start: (interval=900000) ->
    if not @id
      @run()
      @id = setInterval @run.bind(@), interval

travian = [
  new Travian 'log1.txt',
    baseUrl:         'http://ts1.travian.com/'
    ac:              'asdsteven'
    pw:              '25183771'
]

app = express()
app.set 'views', './'
app.set 'view engine', 'jade'
app.engine 'jade', require('jade').__express

app.get '/stop', (req, res) ->
  travian[0].stop()
  res.send 'ok'

app.get '/start', (req, res) ->
  travian[0].start()
  res.send 'ok'

app.get '/run', (req, res) ->
  travian[0].run()
  res.send 'ok'

app.get '/', (req, res) ->
  res.render 'index',
    log:     fs.readFileSync 'log1.txt', encoding: 'utf-8'

app.listen port, ipaddress

