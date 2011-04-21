module Slinky
  class Manifest
    attr_accessor :manifest_dir
    def self.build dir
      md = build_rec dir
      Manifest.new md
    end

    def self.build_rec dir
      md = ManifestDir.new dir
      Dir.glob("#{dir}/*").each do |path|
        if File.new(path).directory?
          md.children << self.build(dir, m)
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
      BUILD_DIRECTIVES = {:require => /slinky_require '(.+?)'/}
      
      attr_accessor :source_path, :last_built, :build_path, :build_tasks

      def initialize source, build_tasks = [], build_path = nil
        @source = source
        @build_path = build_path || source
        @last_built = Time.new(0)
        @build_tasks = []
        @directives = []
        File.open @source do |f|
          f.read.scan 
        end
      end
    end
  end
end
