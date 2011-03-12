module Slinky
  module CoffeeCompiler
    Server.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"]
    
    def CoffeeCompiler::command from, to
      root = File.dirname(__FILE__)
      %Q?#{root}/coffee-helper "#{from}" "#{to}"?
    end
  end
end
