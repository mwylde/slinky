module Slinky
  class Runner
    COMMANDS = %w{start build}
        
    def initialize argv
      @argv = argv
      @options = {
        :build_dir => "build",
        :port => 5323,
        :src_dir => "."
      }

      parser.parse! @argv
      @command = @argv.shift
      @arguments = @argv

      config_path = @options[:config] || "#{@options[:src_dir]}/slinky.yaml"
      @config = if File.exist?(config_path) 
                  ConfigReader.from_file(config_path)
                else
                  ConfigReader.empty
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
        opts.on("-c FILE", "--config FILE", "Path to configuration file"){|f| @options[:config] = f}
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
      Signal.trap('INT') { puts "Slinky fading away ... "; exit(0); }

      EM::run {
        Slinky::Server.dir = @options[:src_dir]
        Slinky::Server.config = @config
        if @config && !@config.proxies.empty? && !@options[:no_proxy]
          server = EM::start_server "127.0.0.1", @options[:port]+1, Slinky::Server
          ProxyServer.run(@config.proxies, @options[:port], 5324)
        else
          EM::start_server "0.0.0.0", @options[:port], Slinky::Server
        end
        puts "Started static file server on port #{@options[:port]}"
      }
    end

    def command_build
      Builder.build(@options[:src_dir], @options[:build_dir], @config)
    end
  end
end
