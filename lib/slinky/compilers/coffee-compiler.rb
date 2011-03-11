module Slinky
  module CoffeeCompiler
    Server.register_compiler self,
    :inputs => ["coffee"],
    :outputs => ["js"]
    
    def CoffeeCompiler::command from, to
      dir = to.split('/')[0..-2].join('/')
      %Q?coffee --compile --output "#{dir}" "#{from}"?
    end
  end
end
