module Slinky
  class Builder
    def self.build dir, build_dir
      manifest = Manifest.new(dir, :build_to => build_dir, :devel => false)
      manifest.build
    end
  end
end
