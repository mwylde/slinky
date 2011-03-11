module Slinky
  class Server < EventMachine::Connection
    include EM::HttpServer

    @compilers = []
    @compilers_by_ext = {}

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
    
    EXTENSION_REGEX = /(^[\w\d\:\/\.]*)\.(\w+)/
    def process_http_request
      @resp = EventMachine::DelegatedHttpResponse.new(self)

      _, _, _, _, _, path, _, query  = URI.split @http_request_uri
      _, file, extension = path.match(EXTENSION_REGEX).to_a
      # dir = path.match(/(.+)^[\/].+/)[1] rescue ""
      puts "Matching #{path}"
      puts "Extension: '#{extension}'"

      compilers = self.class.compilers_by_ext
      
      # if there's a file extension and we have a compiler that
      # outputs that kind of file, look for an input with the same
      # name and an extension in our list
      if extension && extension != "" && compilers[extension]
        files_by_ext = {}
        Dir.glob("#{file[1..-1]}.*").each do |f|
          _, _, ext = f.match(EXTENSION_REGEX).to_a
          files_by_ext[ext] = f
        end

        compiler = nil
        input = nil
        compilers[extension].each do |c|
          c[:inputs].each do |i|
            if files_by_ext[i]
              compiler = c
              input = files_by_ext[i]
              break
            end
          end
          break if compiler
        end

        if compiler
          compile input, path[1..-1], compiler
        else
          puts "Trying to get compiled file, but no source"
          serve_file path[1..-1]
        end
      else
        puts "Serving static file #{path}."
        serve_file path[1..-1]
      end
    end

    def compile from, to, compiler
      command = compiler[:klass].command from, to

      puts "Running command '#{command}'"

      EM.system3 command do |stdout, stderr, status|
        if status.exitstatus != 0
          $stderr.write "Failed on #{from}: #{stderr.strip}\n"
        else
          puts "Compiled #{from}"
          serve_file to
        end
      end
    end

    def serve_file path
      if File.exists? path
        puts "File exists: '#{path}'"

        send_file_data path do
          @resp.send_headers
          @resp.send_trailer
        end
      else
        @resp.status = 404
        @resp.content = "File '#{path}' not found."
        @resp.send_response
      end
    end
  end
end
