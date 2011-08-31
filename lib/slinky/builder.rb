module Slinky
  class Builder
    def self.build dir, build_dir, config
      manifest = Manifest.new(dir, config, :build_to => build_dir, :devel => false)
      manifest.build
    end
  end
end
