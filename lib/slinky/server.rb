module Slinky
  class Server < EventMachine::Connection
    include EM::HttpServer

    # Creates a new Slinky::Server
    #
    # @param String dir The directory from which files will be served
    def initialize dir = "."
      super
      @manifest = Manifest.new(dir)
    end

    # Splits a uri into its components, returning only the path sans
    # initial forward slash.
    def self.path_for_uri uri
      _, _, _, _, _, path, _, _  = URI.split uri
      path[1..-1] #get rid of the leading /
    end

    # Takes a manifest file and produces a response for it
    def self.handle_file resp, mf
      if mf
        if path = mf.process
          serve_file resp, path.to_s
        else
          resp.status = 500
          resp.content = "Error compiling #{mf.source}"
        end
      else
        not_found resp
      end
      resp
    end

    # Serves a file from the file system
    def self.serve_file resp, path
      if File.exists?(path) && !File.directory?(path)
        size = File.size(path)
        _, _, extension = path.match(EXTENSION_REGEX).to_a
        resp.content_type MIME::Types.type_for(path).first
        # File reading code from rack/file.rb
        File.open path do |file|
          resp.content = ""
          while size > 0
            part = file.read([8192, size].min)
            break unless part
            size -= part.length
            resp.content << part
          end
        end
      else
        not_found resp
      end
    end

    # Returns the proper responce for files that do not exist
    def self.not_found resp
      resp.status = 404
      resp.content = "File not found"
    end

    # Method called for every HTTP request made 
    def process_http_request
      path = Server.path_for_uri(@http_request_uri)
      file = @manifest.find_by_path(path)
      resp = EventMachine::DelegatedHttpResponse.new(self)
      if file.is_a? ManifestDir
        file = @manifest.find_by_path(path+"/index.html")
      end
      Server.handle_file(resp, file).send_response
    end
  end
end
