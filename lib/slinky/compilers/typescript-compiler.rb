require 'tempfile'

module Slinky
  module TypescriptCompiler
    Compilers.register_compiler self,
                                :inputs => ["ts"],
                                :outputs => ["js"]

    def TypescriptCompiler::compile s, file
      f = Tempfile.new("tsc")
      begin
        f.close
        output = `tsc --out #{f.path} #{file}`
        if output && output.strip != ""
          raise Exception.new(output.strip)
        end

        return File.read(f.path)
      ensure
        f.unlink
      end
    end
  end
end
