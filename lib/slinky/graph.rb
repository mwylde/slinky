# coding: utf-8
module Slinky
  # The Graph class describes a directed graph and provides various
  # graph algorithms.
  class Graph
    include Enumerable
    include TSort

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

    # Methods needed for TSort mixin
    def tsort_each_node &block
      nodes.each(&block)
    end

    def tsort_each_child node, &block
      adjacency_matrix.fetch(node, []).each(&block)
    end

    # Uses the tsort library to build a list of files in topological
    # order, so that when required in this order all dependencies are
    # met.
    def dependency_list
      return @dependency_list if @dependency_list

      results = []
      each_strongly_connected_component{|component|
        if component.size == 1
          results << component.first
        else
          cycle = component.map{|x| x.source}.join(" -> ")
          raise DependencyError.new("Dependencies #{cycle} could not be satisfied")
        end
      }
      @dependency_list = results
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
