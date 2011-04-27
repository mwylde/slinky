require 'coffee-script'

module Slinky
  module CoffeeCompiler
    Server.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"]

    def CoffeeCompiler::compile s, file
      CoffeeScript::compile(s)
    end
  end
end
