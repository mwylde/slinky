module Slinky
  module LessCompiler
    Compilers.register_compiler self,
                                :inputs => ["less"],
                                :outputs => ["css"],
                                :dependencies => [["less", ">= 2.2.0"]]
    require 'less'

    def LessCompiler::compile s, file
      parser = Less::Parser.new
      tree = parser.parse(s)
      tree.to_css
    end
  end
end
