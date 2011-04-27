require 'pathname'

module Slinky
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

    def build build_dir
      p = Pathname.new(build_dir)
      @manifest_dir.files.each{|mf|
        path = (p + File.basename(mf.source_path)).realpath
        mf.build path
      }
      @manifest_dir.children.each{|c|
        c.build (p + File.basename(c.path)).realpath
      }
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
      BUILD_DIRECTIVES = /^\s*(slinky_require)\s+(".+"|'.+')\s*\n/
      
      attr_accessor :source_path, :last_built, :build_path, :build_tasks

      def initialize source
        @source = source
        @last_built = Time.new(0)
        @directives = File.open @source do |f|
          f.read.scan(BUILD_DIRECTIVES).collect{|x|
            [x[0], x[1][1..-2]]
          }
        end
      end

      def build path
        File.open @source do |rf|
          File.open path, "w+" do |wf|
            wf.write rf.read.gsub(BUILD_DIRECTIVES, "")
          end
        end
      end
      
    end
  end
end
