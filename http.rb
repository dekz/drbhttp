require 'drb/drb'
require 'base64'
require 'stringio'
require 'uri'
require 'net/http'
$drb_debug = false

module DRb
  class DRbHTTP < DRbTCPSocket
    def set_sockopt(*args); end;
    def initialize(uri, soc, config={})
      super(uri, soc, config)
    end

    def accept
      log "accept"
      while true
        s = @socket.accept
        break if (@acl ? @acl.allow_socket?(s) : true)
        s.close
      end
      self.class.new(@uri, s, @config)
    end

    def self.open_server(uri, config)
      require 'webrick'
      host, port = parse_uri(uri)
      soc = TCPServer.open(host, port)
      config[:tcp_port] = port
      #config[:web_server] = @ws
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
      #http = Net::HTTP.start(uri.host, uri.port)
      http = Net::HTTP.new(host, port)
      soc = nil
      soc = http.instance_eval do
        @socket
      end
      return [http, soc]
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
     log 'send_req'
      io = StringIO.new
      @msg.send_request(io, ref, msg_id, arg, b)
      io.rewind
      msg = io.read
      log({ :marshal_dump => msg })
      enc_msg = Base64.strict_encode64(msg)
      log({ :enc_msg => enc_msg })

      host, port = self.class.parse_uri(@uri)

      http = Net::HTTP.new(host, port)
      post = Net::HTTP::Post.new('/')
      post.body = enc_msg
      @resp = http.request post
    end

    def recv_reply
     log 'recv_reply'
      msg = Base64.strict_decode64(@resp.body)
      log msg
      @resp = nil
      io = StringIO.new
      io.write msg
      io.rewind
      @msg.recv_reply(io)
    end

    def send_reply(succ, result)
     log 'send_reply'
    #begin
      res = WEBrick::HTTPResponse.new http_config
    #rescue Exception => e
    #  puts e
    #  puts e.backtrace
    #end
      io = StringIO.new
      @msg.send_reply(io, succ, result)
      io.rewind
      result = io.read
      log result
      result = Base64.strict_encode64 result
      res.body = result
      #log res
      #log result
      res.send_response(@socket)
    end

    def recv_request
     log 'recv_request'
      body = ''
      #begin
        req = WEBrick::HTTPRequest.new http_config
        req.parse(@socket)
        body = req.body
     # rescue Exception => e
     #   puts e
     #   puts e.backtrace
     #   raise e
     # end
      msg = Base64.strict_decode64(body) rescue ''
      return msg if msg.empty?
      log msg
      io = StringIO.new
      io.write msg
      io.rewind
      z = @msg.recv_request io
      z
    end

    def log *args
      puts"#{caller[0]}: #{args}" if $drb_debug
    end

    def http_config
      host, port = self.class.parse_uri(uri)
      WEBrick::Config::General.merge({
        :Port => port,
        :BindAddress => host,
        :Logger => WEBrick::Log::new,
        :InputBufferSize => 1024,
        :HTTPVersion => "1.1",
      })
    end

#    def alive?
#      false
#    end

  end
  DRbProtocol.add_protocol(DRbHTTP)
end
