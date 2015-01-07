require 'json'

require 'sinatra/base'
require 'sinatra/cross_origin'

class RemoteControl < Sinatra::Base
  register Sinatra::CrossOrigin

  set :server, :thin
  set :connections, {}

  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, false
  set :max_age, "1728000"
  set :expose_headers, ['Content-Type']
  set :allow_headers, ['*', 'X-Requested-With', 'X-HTTP-Method-Override', 'Content-Type', 'Cache-Control', 'Accept', 'AUTHORIZATION']
  set :threaded, true

  configure do
    set :allow_origin, proc { environment == :production ? 'http://zampino.github.io' : 'http://localhost:4000' }
    enable :cross_origin
    enable :logging
  end

  get '/' do
    "origin: #{settings.allow_origin}<br />env: #{settings.environment}<br />threaded: #{settings.threaded}<br />connections: <br />#{settings.connections.keys.join('<br />')}"
  end

  get '/connections/:key', provides: 'text/event-stream' do |key|
    stream(:keep_open) { |out|
      settings.connections.store(key, Connection.new(key, out, logger))

      out.callback {
        logger.info "[CLOSE]: #{key}"
        settings.connections.delete(key)
      }

      out.errback {
        logger.error "[ERROR]: #{key}"
        settings.connections.delete(key)
      }
    }
  end

  options '/connections/:key' do
    halt 200
  end

  post '/connections/:key', provides: :json do |key|
    return [404, {}, {message: "no connection for key: #{key}"}.to_json] unless settings.connections[key]
    settings.connections[key].write request.body.read
    {status: 'message received', key: key}.to_json
  end

  class Connection
    def initialize(key, out, logger)
      @key = key
      @out = out
      @logger = logger
      handshake
    end

    def handshake
      @logger.info "[HANDSHAKE]: #{@key}"
      @out << "retry: 1000\nid: #{@key}\nevent: handshake\ndata: connected #{@key}\n\n"
    end

    def closed?
      @out.closed?
    end

    def write(data)
      @logger.info "[DATA]: #{data}"
      @out << data(data)
    end

    def data(data)
      "data: #{data}\n\n"
    end

  end
end
