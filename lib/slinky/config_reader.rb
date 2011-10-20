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
      @config["proxies"] || {}
    end

    def ignores
      @config["ignore"] || []
    end
  end
end
