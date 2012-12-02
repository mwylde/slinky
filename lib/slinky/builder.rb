module Slinky
  class Builder
    def self.build options, config
      dir = options[:src_dir]
      build_dir = options[:build_dir]
      manifest = Manifest.new(dir, config,
                              :build_to => build_dir,
                              :devel => false,
                              :no_minify => options[:no_minify])
      begin
        manifest.build
      rescue BuildFailedError
        $stderr.puts "Build failed"
      end
    end
  end
end
