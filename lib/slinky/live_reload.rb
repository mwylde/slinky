module Slinky
  # Code to interface with the LiveReload set of browser plugins and
  # javascript clients. Adapted from the guard-livereload project at
  # github.com/guard/guard-livereload.
  class LiveReload
    def initialize host, port
      @host = host
      @port = port
      @websockets = []
    end

    def run
      EventMachine.run do
        EventMachine.start_server(@host,
                                  @port,
                                  EventMachine::WebSocket::Connection, {}) do |ws|
          ws.onopen do
            begin
              $stdout.puts "Browser connected to livereload server"
              ws.send "!!ver:1.6"
              @websockets << ws
            rescue
              $stderr.puts $!.to_s.foreground(:red)
            end
          end

          ws.onclose do
            @websockets.delete ws
            $stdout.puts "Browser disconnected"
          end
        end
      end
      $stdout.puts "Started live-reload server on port #{@port}"
    end

    def reload_browser(paths = [])
      paths.each do |path|
        data = MultiJson.encode(['refresh', {
                                   :path           => "#{path}",
                                   :apply_js_live  => false,
                                   :apply_css_live => true
                                 }])
        @websockets.each { |ws| ws.send(data) }
      end
    end
  end
end
