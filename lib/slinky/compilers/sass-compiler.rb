module Slinky
  module SassCompiler
    Compilers.register_compiler self,
      :inputs => ["sass", "scss"],
      :outputs => ["css"],
      :dependencies => [["sass", ">= 3.1.1"]]

    def SassCompiler::compile s, file
      sass_engine = Sass::Engine.new(s, :load_paths => [File.dirname(file)])
      sass_engine.render
    end
  end
end
