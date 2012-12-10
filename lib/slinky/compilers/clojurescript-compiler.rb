module Slinky
  module ClojureScriptCompiler
    Compilers.register_compiler self,
    :inputs => ["cljs"],
    :outputs => ["js"],
    :dependencies => [["clementine", "~> 0.0.3"]]

    def ClojureScriptCompiler::compile s, file
      # Clementine.options[:pretty_print] = true
      # Clementine.options[:optimizations] = :none
      @engine ||= Clementine::ClojureScriptEngine.new(file,
                                          :pretty_print => true,
                                          :optimizations => :none,
                                          :output_dir => Dir.tmpdir)
      @engine.compile
    end
  end
end
