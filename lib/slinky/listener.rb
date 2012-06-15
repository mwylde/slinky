Thread.abort_on_exception = true

module Slinky
  class Listener
    def initialize manifest
      @manifest = manifest
    end

    def run
      
      listener = Listen.to(@manifest.dir)
      listener.change do |mod, add, rem|
        handle_mod(mod) if mod.size > 0
        handle_add(add) if add.size > 0
        handle_rem(rem) if rem.size > 0
      end
      listener.start(false)
    end

    def handle_mod files
    end
    
    def handle_add files
      EM.next_tick {
        files.each{|f|
          @manifest.add_by_path f
        }
      }
    end
    
    def handle_rem files
    end
  end
end
