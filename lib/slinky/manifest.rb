require 'pathname'

module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w{js css html}
  BUILD_DIRECTIVES = /(slinky_require)\(\s*(['"])(.+)['"]\s*\)/
  
  class Manifest
    attr_accessor :manifest_dir

    def initialize dir
      @manifest_dir = ManifestDir.new dir
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

    def build build_dir
      @manifest_dir.build build_dir
    end
  end

  class ManifestDir
    attr_accessor :dir, :files, :children
    def initialize dir
      @dir = dir
      @files = []
      @children = []

      Dir.glob("#{dir}/*").each do |path|
        if File.directory? path
          @children << ManifestDir.new(path)
        else
          mf = ManifestFile.new(path)
          @files << ManifestFile.new(path)
        end
      end
    end

    def build build_dir
      p = Pathname.new(build_dir)
      if !p.exist?
        p.mkdir
      end
      @files.each{|mf|
        path = (p + File.basename(mf.source)).cleanpath
        mf.build path
      }
      @children.each{|c|
        path = (p + File.basename(c.dir)).cleanpath
        c.build path
      }
    end
  end

  class ManifestFile
    attr_accessor :source_path, :build_path
    attr_reader :last_built, :relative_dir

    def initialize source, project_dir, build_tasks = []
      @source = File.realpath(source)
      @last_built = Time.new(0)
      project_dir = File.realpath(project_dir)
      @relative_dir =
        File.dirname(@source.gsub(project_dir, ""))

      @cfile = Compilers.cfile_for_file(source)

      @directives = find_directives      
    end

    def build dir
      # mangle file appropriately
      path = @source
      if @cfile
        @cfile.file do |cpath, _, _, _|
          path = cpath
        end
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

      # copy built file to proper place in build tree
      build_dir = File.realpath(dir) + @relative_dir
      FileUtils.mkdir_p(build_dir)
      filename = File.basename(@source)
      FileUtils.cp(path, build_dir + "/" + filename)
      @last_built = Time.now
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

      directives
    end
  end
end
