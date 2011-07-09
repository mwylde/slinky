module Slinky
  # Stores information about compiled files, including location,
  # source file and last modified time
  class CompiledFile
    attr_accessor :source, :print_name, :output_path
    attr_reader :last_compiled, :output_ext
    
    # Creates a new CompiledFile, compiling the provided source file
    # with the provided compiler class.
    def initialize source, compiler, output_ext
      super source
      @source = source
      @compiler = compiler
      @last_compiled = Time.new(0)
      @output_ext = output_ext
    end

    def build path
      compiler_compile path, EM::DefaultDeferrable
    end

    # Compiles the source file to a temporary location
    def compile &cb
      path = @output_path || tmp_path
      @last_compiled = Time.now
      if @compiler.respond_to? :compile
        compiler_compile path, cb
      else
        compile_failed "invalid compiler"
        cb.call @output_path, nil, nil, "invalid compiler"
        # compiler_command path, cb
      end
    end

    def compiler_compile path, cb
      begin
        out = File.open @source do |f|
          s = f.read.gsub(BUILD_DIRECTIVES, "")
          out = @compiler.compile s, @source
        end
        
        compile_succeeded
        @output_path = path
        File.open(path, "w+") do |f|
          f.write out
        end
      rescue
        compile_failed $!
      end
      cb.call @output_path, nil, nil, $! 
    end

    # def compiler_command path, cb
    #   #NOTE: This currently won't strip out compiler directives, so
    #   #use at own risk. Ideally all compilers would have ruby version
    #   #so we don't have to use this
    #   command = @compiler.command @source, path

    #   EM.system3 command do |stdout, stderr, status|
    #     if status.exitstatus != 0
    #       compile_failed stderr.strip
    #     else
    #       compile_succeeded
    #       @output_path = path
    #     end
    #     cb.call(@output_path, status, stdout, stderr)
    #   end
    # end

    def name
      @print_name || @source
    end

    def compile_succeeded
      puts "Compiled #{name}".foreground(:green)
    end

    def compile_failed e
      $stderr.write "Failed on #{name}: #{e}\n".foreground(:red)
    end

    # Calls the supplied callback with the path of the compiled file,
    # compiling the source file first if necessary.
    def file &cb
      if needs_update?
        compile &cb
      else
        cb.call @output_path, nil, nil, nil
      end
    end

    # Returns whether the source file has changed since it was last
    # compiled.
    def needs_update?
      return true if @compiler.to_s.match "SassCompiler"
      File.new(source).mtime > @last_compiled
    end

    private
    def tmp_path
      Tempfile.new("slinky").path + "." + @output_ext
    end
  end
end
