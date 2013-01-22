# -*- coding: utf-8 -*-
require 'pathname'
require 'digest/md5'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html haml sass scss coffee}
  DEPENDS_DIRECTIVE = /^[^\n\w]*(slinky_depends)\((".*"|'.+'|)\)[^\n\w]*$/
  REQUIRE_DIRECTIVE = /^[^\n\w]*(slinky_require)\((".*"|'.+'|)\)[^\n\w]*$/
  SCRIPTS_DIRECTIVE = /^[^\n\w]*(slinky_scripts)[^\n\w]*$/
  STYLES_DIRECTIVE  = /^[^\n\w]*(slinky_styles)[^\n\w]*$/
  BUILD_DIRECTIVES = Regexp.union(DEPENDS_DIRECTIVE,
                                  REQUIRE_DIRECTIVE,
                                  SCRIPTS_DIRECTIVE,
                                  STYLES_DIRECTIVE)
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
                    File.expand_path(d)
                  else
                    dir
                  end
      @manifest_dir = ManifestDir.new dir, self, @build_to, self
      @devel = (options[:devel].nil?) ? true : options[:devel]
      @config = config
      @no_minify = options[:no_minify] || config.dont_minify
    end

    # Returns a list of all files contained in this manifest
    #
    # @return [ManifestFile] a list of manifest files
    def files include_ignores = true
      unless @files
        @files = []
        files_rec @manifest_dir
      end
      if include_ignores
        @files
      else
        @files.reject{|f| @config.ignores.any?{|p| f.in_tree? p}}
      end
    end

    # Adds a file to the manifest, updating the dependency graph
    def add_all_by_path paths
      manifest_update paths do |path|
        md = find_by_path(File.dirname(path)).first
        mf = md.add_file(File.basename(path))
      end
    end

    # Removes a file from the manifest
    def remove_all_by_path paths
      manifest_update paths do |path|
        mf = find_by_path(path).first()
        begin
          mf.parent.remove_file(mf)
        rescue
          puts "Failed to remove <#{path}>"
        end
      end
    end

    # Finds the file at the given path in the manifest if one exists,
    # otherwise nil.
    #
    # @param String path the path of the file relative to the manifest
    #
    # @return ManifestFile the manifest file at that path if one exists
    def find_by_path path, allow_multiple = false
      @manifest_dir.find_by_path path, allow_multiple
    end

    def scripts_string
      if @devel
        dependency_list.reject{|x| x.output_path.extname != ".js"}.collect{|d|
          %Q\<script type="text/javascript" src="#{@config.base_path}/#{d.relative_output_path}"></script>\
        }.join("")
      else
        %Q\<script type="text/javascript" src="#{@config.base_path}/scripts.js?#{rand(999999999)}"></script>\
      end
    end

    def compress ext, output, compressor
      scripts = dependency_list.reject{|x| x.output_path.extname != ext}

      if scripts.size > 0
        s = scripts.collect{|s|
          f = File.open(s.build_to.to_s, 'rb'){|f| f.read}
          (block_given?) ? (yield s, f) : f
        }.join("\n")

        File.open(output, "w+"){|f|
          unless @no_minify
            f.write(compressor.compress(s))
          else
            f.write(s)
          end
        }
        scripts.collect{|s| FileUtils.rm(s.build_to)}
      end
    end
    
    def compress_scripts
      compressor = YUI::JavaScriptCompressor.new(:munge => false)
      compress(".js", "#{@build_to}/scripts.js", compressor)
    end

    def compress_styles
      compressor = YUI::CssCompressor.new()

      compress(".css", "#{@build_to}/styles.css", compressor){|s, css|
        css.gsub(CSS_URL_MATCHER){|url|
          p = @config.base_path + s.relative_output_path.dirname.to_s + "/#{$1}"
          "url('/#{p}')"
        }
      }
    end

    def styles_string
      if @devel
        dependency_list.reject{|x| x.output_path.extname != ".css"}.collect{|d|
          %Q\<link rel="stylesheet" href="#{@config.base_path}/#{d.relative_output_path}" />\
        }.join("")
      else
        %Q\<link rel="stylesheet" href="#{@config.base_path}/styles.css?#{rand(999999999)}" />\
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
      files(false).each{|mf|
        mf.directives[:slinky_require].each{|rf|
          required = mf.parent.find_by_path(rf, true)
          if required.size > 0
            required.each{|x|
              graph << [x, mf]
            }
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
      s = files(false).reject{|mf| mf.directives[:slinky_require]}
      while s.size > 0
        n = s.delete s.first
        l << n
        files(false).each{|m|
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

    def invalidate_cache
      @files = nil
      @dependency_graph = nil
    end

    def manifest_update paths
      paths.each{|path|
        if path[0] == '/'
          path = Pathname.new(path).relative_path_from(Pathname.new(@dir).expand_path).to_s
        end
        yield path
      }
      invalidate_cache
      files.each{|f|
        if f.directives.include?(:slinky_scripts) || f.directives.include?(:slinky_styles)
          f.invalidate
          f.process
        end
      }
    end
  end

  class ManifestDir
    attr_accessor :dir, :parent, :files, :children
    def initialize dir, parent, build_dir, manifest
      @dir = dir
      @parent = parent
      @files = []
      @children = []
      @build_dir = Pathname.new(build_dir)
      @manifest = manifest

      Dir.glob("#{dir}/*").each do |path|
        # skip the build dir
        next if Pathname.new(File.expand_path(path)) == Pathname.new(build_dir)
        if File.directory? path
          add_child(path)
        else
          add_file(path)
        end
      end
    end

    # Finds the file at the given path in the directory if one exists,
    # otherwise nil.
    #
    # @param String path the path of the file relative to the directory
    # @param Boolean allow_multiple if enabled, can return multiple paths
    #   according to glob rules
    #
    # @return [ManifestFile] the manifest file at that path if one exists
    def find_by_path path, allow_multiple = false
      components = path.to_s.split(File::SEPARATOR).reject{|x| x == ""}
      case components.size
      when 0
        [self]
      when 1
        path = [@dir, components[0]].join(File::SEPARATOR)
        if (File.directory?(path) rescue false)
          c = @children.find{|d|
            Pathname.new(d.dir).cleanpath == Pathname.new(path).cleanpath
          }
          unless c
            c = add_child(path)
          end
          [c]
        else
          @files.find_all{|f| f.matches? components[0], allow_multiple}
        end
      else
        if components[0] == ".."
          @parent.find_by_path components[1..-1].join(File::SEPARATOR)
        else
          child = @children.find{|d|
            Pathname.new(d.dir).basename.to_s == components[0]
          }
          if child
            child.find_by_path(components[1..-1].join(File::SEPARATOR),
                               allow_multiple)
          else
            []
          end
        end
      end
    end

    # Adds a child directory
    def add_child path
      if File.directory? path
        build_dir = (@build_dir + File.basename(path)).cleanpath
        md = ManifestDir.new(path, self, build_dir, @manifest)
        @children << md
        md
      end
    end
    
    # Adds a file on the filesystem to the manifest
    #
    # @param String path The path of the file
    def add_file path
      file = File.basename(path)
      full_path = [@dir, file].join(File::SEPARATOR)
      if File.exists? full_path
        mf = ManifestFile.new(full_path, @build_dir, @manifest, self)
        @files << mf
        mf
      end
    end

    # Removes a file from the manifest
    #
    # @param ManifestFile mf The file to be deleted
    def remove_file mf
      @files.delete(mf)
    end
    
    def build
      unless File.directory?(@build_dir.to_s)
        FileUtils.mkdir(@build_dir.to_s)
      end
      (@files + @children).each{|m|
        m.build
      }
    end

    def to_s
      "<ManifestDir:'#{@dir}'>"
    end
  end

  class ManifestFile
    attr_accessor :source, :build_path
    attr_reader :last_built, :directives, :parent, :manifest, :updated

    def initialize source, build_path, manifest, parent = nil, options = {:devel => false}
      @parent = parent
      @source = source
      @last_built = Time.at(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
      @manifest = manifest
      @devel = true if options[:devel]
    end

    def invalidate
      @last_built = Time.at(0)
      @last_md5 = nil
    end

    # Predicate which determines whether the supplied name is the same
    # as the file's name, taking into account compiled file
    # extensions. For example, if mf refers to "/tmp/test/hello.sass",
    # `mf.matches? "hello.sass"` and `mf.matches? "hello.css"` should
    # both return true.
    #
    # @param String a filename
    # @param Bool match_glob if true, matches according to glob rules
    # @return Bool True if the filename matches, false otherwise
    def matches? s, match_glob = false
      name = Pathname.new(@source).basename.to_s
      output = output_path.basename.to_s
      # check for stars that are not escaped
      a = [""]
      last = ""
      s.each_char {|c|
        if c != "*" || last == "\\"
          a[-1] << c
        else
          a << ""
        end
        last = c
      }

      if match_glob && a.size > 1
        r2 = a.reduce{|a, x| /#{a}.*#{x}/}
        name.match(r2) || output.match(r2)
      else
        name == s || output == s
      end
    end

    # Predicate which determines whether the file is the supplied path
    # or lies on supplied tree
    def in_tree? path
      return true if matches? path
      abs_path = Pathname.new(path).expand_path.to_s
      asdf = Pathname.new(@source).dirname.expand_path.to_s
      # puts [abs_path, asdf, asdf.start_with?(abs_path), abs_path == asdf].inspect
      asdf.start_with?(abs_path)
    end

    # Returns the path to which this file should be output. This is
    # equal to the source path unless the file needs to be compiled,
    # in which case the extension returned is the output extension
    #
    # @return Pathname the output path
    def output_path
      if @cfile
        ext = /\.[^.]*$/
        Pathname.new(@source.gsub(ext, ".#{@cfile.output_ext}"))
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

      @directives = directives
    end

    # If there are any build directives for this file, the file is
    # read and the directives are handled appropriately and a new file
    # is written to a temp location.
    #
    # @return String the path of the de-directivefied file
    def handle_directives path, to = nil
      if path && @directives.size > 0
        out = File.read(path)
        out.gsub!(DEPENDS_DIRECTIVE, "")
        out.gsub!(REQUIRE_DIRECTIVE, "")
        out.gsub!(SCRIPTS_DIRECTIVE, @manifest.scripts_string)
        out.gsub!(STYLES_DIRECTIVE, @manifest.styles_string)
        to = to || Tempfile.new("slinky").path + ".cache"
        File.open(to, "w+"){|f|
          f.write(out)
        }
        to
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

    # Gets the md5 hash of the source file
    def md5
      Digest::MD5.hexdigest(File.read(@source)) rescue nil
    end

    # Gets manifest file ready for serving or building by handling the
    # directives and compiling the file if neccesary.
    # @param String path to which the file should be compiled
    #
    # @return String the path of the processed file, ready for serving
    def process to = nil
      return if @processing # prevent infinite recursion
      start_time = Time.now
      hash = md5
      if hash != @last_md5
        find_directives
      end

      depends = @directives[:slinky_depends].map{|f|
        p = parent.find_by_path(f, true)
        $stderr.puts "File #{f} depended on by #{@source} not found".foreground(:red) unless p.size > 0
        p
      }.flatten.compact if @directives[:slinky_depends]
      depends ||= []
      @processing = true
      # process each file on which we're dependent, watching out for 
      # infinite loops
      depends.each{|f| f.process }
      @processing = false

      # get hash of source file
      if @last_path && hash == @last_md5 && depends.all?{|f| f.updated < start_time}
        @last_path
      else
        @last_md5 = hash
        @updated = Time.now
        # mangle file appropriately
        @last_path = handle_directives((compile @source), to)
      end
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
      begin 
        path = process to
      rescue
        raise BuildFailedError
      end

      if !path
        raise BuildFailedError
      elsif path != to
        FileUtils.cp(path.to_s, to.to_s)
        @last_built = Time.now
      end
      to
    end

    def to_s
      "<Slinky::ManifestFile '#{@source}'>"
    end
  end
end
