require 'coffee-script'

module Slinky
  module CoffeeCompiler
    Compilers.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"],
    :dependencies => [["coffee-script", ">= 2.2.0"]]

    def CoffeeCompiler::compile s, file
      CoffeeScript::compile(s)
    end
  end
end
