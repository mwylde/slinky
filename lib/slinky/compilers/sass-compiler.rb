module Slinky
  module SassCompiler
    Compilers.register_compiler self,
                                :inputs => ["sass", "scss"],
                                :outputs => ["css"],
                                :dependencies => [["sass", ">= 3.1.1"]],
                                :requires => ["sass"]

    def SassCompiler::compile s, file
      syntax = file.end_with?(".sass") ? :sass : :scss
      if Pathname.new(file).basename.to_s.start_with?("_")
        # This is a partial, don't render it
        ""
      else
        sass_engine = Sass::Engine.new(s,
                                     :syntax => syntax,
                                     :load_paths => [File.dirname(file)])
        sass_engine.render
      end
    end
  end
end
