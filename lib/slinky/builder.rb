module Slinky
  class Builder
    def self.build dir, build_dir
      manifest = Manifest.new(dir)
      manifest.build build_dir
    end
  end
end
