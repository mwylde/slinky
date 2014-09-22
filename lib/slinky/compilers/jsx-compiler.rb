module Slinky
  module JSXCompiler
    Compilers.register_compiler self,
                                :inputs => ["jsx"],
                                :outputs => ["js"],
                                :dependencies => [["react-jsx", "~> 0.8.0"]],
                                :requires => ["react/jsx"]

    def JSXCompiler::compile s, file, options = {}
      React::JSX.compile(s)
    end
  end
end
