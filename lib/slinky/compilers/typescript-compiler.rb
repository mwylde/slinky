module Slinky
  module TypescriptCompiler
    Compilers.register_compiler self,
                                :inputs => ["ts"],
                                :outputs => ["js"],
                                :dependencies => [["typescript-node", "~> 1.6.0"]],
                                :requires => ["typescript-node"]

    def TypescriptCompiler::compile s, file
      # Raises an error if node is not available
      TypeScript::Node.check_node

      # compiles a TypeScript source code string and returns String
      TypeScript::Node.compile(s, '--target', 'ES5')
    end
  end
end
