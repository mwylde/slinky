# coding: utf-8
module Slinky
  # The Graph class describes a directed graph and provides various
  # graph algorithms.
  class Graph
    include Enumerable

    attr_reader :nodes, :edges

    # Creates a new Graph from an adjacency list
    def initialize nodes, edges
      @nodes = nodes
      @edges = edges
    end

    # Builds an adjacency matrix representation of the graph
    def adjacency_matrix
      return @adjacency_matrix if @adjacency_matrix

      # Convert from adjacency list to a map structure
      g = Hash.new{|h,k| h[k] = []}
      edges.each{|x|
        g[x[1]] << x[0]
      }

      @adjacency_matrix = g
    end

    # Builds the transitive closure of the dependency graph using
    # Floyd–Warshall
    def transitive_closure
      return @transitive_closure if @transitive_closure

      g = adjacency_matrix
      
      index_map = {}
      nodes.each_with_index{|f, i| index_map[f] = i}

      size = nodes.size

      # Set up the distance matrix
      dist = Array.new(size){|_| Array.new(size, Float::INFINITY)}
      nodes.each_with_index{|fi, i|
        dist[i][i] = 0
        g[fi].each{|fj|
          dist[i][index_map[fj]] = 1
        }
      }

      # Compute the all-paths costs
      size.times{|k|
        size.times{|i|
          size.times{|j|
            if dist[i][j] > dist[i][k] + dist[k][j] 
              dist[i][j] = dist[i][k] + dist[k][j]
            end
          }
        }
      }

      # Compute the transitive closure in map form
      @transitive_closure = Hash.new{|h,k| h[k] = []}
      size.times{|i|
        size.times{|j|
          if dist[i][j] < Float::INFINITY
            @transitive_closure[nodes[i]] << nodes[j]
          end
        }
      }

      @transitive_closure
    end

    # Builds a list of files in topological order, so that when
    # required in this order all dependencies are met. See
    # http://en.wikipedia.org/wiki/Topological_sorting for more
    # information.
    def dependency_list
      return @dependency_list if @dependency_list

      graph = edges.clone
      # will contain sorted elements
      l = []
      # start nodes, those with no incoming edges
      s = nodes.reject{|mf| mf.directives[:slinky_require]}
      while s.size > 0
        n = s.delete s.first
        l << n
        nodes.each{|m|
          e = graph.find{|e| e[0] == n && e[1] == m}
          next unless e
          graph.delete e
          s << m unless graph.any?{|e| e[1] == m}
        }
      end
      if graph != []
        problems = graph.collect{|e| e.collect{|x| x.source}.join(" -> ")}
        raise DependencyError.new("Dependencies #{problems.join(", ")} could not be satisfied")
      end
      @dependency_list = l
    end

    def each &block  
      edges.each do |e|
        if block_given?
          block.call e
        else  
          yield e
        end
      end  
    end
  end
end
