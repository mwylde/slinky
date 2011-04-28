require 'pathname'

module Slinky
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
    BUILD_DIRECTIVES = /^\s*(slinky_require)\s+(".+"|'.+')\s*\n/
    DIRECTIVE_FILES = %w[js css sass coffee haml]
    
    attr_accessor :source, :last_built, :build_path, :build_tasks

    def initialize source
      @source = source
      @last_built = Time.new(0)
      _, _, ext = source.match(/(.+)\.(\w+)/)
      @directive_file = DIRECTIVE_FILES.include? ext
      @directives =
        if @directive_file
          File.open @source do |f|
            f.read.scan(BUILD_DIRECTIVES).collect{|x|
              [x[0], x[1][1..-2]]
            } rescue []
          end
        else
          []
        end
    end

    def build path
      puts "Copying #{File.basename(path)}"
      if @directive_file
        File.open @source do |rf|
          File.open path, "w+" do |wf|
            wf.write rf.read.gsub(BUILD_DIRECTIVES, "")
          end
        end
      else
        FileUtils.cp(@source, path)
      end
    end
  end
end
