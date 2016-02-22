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

      puts "PATH: #{File.absolute_path(File.dirname(file))}"

      # we need to compile using the correct working dir
      # Dir.chdir(File.absolute_path(File.dirname(file))) {
        # compiles a TypeScript source code string and returns String
        TypeScript::Node.compile_file(file, '--target', 'ES5').js
      #}
    end
  end
end
