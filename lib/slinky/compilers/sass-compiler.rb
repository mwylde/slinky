require 'sass'

module Slinky
  module SassCompiler
    Server.register_compiler self,
      :inputs => ["sass", "scss"],
      :outputs => ["css"]

    def SassCompiler::compile file
      s = File.read(file)
      sass_engine = Sass::Engine.new(s, :load_paths => [File.dirname(file)])
      sass_engine.render
    end
  end
end
