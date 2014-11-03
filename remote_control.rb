require 'json'

require 'sinatra/base'
require 'sinatra/cross_origin'

class RemoteControl < Sinatra::Base
  register Sinatra::CrossOrigin

  set :server, :thin
  set :connections, {}

  set :allow_origin, 'http://zampino.github.io'
  set :allow_methods, [:get, :post, :options]
  set :allow_credentials, false
  set :max_age, "1728000"
  set :expose_headers, ['Content-Type']
  set :allow_headers, ['*', 'X-Requested-With', 'X-HTTP-Method-Override', 'Content-Type', 'Cache-Control', 'Accept', 'AUTHORIZATION']

  configure do
    enable :cross_origin
  end

  get '/' do
    "ok, connections: #{settings.connections.keys.join('<br />')}"
  end

  get '/connections/:key', provides: 'text/event-stream' do |key|
    stream(:keep_open) { |out|
      settings.connections.store(key, Connection.new(key, out))
      out.errback { settings.connections.delete(key) }
    }
  end

  options '/connections/:key' do
    puts '//////', params
    halt 200
  end

  post '/connections/:key', provides: :json do |key|
    return [404, {}, {message: "no connection for key: #{key}"}.to_json] unless settings.connections[key]
    settings.connections[key].write request.body.read
    {status: 'message received', key: key}.to_json
  end

  class Connection
    def initialize(key, out)
      @key = key
      @out = out
      handshake
    end

    def handshake
      puts '[HANDSHAKE]:', @key
      @out << "retry: 1000\nid: #{@key}\nevent: handshake\ndata: connected #{@key}\n\n"
    end

    def closed?
      @out.closed?
    end

    def write(data)
      puts '[DATA]:', data
      @out << data(data)
    end

    def data(data)
      "data: #{data}\n\n"
    end

  end
end
