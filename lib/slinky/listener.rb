Thread.abort_on_exception = true

module Slinky
  class Listener
    def initialize manifest, livereload
      @manifest = manifest
      @livereload = livereload
    end

    def run
      manifest_md5 = @manifest.md5
      listener = Listen.to(@manifest.dir) do |mod, add, rem|

        EM.next_tick {
          handle_mod(mod) if mod.size > 0
          handle_add(add) if add.size > 0
          handle_rem(rem) if rem.size > 0
          
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

          # only reload if something's actually changed
          if manifest_md5 != @manifest.md5
            manifest_md5 = @manifest.md5
            @livereload.reload_browser(files)
          end
        } if @livereload
      end
      listener.start
      listener
    end

    def handle_mod files
      @manifest.update_all_by_path files rescue nil
    end

    def handle_add files
      @manifest.add_all_by_path files rescue nil
    end

    def handle_rem files
      @manifest.remove_all_by_path files rescue nil
    end
  end
end
