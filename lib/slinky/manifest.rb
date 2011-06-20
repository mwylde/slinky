# -*- coding: utf-8 -*-
require 'pathname'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html haml sass scss coffee}
  REQUIRE_DIRECTIVE = /^\W*(slinky_require)\((".*"|'.+'|)\)\W*$/
  SCRIPTS_DIRECTIVE = /^\W*(slinky_scripts)\W*$/
  STYLES_DIRECTIVE  = /^\W*(slinky_styles)\W*$/
  BUILD_DIRECTIVES = Regexp.union(REQUIRE_DIRECTIVE, SCRIPTS_DIRECTIVE, STYLES_DIRECTIVE)
  
  class Manifest
    attr_accessor :manifest_dir

    def initialize dir, build_dir = nil
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

    def scripts_string
      if @devel
        
      else
        '<script type="text/javscript" src="/scripts.js" />'
      end
    end

    def styles_string
      '<link rel="stylesheet" href="/styles.css" />'
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
      build_dependency_graph unless @dependency_graph
      graph = @dependency_graph.clone
      # will contain sorted elements
      l = []
      # start nodes, those with no incoming edges
      s = @files.reject{|mf| mf.directives[:slinky_require]}
      while s.size > 0
        n = s.delete s.first
        l << n
        @files.each{|m|
          e = graph.find{|e| e[0] == n && e[1] == m}
          next unless e
          graph.delete e
          s << m unless graph.any?{|e| e[1] == m}
        }
      end
      if graph != []
        puts l.collect{|x| x.source}.inspect
        problems = graph.collect{|e| e.collect{|x| x.source}.join(":")}
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

    def initialize source, build_path, options = {:devel => false}
      @source = source
      @last_built = Time.new(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
      @devel = true if options[:devel]
    end

    def build
      # mangle file appropriately
      path = @source
      build_path = @build_path

      if @directives.size > 0
        File.open(path){|f|
          out = f.read
          out.gsub!(REQUIRE_DIRECTIVE, "")
          out.gsub!(SCRIPTS_DIRECTIVE, scripts_string)
          out.gsub!(STYLES_DIRECTIVE, styles_string)
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
              key, value = slice[1..-1].compact
              directives[key.to_sym] ||= []
              directives[key.to_sym] << value[1]
            }
          } rescue nil
        end
      end

      directives
    end
  end
end
