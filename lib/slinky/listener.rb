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
        @manifest.add_all_by_path files
      }
    end
    
    def handle_rem files
      EM.next_tick {
        @manifest.remove_all_by_path files
      }
    end
  end
end
