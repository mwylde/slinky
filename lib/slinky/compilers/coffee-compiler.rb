require 'coffee-script'

module Slinky
  module CoffeeCompiler
    Server.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"]

    def CoffeeCompiler::compile file
      s = File.read(file)
      CoffeeScript::compile(s)
    end
  end
end
