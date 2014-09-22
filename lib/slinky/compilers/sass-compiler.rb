module Slinky
  module SassCompiler
    Compilers.register_compiler self,
                                :inputs => ["sass", "scss"],
                                :outputs => ["css"],
                                :dependencies => [["sass", ">= 3.1.1"]],
                                :requires => ["sass"]

    def SassCompiler::compile s, file, options = {}
      syntax = file.end_with?(".sass") ? :sass : :scss

      default_options = {
        :syntax => syntax,
        :load_paths => [File.dirname(file)]
      }

      compile_options = default_options.merge(options)

      if Pathname.new(file).basename.to_s.start_with?("_")
        # This is a partial, don't render it
        ""
      else
        sass_engine = Sass::Engine.new(s, compile_options)
        sass_engine.render
      end
    end
  end
end
