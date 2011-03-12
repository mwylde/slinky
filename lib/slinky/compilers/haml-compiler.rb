module Slinky
  module HamlCompiler
    Server.register_compiler self,
    :inputs => ["haml"],
    :outputs => ["html"]
    
    def HamlCompiler::command from, to
      %Q?haml "#{from}" "#{to}"?
    end
  end
end
