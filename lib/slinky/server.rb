module Slinky
  module Server
    include EM::HttpServer

    INJECT_CSS = File.read("#{File.dirname(__FILE__)}/templates/inject.css")
    ERROR_CSS = File.read("#{File.dirname(__FILE__)}/templates/error.css")
    ERROR_HAML = File.read("#{File.dirname(__FILE__)}/templates/error.haml")
    ERROR_JS = File.read("#{File.dirname(__FILE__)}/templates/error.js")

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

    def self.process_path resp, path, pushstate = false
      file = manifest.find_by_path(path).first

      if file.is_a? ManifestDir
        file = manifest.find_by_path(path + "/index.html").first
        path += "/index.html"
      end

      if file
        # They're requesting the source file and we should not
        # compile it (but still process directives)
        compile = !(file.source.end_with?(path) && file.source)
        handle_file(resp, file, compile)
      elsif !pushstate && p = config.pushstate_for_path("/" + path)
        path = p[0] == "/" ? p[1..-1] : p
        self.process_path(resp, path, true)
      else
        not_found resp
      end

      type = MIME::Types.type_for(path).first.to_s
      if resp.content.encoding.to_s == "UTF-8"
        type += "; charset=utf-8"
      end

      resp.content_type type

      resp
    end

    # Produces nice error output for various kinds of formats
    def self.format_error_output resp, mf, error
      resp.content =
        case Pathname.new(mf.output_path).extname
        when ".html"
          Haml::Engine.new(ERROR_HAML).
            render(Object.new, errors: error.messages, css: ERROR_CSS)
        when ".css"
          resp.status = 200 # browsers ignore 500'd css
          INJECT_CSS.gsub("{REPLACE_ERRORS}",
                          error.messages.join("\n").gsub("'", "\""))
        when ".js"
          resp.status = 200 # browsers ignore 500'd js
          ERROR_JS
            .gsub("{REPLACE_CSS}",
                  JSON.dump({css: ERROR_CSS.gsub("\n", "")}))
            .gsub("{REPLACE_ERRORS}", JSON.dump(error.messages))
        else
          error.message
        end
    end

    # Takes a manifest file and produces a response for it
    def self.handle_file resp, mf, compile = true
      begin
        path = mf.process(nil, compile)
        serve_file resp, path.to_s
      rescue SlinkyError => e
        resp.status = 500
        if self.config.enable_browser_errors
          format_error_output(resp, mf, e)
        else
          resp.content = e.message
        end
        e.messages.each{|m|
          $stderr.puts(m.foreground(:red))
        }
      rescue => e
        resp.status = 500
        format_error_output(resp, mf, SlinkyError.new(
                              "Unknown error handling #{mf.source}: #{$!}\n"))
        $stderr.puts("Unknown error handling #{mf.source}: #{$!}".foreground(:red))
      end
      resp
    end

    # Serves a file from the file system
    def self.serve_file resp, path
      if File.exists?(path) && !File.directory?(path)
        size = File.size(path)
        _, _, extension = path.match(EXTENSION_REGEX).to_a
        # File reading code from rack/file.rb
        File.open(path, "rb") do |file|
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
  end
end
