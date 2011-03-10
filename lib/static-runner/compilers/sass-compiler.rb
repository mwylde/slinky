module StaticRunner
  class SassCompiler
    Runner.register_compiler SassCompiler,
      :handles => ["css"],
      :extensions => ["sass", "scss"]

    def compile file to
      %Q?sass "#{file}:#{to}"?
    end
  end
end
