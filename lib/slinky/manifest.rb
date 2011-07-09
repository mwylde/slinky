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

    def initialize dir, options = {:devel => true, :build_to => ""}
      @manifest_dir = ManifestDir.new dir, options[:build_to], self
      @devel = options[:devel]
    end

    # Returns a list of all files contained in this manifest
    #
    # @return [ManifestFile] a list of manifest files
    def files
      @files = []
      files_rec @manifest_dir
      @files
    end
    

    # Finds the file at the given path in the manifest if one exists,
    # otherwise nil.
    #
    # @param String path the path of the file relative to the manifest
    #
    # @return ManifestFile the manifest file at that path if one exists
    def find_by_path path
      @manifest_dir.find_by_path path
    end
    
    def scripts_string
      if @devel
        dependency_list.collect{|d|
          # we take [1..-1] to eliminate the starting . in ./path/to/script.js
          %Q\<script type="text/javascript" src="#{d.output_path.to_s[1..-1]}" />\
        }.join("")
      else
        '<script type="text/javscript" src="/scripts.js" />'
      end
    end

    def styles_string
      '<link rel="stylesheet" href="/styles.css" />'
    end

    # Builds the directed graph representing the dependencies of all
    # files in the manifest that contain a slinky_require
    # declaration. The graph is represented as a list of pairs (from,
    # to), each of which describes an edge.
    #
    # @return [[ManifestFile, ManifestFile]]
    def build_dependency_graph
      graph = []
      files.each{|mf|
        mf.directives[:slinky_require].each{|rf|
          pf = Pathname.new(mf.source).dirname + rf
          required = @files.find{|f| Pathname.new(f.source) == pf}
          if required
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

    private
    def files_rec md
      @files += md.files
      md.children.each do |c|
        files_rec c
      end
    end
  end

  class ManifestDir
    attr_accessor :dir, :files, :children
    def initialize dir, build_dir, manifest
      @dir = dir
      @files = []
      @children = []
      @build_dir = Pathname.new(build_dir)
      @manifest = manifest

      Dir.glob("#{dir}/*").each do |path|
        # skip the build dir
        next if File.realpath(path) == File.realpath(build_dir) rescue false
        if File.directory? path
          build_dir = (@build_dir + File.basename(path)).cleanpath
          @children << ManifestDir.new(path, build_dir, manifest)
        else
          build_path = (@build_dir + File.basename(path)).cleanpath
          @files << ManifestFile.new(path, build_path, manifest)
        end
      end
    end

    # Finds the file at the given path in the directory if one exists,
    # otherwise nil.
    #
    # @param String path the path of the file relative to the directory
    #
    # @return ManifestFile the manifest file at that path if one exists
    def find_by_path path
      components = path.to_s.split(File::SEPARATOR).reject{|x| x == ""}
      case components.size
      when 0
        nil
      when 1
        @files.find{|f| File.basename(f.source) == components[0]}
      else
        child = @children.find{|d|
          Pathname.new(d.dir).basename.to_s == components[0]
        }
        child ? child.find_by_path(components[1..-1].join(File::SEPARATOR)) : nil
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

  class BuildFailedError < StandardError; end
  
  class ManifestFile
    attr_accessor :source, :build_path
    attr_reader :last_built, :directives

    def initialize source, build_path, manifest, options = {:devel => false}
      @source = source
      @last_built = Time.new(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
      @manifest = manifest
      @devel = true if options[:devel]
    end

    # Returns the path to which this file should be output. This is
    # equal to the source path unless the file needs to be compiled,
    # in which case the extension returned is the output extension
    #
    # @return Pathname the output path
    def output_path
      if @cfile
        Pathname.new(@source).sub_ext ".#{@cfile.output_ext}"
      else
        Pathname.new(@source)
      end
    end

    # Looks through the file for directives
    # @return {Symbol => [String]} the directives in the file
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
              key, value = slice.compact
              directives[key.to_sym] ||= []
              directives[key.to_sym] << value[1..-2] if value
            }
          } rescue nil
        end
      end

      directives
    end

    # If there are any build directives for this file, the file is
    # read and the directives are handled appropriately and a new file
    # is written to a temp location.
    #
    # @return String the path of the de-directivefied file
    def handle_directives
      if @directives.size > 0
        out = File.read(@source)
        out.gsub!(REQUIRE_DIRECTIVE, "")
        out.gsub!(SCRIPTS_DIRECTIVE, @manifest.scripts_string)
        out.gsub!(STYLES_DIRECTIVE, @manifest.styles_string)
        path = Tempfile.new("slinky").path
        File.open(path, "w+"){|f|
          f.write(out)
        }
        path
      else
        @source
      end
    end

    # Takes a path and compiles the file if necessary.
    # @return Pathname the path of the compiled file, or the original
    #   path if compiling is not necessary
    def compile path, to = nil
      if @cfile
        cfile = @cfile.clone
        cfile.source = path
        cfile.print_name = @source
        cfile.output_path = to if to
        cfile.file do |cpath, _, _, _|
          path = cpath
        end
      end
      Pathname.new(path)
    end

    # Gets manifest file ready for serving or building by handling the
    # directives and compiling the file if neccesary.
    # @param String path to which the file should be compiled
    #
    # @return String the path of the processed file, ready for serving
    def process to = nil
      # mangle file appropriately
      path = handle_directives
      compile path, to
    end

    # Path to which the file will be built
    def build_to
      Pathname.new(@build_path) + output_path.basename
    end

    # Builds the file by handling and compiling it and then copying it
    # to the build path
    def build
      if !File.exists? @build_path
        FileUtils.mkdir_p(@build_path)
      end
      to = build_to
      path = process to
      
      if !path
        raise BuildFailedError
      elsif path != to
        FileUtils.cp(path, to)
        @last_built = Time.now
      end

      to
    end
  end
end
