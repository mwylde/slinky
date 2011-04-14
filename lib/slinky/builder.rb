module Slinky
  class Builder
    def initialize dir
      @dir = dir
    end

    def build
      manifest = Manifest.build(@dir)
      manifest.files.each do |file|
        File.open(file) do
          
        end
      end
    end
  end
end
