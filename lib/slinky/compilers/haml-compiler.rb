require 'haml'

module Slinky
  module HamlCompiler
    Compilers.register_compiler self,
    :inputs => ["haml"],
    :outputs => ["html"]

    def HamlCompiler::compile file
      s = File.read(file)
      haml_engine = Haml::Engine.new(s)
      haml_engine.render
    end    
  end
end
