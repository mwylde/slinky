require 'pathname'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html}
  BUILD_DIRECTIVES = /(slinky_require)\(\s*(['"])(.+)['"]\s*\)/
  
  class Manifest
    attr_accessor :manifest_dir

    def initialize dir, build_dir
      @manifest_dir = ManifestDir.new dir, build_dir
    end

    def files
      files_rec @manifest_dir, []
    end
    
    def files_rec md, f
      f += md.files
      md.children.each do |c|
        files_rec c, f
      end
      f
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
        next if path == build_dir
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
    attr_reader :last_built

    def initialize source, build_path
      @source = File.realpath(source)
      @last_built = Time.new(0)

      @cfile = Compilers.cfile_for_file(@source)

      @directives = find_directives
      @build_path = build_path
    end

    def build
      # mangle file appropriately
      path = @source
      build_path = @build_path
      if @cfile
        @cfile.file do |cpath, _, _, _|
          path = cpath
        end
        build_path = build_path.sub_ext @cfile.output_ext
      end
      if @directives
        File.open(path) do |f|
          out = f.read.gsub(BUILD_DIRECTIVES, "")
          path = Tempfile.new("slinky").path
          File.open(path, "w+") do |f|
            f.write(out)
          end
        end
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
      directives = []
      # check if this file might include directives
      if @cfile || DIRECTIVE_FILES.include?(ext)
        # make sure the file isn't too big to scan
        stat = File::Stat.new(@source)
        if stat.size < 1024*1024
          File.open(@source) {|f|
            matches = f.read.scan(BUILD_DIRECTIVES).to_a
            matches.each_slice(2) {|slice|
              key, value = slice
              directives[key.to_sym] ||= []
              directives[key.to_sym] << value
            }
          } rescue nil
        end
      end

      directives && directives.size > 0 ? directives : nil
    end
  end
end
