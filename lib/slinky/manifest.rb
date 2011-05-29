module Slinky
  # extensions of files that can contain build directives
  DIRECTIVE_FILES = %w["js css html"]
  
  class Manifest
    attr_accessor :manifest_dir
    def self.construct dir
      md = build_rec dir
      Manifest.new md
    end

    def self.construct_rec dir
      md = ManifestDir.new dir
      Dir.glob("#{dir}/*").each do |path|
        if File.new(path).directory?
          md.children << self.construct(dir, m)
        else
          mf = ManifestFile.new(path)
          md.files << ManifestFile.new(path)
        end
      end
      md
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

    def initialize manifest_dir
      @manifest_dir = manifest_dir
    end
  end

  class ManifestDir
    attr_accessor :path, :files, :children
    def initialize path
      @dir = dir
      @files = []
      @children = []
    end
  end

  module Slinky
    class ManifestFile
      BUILD_DIRECTIVE_REGEX = /(slinky_require)\(\s*(['"])(.+)['"]\s*\)/
      
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
            out = f.read.gsub(BUILD_DIRECTIVE_REGEX, "")
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
              matches = f.read.scan(BUILD_DIRECTIVE_REGEX).to_a
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
end
