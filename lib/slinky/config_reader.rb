module Slinky
  class ConfigReader
    def self.from_file path
      new File.open(path).read
    end

    def self.empty
      new "{}"
    end

    def initialize string
      @config = YAML::load(string)
    end

    def proxies
      @config["proxy"] || {}
    end

    def ignores
      @config["ignore"] || []
    end

    def port
      @config["port"] || 5323
    end

    def src_dir
      @config["src_dir"] || "."
    end

    def build_dir
      @config["build_dir"] || "build"
    end

    def no_proxy
      @config["no_proxy"] || false
    end
    
    def no_livereload
      @config["no_livereload"] || false
    end

    def livereload_port
      @config["livereload_port"] || 35729
    end

    def dont_minify
      @config["dont_minify"] || false
    end

    def pushstates
      @config["pushstate"]
    end

    def pushstate_for_path path
      if pushstates && pushstates.is_a?(Hash)
        p = pushstates.sort_by{|from, to| -from.count("/")}.find{|a|
          path.start_with? a[0]
        }
        p[1] if p
      end
    end

    def base_path
      @config["base_path"] || ""
    end

    def [](x)
      @config[x]
    end

    def to_s
      @config.to_s
    end
  end
end
