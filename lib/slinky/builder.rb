module Slinky
  class Builder
    def initialize dir
      @dir = dir
    end

    def build build_dir = "build"
      manifest = Manifest.construct(@dir)
      manifest.files.each{|mf|
        mf.build build_dir
      }
    end
  end
end
