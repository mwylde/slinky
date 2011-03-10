require 'eventmachine'
require 'em-http-server'

module StaticRunner
  class Runner
    class << self
      @compilers = []
      @compilers_by_extension = {}
      def register_compiler klass, options
        @compilers << options
      end
    end
    
    def run
      EM::run {
        EM::start_server "0.0.0.0", 5323, Server
        puts "Started static file server on port 5323"
      }
    end
  end
  
  class Server < EventMachine::Connection
    def process_http_request
      resp = EventMachine::DelegatedHttpResponse.new(self)
      extension = @http_request_url.match(/^[\w\d\:\/\.]+\.(\w+)\?[\w\W]*?$/)[1]
      case extension
        when "html" then handle_html resp
        when "css" then handle_css resp
        when "js" then handle_js resp
        else static_serve resp
      end
    end

    def static_serve resp
      
    end
  end
end
