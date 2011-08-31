# -*- coding: utf-8 -*-
require 'pathname'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html haml sass scss coffee}
  REQUIRE_DIRECTIVE = /^[^\n\w]*(slinky_require)\((".*"|'.+'|)\)[^\n\w]*$/
  SCRIPTS_DIRECTIVE = /^[^\n\w]*(slinky_scripts)[^\n\w]*$/
  STYLES_DIRECTIVE  = /^[^\n\w]*(slinky_styles)[^\n\w]*$/
  BUILD_DIRECTIVES = Regexp.union(REQUIRE_DIRECTIVE, SCRIPTS_DIRECTIVE, STYLES_DIRECTIVE)
  CSS_URL_MATCHER = /url\(['"]?([^'"\/][^\s)]+\.[a-z]+)(\?\d+)?['"]?\)/

  # Raised when a compilation fails for any reason
  class BuildFailedError < StandardError; end
  # Raised when a required file is not found.
  class FileNotFoundError < StandardError; end
  # Raised when there is a cycle in the dependency graph (i.e., file A
  # requires file B which requires C which requires A)
  class DependencyError < StandardError; end
  
  class Manifest
    attr_accessor :manifest_dir, :dir

    def initialize dir, config, options = {}
      @dir = dir
      @build_to = if d = options[:build_to]
                    File.absolute_path(d)
                  else
                    dir
                  end
      @manifest_dir = ManifestDir.new dir, @build_to, self
      @devel = (options[:devel].nil?) ? true : options[:devel]
      @config = config
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
        dependency_list.reject{|x| x.output_path.extname != ".js"}.collect{|d|
          %Q\<script type="text/javascript" src="#{d.relative_output_path}"></script>\
        }.join("")
      else
        '<script type="text/javascript" src="/scripts.js"></script>'
      end
    end

    def compress ext, output, compressor
      scripts = dependency_list.reject{|x| x.output_path.extname != ext}

      s = scripts.collect{|s|
        f = File.open(s.build_to.to_s, 'rb'){|f| f.read}
        (block_given?) ? (yield s, f) : f
      }.join("\n")

      File.open(output, "w+"){|f|
        f.write(compressor.compress(s)) 
      }
      scripts.collect{|s| FileUtils.rm(s.build_to)}
    end
    
    def compress_scripts
      compressor = YUI::JavaScriptCompressor.new(:munge => true)
      compress(".js", "#{@build_to}/scripts.js", compressor)
    end

    def compress_styles
      compressor = YUI::CssCompressor.new()

      compress(".css", "#{@build_to}/styles.css", compressor){|s, css|
        css.gsub(CSS_URL_MATCHER){|url|
          p = s.relative_output_path.dirname.to_s + "/#{$1}"
          "url('#{p}')"
        }
      }
    end

    def styles_string
      if @devel
        dependency_list.reject{|x| x.output_path.extname != ".css"}.collect{|d|
          %Q\<link rel="stylesheet" href="#{d.relative_output_path}" />\
        }.join("")
      else
        '<link rel="stylesheet" href="/styles.css" />'
      end
    end

    # Builds the directed graph representing the dependencies of all
    # files in the manifest that contain a slinky_require
    # declaration. The graph is represented as a list of pairs
    # (required, by), each of which describes an edge.
    #
    # @return [[ManifestFile, ManifestFile]] the graph
    def build_dependency_graph
      graph = []
      files.each{|mf|
        mf.directives[:slinky_require].each{|rf|
          required = mf.parent.find_by_path(rf)
          if required
            graph << [required, mf]
          else
            error = "Could not find file #{rf} required by #{mf.source}"
            $stderr.puts error.foreground(:red)
            raise FileNotFoundError.new(error)
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
        problems = graph.collect{|e| e.collect{|x| x.source}.join(" -> ")}
        $stderr.puts "Dependencies #{problems.join(", ")} could not be satisfied".foreground(:red)
        raise DependencyError
      end
      l
    end

    def build
      @manifest_dir.build
      unless @devel
        compress_scripts
        compress_styles
      end
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
        next if Pathname.new(File.absolute_path(path)) == Pathname.new(build_dir)
        if File.directory? path
          build_dir = (@build_dir + File.basename(path)).cleanpath
          @children << ManifestDir.new(path, build_dir, manifest)
        else
           @files << ManifestFile.new(path, @build_dir, manifest, self)
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
        self
      when 1
        @files.find{|f| f.matches? components[0]}
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

  class ManifestFile
    attr_accessor :source, :build_path
    attr_reader :last_built, :directives, :parent, :manifest

    def initialize source, build_path, manifest, parent = nil, options = {:devel => false}
      @parent = parent
      @source = source
      @last_built = Time.new(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
      @manifest = manifest
      @devel = true if options[:devel]
    end

    # Predicate which determines whether the supplied name is the same
    # as the file's name, taking into account compiled file
    # extensions. For example, if mf refers to "/tmp/test/hello.sass",
    # `mf.matches? "hello.sass"` and `mf.matches? "hello.css"` should
    # both return true.
    #
    # @param [String] a filename
    # @return [Bool] True if the filename matches, false otherwise
    def matches? s
      name = Pathname.new(@source).basename.to_s
      name == s || output_path.basename.to_s == s
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

    # Returns the output path relative to the manifest directory
    def relative_output_path
      output_path.relative_path_from Pathname.new(@manifest.dir)
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
    def handle_directives path, to = nil
      if @directives.size > 0
        begin
          out = File.read(path)
          out.gsub!(REQUIRE_DIRECTIVE, "")
          out.gsub!(SCRIPTS_DIRECTIVE, @manifest.scripts_string)
          out.gsub!(STYLES_DIRECTIVE, @manifest.styles_string)
          to = to ||  Tempfile.new("slinky").path
          File.open(to, "w+"){|f|
            f.write(out)
          }
          to
        rescue
          nil
        end
      else
        path
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
      path ? Pathname.new(path) : nil
    end

    # Gets manifest file ready for serving or building by handling the
    # directives and compiling the file if neccesary.
    # @param String path to which the file should be compiled
    #
    # @return String the path of the processed file, ready for serving
    def process to = nil
      # mangle file appropriately
      handle_directives (compile @source), to
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
        FileUtils.cp(path.to_s, to.to_s)
        @last_built = Time.now
      end
      to
    end
  end
end
