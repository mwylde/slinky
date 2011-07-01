module Slinky
  CONTENT_TYPES = {
    'html' => 'text/html',
    'js' => 'application/x-javascript',
    'css' => 'text/css'
  }

  class Server < EventMachine::Connection
    include EM::HttpServer

    @files = {}

    def initialize dir = "."
      super
      @manifest = Manifest.new(dir)
    end
    
    def files
      self.class.instance_variable_get(:@files)
    end
    
    def process_http_request
      @resp = EventMachine::DelegatedHttpResponse.new(self)

      _, _, _, _, _, path, _, query  = URI.split @http_request_uri
      path = path[1..-1] #get rid of the leading /

      # Check if we've already seen this file. If so, we can skip a
      # bunch of processing.
      if files[path]
        serve_compiled_file files[path]
        return
      end

      if cfile = Compilers.cfile_for_file(path)
        files[path] = cfile
        serve_compiled_file cfile
      else
        serve_file path
      end
    end

    def serve_compiled_file cfile
      cfile.file do |path, status, stdout, stderr|
        if path
          serve_file path
        else
          puts "Status: #{status.inspect}"
          @resp.status = 500
          @resp.content = "Error compiling #{cfile.source}:\n #{stdout}"
          @resp.send_response
        end
      end
    end

    def serve_file path
      if File.exists?(path) && size = File.size?(path)
        _, _, extension = path.match(EXTENSION_REGEX).to_a
        @resp.content_type CONTENT_TYPES[extension]
        # File reading code from rack/file.rb
        File.open path do |file|
          @resp.content = ""
          while size > 0
            part = file.read([8192, size].min)
            break unless part
            size -= part.length
            @resp.content << part
          end
        end
        @resp.send_response
      else
        @resp.status = 404
        @resp.content = "File '#{path}' not found."
        @resp.send_response
      end
    end
  end
end
