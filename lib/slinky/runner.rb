module Slinky
  class Runner
    COMMANDS = %w{start build}
        
    def initialize argv
      @argv = argv
      @options = {
        :build_dir => "build",
        :port => 5323
      }

      parser.parse! @argv
      @command = @argv.shift
      @arguments = @argv
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
        EM::start_server "0.0.0.0", @options[:port], Slinky::Server
        puts "Started static file server on port #{@options[:port]}"
      }
    end

    def command_build
      Builder.build(".", @options[:build_dir])
    end
  end
end
