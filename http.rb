require 'drb/drb'
require 'base64'
require 'stringio'
require 'uri'
require 'net/http'

module DRb
  class DRbHTTP < DRbTCPSocket
    def set_sockopt(*args); end;
    def initialize(uri, soc, config={})
      super(uri, soc, config)
    end

    def self.open_server(uri, config)
      require 'webrick'
      host, port = parse_uri(uri)
      @ws = WEBrick::HTTPServer::new(:Port => port)
      soc = nil
      soc = @ws.instance_eval do
        @listeners[0]
      end
      config[:tcp_port] = port
      config[:web_server] = @ws
      uri = "drbhttp://#{host}:#{port}"
      self.new(uri, soc, config)
    end

    # Open a client to server
    def self.open(uri, config)
      host, port = parse_uri(uri)
      http, soc = new_request(host, port)
      config[:net_http] = http
      self.new(uri, soc, config)
    end

    def self.new_request(host, port)
      uri = URI("http://#{host}:#{port}")
      http = Net::HTTP.start(uri.host, uri.port)
      soc = nil
      soc = http.instance_eval do
        @socket
      end
      return [http, soc]
    end

    def close
      super
    end

    def self.parse_uri(uri)
      if /^drbhttp:\/\/(.*?):(\d+)(\?(.*))?$/ =~ uri
        host = $1
        port = $2.to_i
        option = $4
        [host, port, option]
      else
        raise(DRbBadScheme, uri) unless uri =~ /^drbhttp:/
        raise(DRbBadURI, 'can\'t parse uri:' + uri)
      end
    end

    def self.uri_option(uri, config)
      config = config.update({ :verbose => true })
      host, port, option = parse_uri(uri)
      return "drbhttp://#{host}:#{port}", option
    end

    def send_request(ref, msg_id, arg, b)
      io = StringIO.new
      @msg.send_request(io, ref, msg_id, arg, b)
      io.rewind
      msg = io.read
      enc_msg = Base64.strict_encode64(msg)

      host, port = self.class.parse_uri(@uri)
      http, soc = self.class.new_request(host, port)
      @socket = soc
      @resp = http.request_post '/', enc_msg
    end

    def recv_reply
      msg = Base64.strict_decode64(@resp.body)
      @resp = nil
      io = StringIO.new
      io.write msg
      io.rewind
      @msg.recv_reply(io)
    end

    def send_reply(succ, result)
      res = WEBrick::HTTPResponse.new @config[:web_server].config
      io = StringIO.new
      @msg.send_reply(io, succ, result)
      io.rewind
      result = io.read
      result = Base64.strict_encode64 result
      res.body = result
      p result
      res.send_response(@socket)
    end

    def recv_request
      req = WEBrick::HTTPRequest.new @config[:web_server].config
      req.parse(@socket)
      msg = Base64.strict_decode64(req.body)
      io = StringIO.new
      io.write msg
      io.rewind
      z = @msg.recv_request io
      p z
      z
    end

    def close
      puts 'close'
    end

    def alive?
      false
    end

  end
  DRbProtocol.add_protocol(DRbHTTP)
end
