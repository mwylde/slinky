module Slinky
  class Builder
    def initialize dir
      @dir = dir
    end

    def build
      manifest = Manifest.build(@dir)
      exts = Server.compilers_by_ext.keys
      manifest.files.each do |file|
        # check whether we might need to do something special with
        # this file
        _, _, ext = file.match(EXTENSION_REGEX).to_a
        File.open(file) do
          
        end
      end
    end
  end
end
