Thread.abort_on_exception = true

module Slinky
  class Listener
    def initialize manifest, livereload
      @manifest = manifest
      @livereload = livereload
    end

    def run
      listener = Listen.to(@manifest.dir) do |mod, add, rem|
        handle_mod(mod) if mod.size > 0
        handle_add(add) if add.size > 0

        EM.next_tick {
          files = (mod + add + rem).map{|path|
            mpath = Pathname.new(path)\
              .relative_path_from(Pathname.new(@manifest.dir).expand_path).to_s
            mf = @manifest.find_by_path(mpath, false).first
            if mf
              mf.output_path
            else
              path
            end
          }
          @livereload.reload_browser(files)
        } if @livereload

        handle_rem(rem) if rem.size > 0        
      end
      listener.start
      listener
    end

    def handle_mod files
    end
    
    def handle_add files
      EM.next_tick {
        begin
          @manifest.add_all_by_path files
        rescue
        end
      }
    end

    def handle_rem files
      EM.next_tick {
        begin
          @manifest.remove_all_by_path files
        rescue
        end
      }
    end
  end
end
