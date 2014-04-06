module Slinky
  # Raised when reading an invalid configuraiton
  class InvalidConfigError < StandardError; end

  class ConfigReader
    HASH_TYPE = "hash"
    ARRAY_TYPE = "array"
    STRING_TYPE = "string"
    NUMBER_TYPE = "number"
    BOOL_TYPE = "bool"
    ANY_TYPE = "any"

    class ConfigEntry
      attr_reader :type, :name, :default
      def initialize(name, type, default)
        @name = name
        @type = type
        @default = default
      end
    end

    @entries = [
      ConfigEntry.new("proxy", HASH_TYPE, {}),
      ConfigEntry.new("ignore", ARRAY_TYPE, []),
      ConfigEntry.new("port", NUMBER_TYPE, 5323),
      ConfigEntry.new("src_dir", STRING_TYPE, "."),
      ConfigEntry.new("build_dir", STRING_TYPE, "."),      
      ConfigEntry.new("no_proxy", BOOL_TYPE, false),
      ConfigEntry.new("no_livereload", BOOL_TYPE, false),
      ConfigEntry.new("livereload_port", NUMBER_TYPE, 35729),
      ConfigEntry.new("dont_minify", BOOL_TYPE, false),
      ConfigEntry.new("pushstate", ANY_TYPE, []),
    ]

    @entries.each{|e|
      self.class_eval %{
        def #{e.name}
          @config["#{e.name}"] || #{e.default.inspect}
        end
      }
    }

    def self.from_file path
      new File.open(path).read
    end

    def self.empty
      new "{}"
    end

    # Validates whether a supplied hash is well-formed according to
    # the allowed entries
    def self.validate config
      entries = {}
      @entries.each{|e| entries[e.name] = e}
      errors = config.map{|k, v|
        if !entries[k]
          " * '#{k}' is not an allowed configuration key"
        end
      }.compact

      if !errors.empty?
        raise InvalidConfigError.new(errors.join("\n"))
      end
    end

    def initialize string
      @config = YAML::load(string)
      ConfigReader.validate(@config)
    end

    def pushstate_for_path path
      if pushstate && pushstate.is_a?(Hash)
        p = pushstate.sort_by{|from, to| -from.count("/")}.find{|a|
          path.start_with? a[0]
        }
        p[1] if p
      end
    end

    def [](x)
      @config[x]
    end

    def to_s
      @config.to_s
    end
  end
end
