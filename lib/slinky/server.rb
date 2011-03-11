module Slinky
  class Server < EventMachine::Connection
    include EM::HttpServer

    @compilers = []
    @compilers_by_ext = {}


    @files = {}

    class << self
      def register_compiler klass, options
        options[:klass] = klass
        @compilers << options
        options[:outputs].each do |output|
          @compilers_by_ext[output] ||= []
          @compilers_by_ext[output] << options
        end
      end

      def compilers_by_ext
        @compilers_by_ext
      end
    end

    def files
      self.class.instance_variable_get(:@files)
    end
    
    EXTENSION_REGEX = /(^[\w\d\:\/\.]*)\.(\w+)/
    def process_http_request
      @resp = EventMachine::DelegatedHttpResponse.new(self)

      _, _, _, _, _, path, _, query  = URI.split @http_request_uri
      path = path[1..-1] #get rid of the leading /
      _, file, extension = path.match(EXTENSION_REGEX).to_a

      compilers = self.class.compilers_by_ext

      # Check if we've already seen this file. If so, we can skip a
      # bunch of processing.
      if files[path]
        serve_compiled_file files[path]
        return
      end
      
      # if there's a file extension and we have a compiler that
      # outputs that kind of file, look for an input with the same
      # name and an extension in our list
      if extension && extension != "" && compilers[extension]
        files_by_ext = {}
        # find possible source files
        Dir.glob("#{file}.*").each do |f|
          _, _, ext = f.match(EXTENSION_REGEX).to_a
          files_by_ext[ext] = f
        end

        cfile = nil
        # find a compiler that outputs the request kind of file and
        # which has an input file type that exists on the file system
        compilers[extension].each do |c|
          c[:inputs].each do |i|
            if files_by_ext[i]
              cfile = CompiledFile.new files_by_ext[i], c[:klass]
              files[path] = cfile
              break
            end
          end
          break if cfile
        end

        if cfile
          serve_compiled_file cfile
        else
          serve_file path
        end
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
      if File.exists? path
        size = File.size? path
        if true || size < EventMachine::FileStreamer::MappingThreshold
          s = File.open(path).read
          @resp.content = s
          @resp.send_response
        else
          stream_file_data path do
            @resp.send_headers
            @resp.send_trailer
          end
        end
      else
        @resp.status = 404
        @resp.content = "File '#{path}' not found."
        @resp.send_response
      end
    end
  end
end
