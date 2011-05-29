module Slinky
  module HamlCompiler
    Compilers.register_compiler self,
    :inputs => ["haml"],
    :outputs => ["html"]
    
    def HamlCompiler::command from, to
      %Q?haml "#{from}" "#{to}"?
    end
  end
end
