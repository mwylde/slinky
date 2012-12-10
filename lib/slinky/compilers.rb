require 'set'

module Slinky
  EXTENSION_REGEX = /(.+)\.(\w+)/
  
  class Compilers
    @compilers = []
    @compilers_by_ext = {}
    @compilers_by_input = {}
    @checked_dependencies = Set.new

    DEPENDENCY_NOT_MET = "Missing dependency %s (version %s), which is\n" +
      "necessary to compile %s files\n\n" +
      "Running the following should rectify this problem:\n" +
      "  $ gem install --version '%s' %s"

    class << self
      def register_compiler klass, options
        options[:klass] = klass
        @compilers << options
        options[:outputs].each do |output|
          @compilers_by_ext[output] ||= []
          @compilers_by_ext[output] << options
        end
        options[:inputs].each do |input|
          @compilers_by_input[input] = options
        end
      end

      def get_cfile source, compiler, input_ext, output_ext
        if has_dependencies compiler, input_ext
          CompiledFile.new source, compiler[:klass], output_ext
        end
      end

      def has_dependencies compiler, ext
        (compiler[:dependencies] || []).all? {|d|
          if @checked_dependencies.include?(d)
            true
          else
            begin
              gem(d[0], d[1])
              require d[0]
              @checked_dependencies.add(d)
              true
            rescue Gem::LoadError
              $stderr.puts (DEPENDENCY_NOT_MET % [d[0], d[1], ext, d[1], d[0]]).foreground(:red)
              false
            end
          end
        }
      end
      
      # Produces a CompiledFile for an input file if the file needs to
      # be compiled, or nil otherwise. Note that path is the path of
      # the compiled file, so script.js not script.coffee.
      def cfile_for_request path
        _, file, extension = path.match(EXTENSION_REGEX).to_a

        compilers = @compilers_by_ext

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
                cfile = get_cfile(files_by_ext[i], c, ext, extension)
                break
              end
            end
            break if cfile
          end
          cfile
        else
          nil
        end
      end

      # Like cfile_for_request, but for the actual file to be compiled
      # (so script.coffee, not script.js).
      def cfile_for_file path
        _, file, ext = path.match(EXTENSION_REGEX).to_a

        if ext && ext != "" && compiler = @compilers_by_input[ext]
          get_cfile(path, compiler, ext, compiler[:outputs].first)
        else
          nil
        end
      end
    end
  end
end
