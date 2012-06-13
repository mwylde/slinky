module Slinky
  class Builder
    def self.build dir, build_dir, config
      manifest = Manifest.new(dir, config, :build_to => build_dir, :devel => false)
      begin
        manifest.build
      rescue BuildFailedError
        $stderr.puts "Build failed"
      end
    end
  end
end
