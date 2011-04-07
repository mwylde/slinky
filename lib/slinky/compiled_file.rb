module Slinky
  # Stores information about compiled files, including location,
  # source file and last modified time
  class CompiledFile
    attr_reader :source, :last_compiled

    # Creates a new CompiledFile, compiling the provided source file
    # with the provided compiler class.
    def initialize source, compiler, output_ext
      @source = source
      @compiler = compiler
      @last_compiled = Time.new(0)
      @output_ext = output_ext
    end

    # Compiles the source file to a temporary location
    def compile &cb
      path = @path || tmp_path

      command = @compiler.command @source, path

      EM.system3 command do |stdout, stderr, status|
        @last_compiled = Time.now
        if status.exitstatus != 0
          $stderr.write "Failed on #{@source}: #{stderr.strip}\n".foreground(:red)
        else
          puts "Compiled #{@source}".foreground(:green)
          @path = path
        end
        cb.call(@path, status, stdout, stderr)
      end
    end

    # Calls the supplied callback with the path of the compiled file,
    # compiling the source file first if necessary.
    def file &cb
      if needs_update?
        compile &cb
      else
        cb.call @path, nil, nil, nil
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
