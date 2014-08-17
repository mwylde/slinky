module Slinky
  # This class uses sass --output compressed to compress CSS
  class SassCompressor
    def compress s
       Sass::Engine.new(s, :syntax => :scss, :style => :compressed).render
    end
  end
end
    
