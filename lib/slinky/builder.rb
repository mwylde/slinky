module Slinky
  class Builder
    def self.build dir, build_dir
      manifest = Manifest.new(dir, build_dir)
      puts manifest.dependency_list.collect{|x| x.source}.inspect
      # manifest.build
      puts "Build complete!"
    end
  end
end
