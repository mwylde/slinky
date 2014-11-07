module Slinky
  # Pure ruby implementation of all paths cost for a graph
  def self.all_paths_costs size, dist
    size.times{|k|
      size.times{|i|
        size.times{|j|
          if dist[size * i + j] > dist[size * i + k] + dist[size * k + j]
            dist[size * i + j] = dist[size * i + k] + dist[size * k + j]
          end
        }
      }
    }
  end  
end
