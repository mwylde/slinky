module Slinky
  module Server
    include EM::HttpServer

    # Sets the root directory from which files should be served
    def self.dir= _dir; @dir = _dir; end
    # Gets the root directory from which files should be served
    def self.dir; @dir || "."; end

    def self.config= _config; @config = _config; end
    def self.config; @config || ConfigReader.empty; end

    def self.manifest= _manifest; @manifest = _manifest; end
    def self.manifest; @manifest; end

    # Splits a uri into its components, returning only the path sans
    # initial forward slash.
    def self.path_for_uri uri
      _, _, _, _, _, path, _, _  = URI.split uri
      path[1..-1] #get rid of the leading /
    end

    # Takes a manifest file and produces a response for it
    def self.handle_file resp, mf, pushstate = false
      if mf
        if path = mf.process
          serve_file resp, path.to_s
        else
          resp.status = 500
          resp.content = "Error compiling #{mf.source}\n"
        end
      elsif !pushstate && p = config.pushstate_index
        path = p[0] == "/" ? p[1..-1] : p
        self.process_path(resp, path, true)
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

    # Returns the proper response for files that do not exist
    def self.not_found resp
      resp.status = 404
      resp.content = "File not found\n"
    end

    def self.process_path resp, path, pushstate = false
      file = manifest.find_by_path(path).first
      if file.is_a? ManifestDir
        file = manifest.find_by_path(path+"/index.html").first
      end

      resp.content_type MIME::Types.type_for(path).first
      handle_file(resp, file, pushstate)
    end

    # Method called for every HTTP request made 
    def process_http_request
      resp = EventMachine::DelegatedHttpResponse.new(self)

      begin
        path = Server.path_for_uri(@http_request_uri)
      rescue
        resp.status = 500
        resp.content = "Invalid request"
        return
      end

      Server.process_path(resp, path).send_response
    end
  end
end
