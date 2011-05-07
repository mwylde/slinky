module Slinky
  class Runner
    class << self
      Signal.trap('INT') { puts "Slinky fading away ... "; exit(0); }
      def run
        EM::run {
          EM::start_server "0.0.0.0", 5323, Slinky::Server
          puts "Started static file server on port 5323"
        }
      end
    end    
  end
end
