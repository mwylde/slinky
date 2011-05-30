# -*- coding: utf-8 -*-
require 'pathname'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html haml sass scss coffee}
  #BUILD_DIRECTIVES = /(slinky_require)\(\s*(['"])(.+)['"]\s*\)/
  #BUILD_DIRECTIVES = /^\s*(slinky_require)\s+(".+"|'.+')\s*\n/
  BUILD_DIRECTIVES = /(slinky_require|slinky_scripts|slinky_css)\((".*"|'.+'|)\)/
  
  class Manifest
    attr_accessor :manifest_dir

    def initialize dir, build_dir
      @manifest_dir = ManifestDir.new dir, build_dir
    end

    def files
      @files = []
      files_rec @manifest_dir
      @files
    end
    
    def files_rec md
      @files += md.files
      md.children.each do |c|
        files_rec c
      end
    end

    def build_dependency_graph
      graph = []
      files.each{|mf|
        mf.directives[:slinky_require].each{|rf|
          pf = Pathname.new(mf.source).dirname + rf
          required = @files.find{|f| Pathname.new(f.source) == pf}
          if required
            puts "Created edge: #{[required.source, mf.source].inspect}"
            graph << [required, mf]
          else
            puts "Could not find file #{pf} required by #{mf.source}".foreground(:red)
            exit
          end
        } if mf.directives[:slinky_require]
      }
      @dependency_graph = graph
    end

    # Builds a list of files in topological order, so that when
    # required in this order all dependencies are met. See
    # http://en.wikipedia.org/wiki/Topological_sorting for more
    # information.
    def dependency_list
      # Algorithm (from wikipedia)
      # L ← Empty list that will contain the sorted elements
      # S ← Set of all nodes with no incoming edges
      # while S is non-empty do
      #   remove a node n from S
      #   insert n into L
      #   for each node m with an edge e from n to m do
      #     remove edge e from the graph
      #     if m has no other incoming edges then
      #       insert m into S
      #       if graph has edges then
      #         output error message (graph has at least one cycle)
      #       else 
      #        output message (proposed topologically sorted order: L)
      build_dependency_graph unless @dependency_graph
      graph = @dependency_graph.clone
      # will contain sorted elements
      l = []
      # start nodes, those with no incoming edges
      s = @files.reject{|mf| mf.directives[:slinky_require]}
      while s.size > 0
        n = s.delete s.first
        l << n
        graph.delete_if{|e|
          if e[1] == n
            m = e[0]
            s << m unless _graph.any{|e| e[1] == m}
            true
          else
            false
          end
        }
      end
      if graph != []
        problems = graph.collect{|e| e[1].source}
        puts "Dependencies #{problems.join(",")} could not be satisfied".foreground(:red)
        exit
      end
      l
    end

    def build
      @manifest_dir.build
    end
  end

  class ManifestDir
    attr_accessor :dir, :files, :children
    def initialize dir, build_dir
      @dir = dir
      @files = []
      @children = []
      @build_dir = Pathname.new(build_dir)

      Dir.glob("#{dir}/*").each do |path|
        # skip the build dir
        next if File.realpath(path) == File.realpath(build_dir) rescue false
        if File.directory? path
          build_dir = (@build_dir + File.basename(path)).cleanpath
          @children << ManifestDir.new(path, build_dir)
        else
          build_path = (@build_dir + File.basename(path)).cleanpath
          @files << ManifestFile.new(path, build_path)
        end
      end
    end

    def build
      if !@build_dir.exist?
        @build_dir.mkdir
      end
      (@files + @children).each{|m|
        m.build
      }
    end
  end

  class ManifestFile
    attr_accessor :source, :build_path
    attr_reader :last_built, :directives

    def initialize source, build_path
      @source = source
      @last_built = Time.new(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
    end

    def build
      # mangle file appropriately
      path = @source
      build_path = @build_path

      if @directives.size > 0
        File.open(path){|f|
          out = f.read.gsub(BUILD_DIRECTIVES, "")
          path = Tempfile.new("slinky").path
          File.open(path, "w+"){|f|
            f.write(out)
          }
        }
      end

      if @cfile
        cfile = @cfile.clone
        cfile.source = path
        cfile.print_name = @source
        cfile.file do |cpath, _, _, _|
          path = cpath
        end
        build_path = build_path.sub_ext ".#{cfile.output_ext}"
      end

      filename = File.basename(@source)
      if path
        FileUtils.cp(path, build_path)
        @last_built = Time.now
      else
        exit
      end
    end

    def find_directives
      _, _, ext = @source.match(EXTENSION_REGEX).to_a
      directives = {}
      # check if this file might include directives
      if @cfile || DIRECTIVE_FILES.include?(ext)
        # make sure the file isn't too big to scan
        stat = File::Stat.new(@source)
        if stat.size < 1024*1024
          File.open(@source) {|f|
            matches = f.read.scan(BUILD_DIRECTIVES).to_a
            matches.each{|slice|
              key, value = slice
              directives[key.to_sym] ||= []
              directives[key.to_sym] << value[1..-2]
            }
          } rescue nil
        end
      end

      directives
    end
  end
end
