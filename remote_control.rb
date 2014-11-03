require 'json'

require 'sinatra/base'
require 'sinatra/cross_origin'

class RemoteControl < Sinatra::Base
  register Sinatra::CrossOrigin

  set :server, :thin
  set :connections, {}

  set :allow_origin, 'http://localhost:4000'
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
      settings.connections.store(key, Connection.new(out))
      out.errback { puts out; settings.connections.delete(key) }
    }
  end

  options '/connections/:key' do
    puts '//////', params
    halt 200
  end

  post '/connections/:key', provides: :json do |key|
    return [404, {}, 'no connection for key'] unless settings.connections[key]
    settings.connections[key].write request.body.read
    {status: 'message received', key: key}.to_json
  end

  class Connection
    def initialize(out)
      @out = out
    end

    def closed?
      @out.closed?
    end

    def write(data)
      @out << format(data)
    end

    def format(data)
      "data: #{data}\n\n"
    end

  end
end
