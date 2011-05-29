require 'coffee-script'

module Slinky
  module CoffeeCompiler
    Compilers.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"]

    def CoffeeCompiler::compile s, file
      CoffeeScript::compile(s)
    end
  end
end
