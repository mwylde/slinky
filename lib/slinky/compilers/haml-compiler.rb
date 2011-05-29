require 'haml'

module Slinky
  module HamlCompiler
    Compilers.register_compiler self,
    :inputs => ["haml"],
    :outputs => ["html"]

    def HamlCompiler::compile s, file
      haml_engine = Haml::Engine.new(s)
      haml_engine.render
    end    
  end
end
