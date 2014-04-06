module Slinky
  class Runner
    COMMANDS = %w{start build}
        
    def initialize argv
      # While slinky largely works in Ruby 1.8, the tests don't run
      # properly and using 1.9 is highly recommended.
      if RUBY_VERSION.start_with?("1.8")
        $stderr.puts(("Slinky is unsupported on Ruby 1.8." + \
                      " Using 1.9 is highly recommended.").foreground(:red))
        
      end
      
      @argv = argv
      @options = {}

      parser.parse! @argv
      @command = @argv.shift
      @arguments = @argv

      config_path = @options[:config] || "#{@options[:src_dir] || "."}/slinky.yaml"
      begin
        @config = if File.exist?(config_path) 
                    ConfigReader.from_file(config_path)
                  else
                    ConfigReader.empty
                  end
      rescue InvalidConfigError => e
        $stderr.puts("The configuration file at #{config_path} is invalid:".foreground(:red))
        $stderr.puts(e.message.foreground(:red))
        exit(1)
      end
        
    end

    def version
      root = File.expand_path(File.dirname(__FILE__))
      File.open("#{root}/../../VERSION"){|f|
        puts "slinky #{f.read.strip}"
      }
      exit
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: slinky [options] #{COMMANDS.join('|')}"
        opts.on("-v", "--version", "Outputs current version number and exits"){ version }
        opts.on("-o DIR", "--build-dir DIR", "Directory to which the site will be built.", "Use in conjunction with the 'build' command."){|dir| @options[:build_dir] = File.expand_path(dir)}
        opts.on("-p PORT", "--port PORT", "Port to run on (default: #{@options[:port]})"){|p| @options[:port] = p.to_i}
        opts.on("-s DIR", "--src-dir DIR", "Directory containing project source"){|p| @options[:src_dir] = p}
        opts.on("-n", "--no-proxy", "Don't set up proxy server"){ @options[:no_proxy] = true }
        opts.on("-r", "--no-livereload", "Don't start a livereload server"){ @options[:no_livereload] = true }        
        opts.on("-c FILE", "--config FILE", "Path to configuration file"){|f| @options[:config] = f}
        opts.on("-m", "--dont-minify", "Don't minify js/css"){ @options[:no_minify] = true }
      end
    end

    def run
      case @command
      when "start" then command_start
      when "build" then command_build
      when nil
        abort "Must provide a command (one of #{COMMANDS.join(', ')})"
      else
        abort "Unknown command: #{@command}. Must be on of #{COMMANDS.join(', ')}."
      end
    end

    def command_start
      EM::run {
        @config ||= Config.empty

        Slinky::Server.dir = @options[:src_dir]
        Slinky::Server.config = @config
        manifest = Manifest.new(Slinky::Server.dir,
                                Slinky::Server.config)
        Slinky::Server.manifest = manifest

        port = @options[:port] || @config.port

        should_proxy = !(@config.no_proxy || @options[:no_proxy])
        if !@config.proxy.empty? && should_proxy
          server = EM::start_server "127.0.0.1", port+1, Slinky::Server
          ProxyServer.run(@config.proxy, port, port+1)
        else
          EM::start_server "127.0.0.1", port, Slinky::Server
        end

        if !@config.no_livereload && !@options[:no_livereload]
          lr_port = @options[:livereload_port] || @config.livereload_port
          livereload = LiveReload.new("127.0.0.1", lr_port)
          livereload.run
        end

        Listener.new(manifest, livereload).run

        Signal.trap('INT') {
          Listen.stop
          EM::stop
          puts "Slinky fading away ... "
          exit(0)
        }

        puts "Started static file server on port #{port}"
      }
    end

    def command_build
      Builder.build(@options, @config)
    end
  end
end
