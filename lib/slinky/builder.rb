module Slinky
  class Builder
    def self.build options, config
      dir = options[:src_dir] || config.src_dir
      build_dir = options[:build_dir] || config.build_dir
      manifest = Manifest.new(dir, config,
                              :build_to => build_dir,
                              :devel => false,
                              :no_minify => config.dont_minify || options[:no_minify])
      begin
        manifest.build
      rescue SlinkyError => e
        e.messages.each{|m|
          $stderr.puts(m.foreground(:red))
        }
        exit 1
      end
    end
  end
end
