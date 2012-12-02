module Slinky
  module ProxyServer
    HTTP_MATCHER = /(GET|POST|PUT|DELETE|HEAD) (.+?)(?= HTTP)/
    HOST_MATCHER = /Host: (.+)/
    
    def self.process_proxies proxy_hash
      proxy_hash.map{|from, h|
        begin
          to, opt = h.is_a?(Hash) ? [h.delete("to"), h] : [h, {}]
          a = [from, URI::parse(to), opt]
        rescue
          $stderr.puts "Invalid proxy setting: #{from} => #{to}".foreground(:red)
        end
      }.compact
    end

    def self.process_proxy_servers proxies
      proxies.map{|p| [p[1].host, p[1].port]}
    end

    def self.find_matcher proxies, path
      proxies.find{|p| path.start_with?(p[0])}
    end

    def self.rewrite_path path, proxy
      path.gsub(/^#{proxy[0]}/, "")      
    end

    def self.replace_path http, old_path, new_path, addition
      # TODO: This may fail in certain, rare cases
      addition = addition[0..-2] if addition[-1] == "/"
      http.gsub(old_path, addition + new_path)
    end

    def self.replace_host http, host
      http.gsub(HOST_MATCHER, "Host: #{host}")
    end

    def self.run proxy_hash, port, slinky_port
      proxies = process_proxies proxy_hash
      proxy_servers = process_proxy_servers proxies

      Proxy.start(:host => "0.0.0.0", :port => port){|conn|
        proxy = nil
        start_time = nil
        conn.server :slinky, :host => "127.0.0.1", :port => slinky_port

        conn.on_data do |data|
          begin
            _, path = data.match(ProxyServer::HTTP_MATCHER)[1..2]
            proxy = ProxyServer.find_matcher(proxies, path)
            start_time = Time.now
            server = if proxy
                       new_path = ProxyServer.rewrite_path path, proxy
                       data = ProxyServer.replace_path(data, path, new_path, proxy[1].path)
                       new_host = proxy[1].select(:host, :port).join(":")
                       data = ProxyServer.replace_host(data, new_host)
                       conn.server [proxy[1].host, proxy[1].port],
                         :host => proxy[1].host, :port => proxy[1].port
                       [proxy[1].host, proxy[1].port]
                     else :slinky
                     end
            [data, [server]]
          rescue
            $stderr.puts "Got error: #{$!}".foreground(:red)
            conn.send_data "HTTP/1.1 500 Ooops...something went wrong\r\n"
          end
        end

        conn.on_response do |server, resp|
          opt = proxy && proxy[2]
          if opt && opt["lag"]
            # we want to get as close as possible to opt["lag"], so we
            # take into account the lag from the backend server
            so_far = Time.now - start_time
            time = opt["lag"]/1000.0-so_far
            EM.add_timer (time > 0 ? time : 0) do
              conn.send_data resp
            end
          else
            resp
          end
        end

        conn.on_finish do |name|
          unbind
        end
      }
    end
  end
end
