require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Manifest" do
  before :each do
    @mprod = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
    @mdevel = Slinky::Manifest.new("/src", @config)
    @md_prod = @mprod.manifest_dir
    @md_devel = @mdevel.manifest_dir
  end

  context "General" do
    it "should build manifest dir with all files in current dir" do
      @md_prod.files.collect{|f| f.source}.should == ["/src/test.haml"]
      @md_devel.files.collect{|f| f.source}.should == ["/src/test.haml"]
    end

    it "should build manifest with all files in fs" do
      @mprod.files.collect{|f|
        f.source
      }.sort.should == @files.collect{|x| "/src/" + x}.sort
      @mdevel.files.collect{|f|
        f.source
      }.sort.should == @files.collect{|x| "/src/" + x}.sort
    end

    it "should not include dot files" do
      File.open("/src/.index.haml.swp", "w+"){|f| f.write("x")}
      manifest = Slinky::Manifest.new("/src", @config)
      manifest.files.map{|x| x.source}.include?("/src/.index.haml.swp").should == false
    end

    it "should be able to compute a hash for the entire manifest" do
      m = @mdevel
      hash1 = m.md5
      File.open("/src/hello.html", "w+") {|f| f.write("Hell!") }
      m.add_all_by_path(["/src/hello.html"])
      m.md5.should_not == hash1
    end

    it "should find files in the manifest by path" do
      @mdevel.find_by_path("test.haml").first.source.should == "/src/test.haml"
      @mdevel.find_by_path("asdf.haml").first.should == nil
      @mdevel.find_by_path("l1/l2/test.txt").first.source.should == "/src/l1/l2/test.txt"
      @mdevel.find_by_path("l1/test.css").first.source.should == "/src/l1/test.sass"
      l1 = @mdevel.manifest_dir.children.find{|c| c.dir == "/src/l1"}
      l1.find_by_path("../test.haml").first.source.should == "/src/test.haml"
    end

    it "should produce the correct scripts string for production" do
      @mprod.scripts_string.should match \
                                     %r!<script type="text/javascript" src="/scripts.js\?\d+"></script>!
    end

    it "should produce the correct scripts string for devel" do
      @mdevel.scripts_string.should == [
        '<script type="text/javascript" src="/l1/test5.js"></script>',
        '<script type="text/javascript" src="/l1/test2.js"></script>',
        '<script type="text/javascript" src="/l1/l2/test6.js"></script>',        
        '<script type="text/javascript" src="/l1/l2/test3.js"></script>',
        '<script type="text/javascript" src="/l1/test.js"></script>'].join("\n")
    end

    it "should produce the correct styles string for production" do
      @mprod.styles_string.should match \
                                    %r!<link rel="stylesheet" href="/styles.css\?\d+" />!
    end

    it "should produce the correct styles string for development" do
      File.open("/src/l1/l2/bad.sass", "w+"){|f|
        f.write "require('../test.sass')\ncolor: red;"
      }
      manifest = Slinky::Manifest.new("/src", @config)
      @mdevel.styles_string.should == [
        '<link rel="stylesheet" href="/l1/test.css" />',
        '<link rel="stylesheet" href="/l1/l2/test2.css" />'].join("\n")
    end

    it "should allow the creation of ManifestFiles" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "", @mprod)
    end

    it "should correctly determine output_path" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      mf.output_path.to_s.should == "/src/test.html"
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      mf.output_path.to_s.should == "/src/l1/test.js"
    end

    it "should correctly determine relative_output_path" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      mf.relative_output_path.to_s.should == "test.html"
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      mf.relative_output_path.to_s.should == "l1/test.js"
    end

    it "should build tmp file without directives" do
      original = "/src/test.haml"
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      path = mf.handle_directives mf.source
      File.read(original).match(/slinky_scripts|slinky_styles/).should_not == nil
      File.read(path).match(/slinky_scripts|slinky_styles/).should == nil
    end

    it "should build tmp file without directives for .js" do
      original = "/src/l1/test.js"
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      path = mf.handle_directives mf.source
      File.read(original).match(/slinky_require/).should_not == nil
      File.read(path).match(/slinky_require/).should == nil
    end

    it "should compile files that need it" do
      $stdout.should_receive(:puts).with("Compiled /src/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      FileUtils.mkdir("/src/build")
      build_path = mf.process mf.build_to
      build_path.to_s.split(".")[-1].should == "html"
      File.read("/src/test.haml").match("<head>").should == nil
      File.read(build_path).match("<head>").should_not == nil

      $stdout.should_receive(:puts).with("Compiled /src/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      build_path = mf.process "/src/build/test.html"
      File.read("/src/build/test.html").match("<head>").should_not == nil
      FileUtils.rm_rf("/src/build") rescue nil
    end

    it "should give the proper error message for compilers with unmet dependencies" do
      File.open("/src/test.fake", "w+"){|f| f.write("hello, fake data")}
      $stderr.should_receive(:puts).with(/Missing dependency/)
      mf = Slinky::ManifestFile.new("/src/test.fake", "/src/build", @mprod)
      build_path = mf.process
    end

    it "should report errors for bad files" do      
      File.open("/src/l1/l2/bad.sass", "w+"){|f|
        f.write "color: red;"
      }
      mf = Slinky::ManifestFile.new("/src/l1/l2/bad.sass", "/src/build", @mprod)
      expect { mf.process }.to raise_error Slinky::BuildFailedError
    end

    it "shouldn't crash on syntax errors" do
      File.open("/src/l1/asdf.haml", "w+"){|f|
        f.write("%h1{:width => 50px}")
      }
      mf = Slinky::ManifestFile.new("/src/l1/asdf.haml", "/src/build", @mprod)
      expect { mf.process }.to raise_error Slinky::BuildFailedError
    end

    it "should properly determine build directives" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      mf.find_directives.should == {:slinky_scripts => [], :slinky_styles => []}
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      mf.find_directives.should == {:slinky_require => ["test2.js", "l2/test3.js"]}
    end

    it "should properly find depends directives" do
      File.open("/src/depends.sass", "w+") {|f|
        f.write('// slinky_depends("/something.sass")')
      }
      mf = Slinky::ManifestFile.new("/src/depends.sass", "/src/build", @mprod)
      mf.find_directives.should == {:slinky_depends => ["/something.sass"]}
    end

    it "should properly determine build_to path" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      mf.build_to.should == Pathname.new("/src/build/test.html")
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      mf.build_to.should == Pathname.new("/src/build/test.js")
    end

    it "should build both compiled files and non-compiled files" do
      $stdout.should_receive(:puts).with("Compiled /src/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      path = mf.build
      path.to_s.should == "/src/build/test.html"
      File.read("/src/test.haml").match("<head>").should == nil
      File.read(path).match("<head>").should_not == nil

      $stdout.should_not_receive(:puts)
      mf = Slinky::ManifestFile.new("/src/l1/l2/test.txt", "/src/build/l1/l2", @mprod)
      path = mf.build
      path.to_s.should == "/src/build/l1/l2/test.txt"
      File.read("/src/build/l1/l2/test.txt").should == "hello\n"
    end

    it "should match files" do
      mf = Slinky::ManifestFile.new("/src/l1/l2/test.txt", "/src/build/l1/l2", @mprod)
      mf.matches?("test.txt").should == true
      mf = Slinky::ManifestFile.new("/src/l1/test.sass", "", @mprod)
      mf.matches?("test.css").should == true
      mf.matches?("test.sass").should == true
    end

    it "should match file paths" do
      mf = Slinky::ManifestFile.new("/src/l1/l2/test.txt", "/src/build/l1/l2", @mprod)
      mf.matches_path?("test.txt").should == false
      mf.matches_path?("/l1/l2/test.txt").should == true
      mf.matches_path?("/l1/l2/*.txt").should == false
      mf.matches_path?("/l1/l2/*.txt", true).should == true
      mf = Slinky::ManifestFile.new("/src/l1/test.sass", "", @mprod)
      mf.matches_path?("/l1/test.css").should == true
      mf.matches_path?("/l1/test.sass").should == true
      mf.matches_path?("/l1/*.css", true).should == true
      mf.matches_path?("/l1/*.sass", true).should == true
      mf.matches_path?("l1/test.sass").should == false
    end

    it "should should properly determine if in tree" do
      mf = Slinky::ManifestFile.new("/src/l1/l2/test.txt", "/src/build/l1/l2", @mprod)
      mf.in_tree?("/l1").should == true
      mf.in_tree?("/l1/l2").should == true
      mf.in_tree?("/l1/l2/test.txt").should == true
      mf.in_tree?("/l1/l3").should == false
      mf.in_tree?("test.txt").should == false
    end

    it "should correctly build the dependency graph" do
      @mprod.dependency_graph.collect{|x| x.collect{|y| y.source}}.sort.should ==
        [["/src/l1/test2.js", "/src/l1/test.js"],
         ["/src/l1/l2/test3.coffee", "/src/l1/test.js"],
         ["/src/l1/test5.js", "/src/l1/test2.js"],
         ["/src/l1/l2/test6.js", "/src/l1/l2/test3.coffee"]].sort
    end

    it "should fail if a required file isn't in the manifest" do
      FileUtils.rm("/src/l1/test2.js")
      manifest = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
      proc {
        manifest.dependency_graph
      }.should raise_error Slinky::FileNotFoundError
    end

    it "should build a correct dependency list" do
      @mprod.dependency_list.collect{|x| x.source}.should == ["/src/test.haml", "/src/l1/test5.js", "/src/l1/test2.js", "/src/l1/l2/test6.js", "/src/l1/l2/test3.coffee", "/src/l1/test.js", "/src/l1/test.sass", "/src/l1/l2/test.txt", "/src/l1/l2/test2.css", "/src/l1/l2/l3/test2.txt"]
    end

    it "should fail if there is a cycle in the dependency graph" do
      File.open("/src/l1/test5.js", "w+"){|f| f.write("slinky_require('test.js')")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
      proc { manifest.dependency_list }.should raise_error Slinky::DependencyError
    end

    it "should handle depends directives" do
      File.open("/src/l1/test5.coffee", "w+"){|f| f.write("slinky_depends('test.sass')")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test5.js").first
      f.should_not == nil
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test5.coffee/)
      f.process
    end

    it "should handle external depends directives" do
      Dir.mkdir("/external")
      File.open("/external/file.js", "w+"){|f| f.write("Hello!") }
      File.open("/src/l1/test5.coffee", "w+"){|f| f.write("slinky_depends_external('../external/*.js')")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test5.js").first
      f.should_not == nil
      f.external_dependencies.should == ["/external/file.js"]
      f.external_dependencies_updated?.should == true

      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test5.coffee/)
      f.process

      f.external_dependencies_updated?.should == false
    end

    it "should handle depends directives with glob patterns" do
      File.open("/src/l1/test5.coffee", "w+"){|f| f.write("slinky_depends('*.sass')")}
      File.open("/src/l1/test2.sass", "w+"){|f| f.write("body\n\tcolor: red")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test5.js").first
      f.should_not == nil
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test2.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test5.coffee/)
      f.process
    end

    it "should handle depends directives with **" do
      File.open("/src/l1/test5.coffee", "w+"){|f| f.write("slinky_depends('/l1/**/*.sass')")}
      File.open("/src/l1/l2/test5.sass", "w+"){|f| f.write("body\n\tcolor: red")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test5.js").first
      f.should_not == nil
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/l2\/test5.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test5.coffee/)
      f.process
    end
    
    it "should handle depends directives with infinite loops" do
      File.open("/src/l1/test5.coffee", "w+"){|f| f.write("slinky_depends('*.sass')")}
      File.open("/src/l1/test2.sass", "w+"){|f| f.write("/* slinky_depends('*.coffee')")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test5.js").first
      f.should_not == nil
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test2.sass/)
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/test5.coffee/)
      f.process
    end

    it "should handle depends directives in config" do
      cf "/depend/script/vendor/backbone.js"
      cf "/depend/script/vendor/jquery.js"
      cf "/depend/script/vendor/underscore.js"

      config = <<eos
dependencies:
  "/script/vendor/backbone.js":
      - "/script/vendor/jquery.js"
      - "/script/vendor/underscore.js"
eos
      config = Slinky::ConfigReader.new(config)

      mdevel = Slinky::Manifest.new("/depend", config, :devel => true)

      files = mdevel.files_for_product("/scripts.js").map{|x| x.source}
      files[2].should == "/depend/script/vendor/backbone.js"
    end

    it "should cache files" do
      File.open("/src/l1/cache.coffee", "w+"){|f| f.write("() -> 'hello, world!'\n")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/cache.js").first
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/cache.coffee/)
      f.process
      f.process
      File.open("/src/l1/cache.coffee", "a"){|f| f.write("() -> 'goodbye, world!'\n")}
      $stdout.should_receive(:puts).with(/Compiled \/src\/l1\/cache.coffee/)
      f.process
    end

    it "should handle new directives" do
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/test.js").first
      f.process
      f.directives.should == {:slinky_require=>["test2.js", "l2/test3.js"]}
      File.open("/src/l1/test.js", "a"){|f| f.write("slinky_require('test5.js')\n")}
      f.process
      f.directives.should == {:slinky_require=>["test2.js", "l2/test3.js", "test5.js"]}
    end

    it "should detect new files" do
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      File.open("/src/l1/cache.coffee", "w+"){|f| f.write("console.log 'hello'")}
      manifest.add_all_by_path(["/src/l1/cache.coffee"])
      f = manifest.find_by_path("l1/cache.js").first
      f.should_not == nil
      manifest.scripts_string.match("cache.js").should_not == nil
      FileUtils.mkdir("/src/l1/hello")
      File.open("/src/l1/hello/asdf.sass", "w+"){|f| f.write("hello")}
      f = manifest.find_by_path("l1/hello/asdf.sass")
      f.should_not == nil
    end

    it "should handle deletion of files" do
      File.open("/src/l1/cache.coffee", "w+"){|f| f.write("console.log 'hello'")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => true)
      f = manifest.find_by_path("l1/cache.coffee").first
      f.should_not == nil
      manifest.scripts_string.match("l1/cache.js").should_not == nil

      FileUtils.rm("/src/l1/cache.coffee")
      File.exists?("/src/l1/cache.coffee").should == false
      manifest.remove_all_by_path(["/src/l1/cache.coffee"])
      f = manifest.find_by_path("l1/cache.coffee").first
      f.should == nil
      manifest.scripts_string.match("l1/cache.js").should == nil
    end

    it "should ignore the build directory" do
      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(6).times
      options = {:src_dir => "/src", :build_dir => "/src/build"}
      Slinky::Builder.build(options, @config)
      File.exists?("/src/build/build").should_not == true
      File.exists?("/src/build/test.html").should == true
      Slinky::Builder.build(options, @config)
      File.exists?("/src/build/build").should == false
    end

    it "should combine and compress javascript" do
      FileUtils.rm_rf("/build") rescue nil
      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times
      @mprod.build
      File.exists?("/build/scripts.js").should == true
      File.size("/build/scripts.js").should > 90
      File.read("/build/scripts.js").match('"Hello, world"').should_not == nil
      File.exists?("/build/l1/test.js").should == false
    end

    it "should combine and compress css" do
      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times
      @mprod.build
      File.exists?("/build/styles.css").should == true
      File.size("/build/styles.css").should > 25
      File.read("/build/styles.css").match(/color:\s*red/).should_not == nil
      File.exists?("/build/l1/test.css").should == false
    end

    it "should modify css urls to point to correct paths when compiled" do
      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times
      @mprod.build
      css = File.read("/build/styles.css")
      css.include?("url('/l1/asdf.png')").should == true
      css.include?("url('/l1/bg.png')").should == true
      css.include?("url('/l1/l2/l3/hello.png')").should == true
    end

    it "should properly filter out ignores in files list" do
      config = Slinky::ConfigReader.new("ignore:\n  - /l1/test2.js")
      config.ignore.should == ["/l1/test2.js"]
      mdevel = Slinky::Manifest.new("/src", config)
      mfiles = mdevel.files(false).map{|x| x.source}.sort
      files = (@files - ["l1/test2.js"]).map{|x| "/src/" + x}.sort
      mfiles.should == files
      # double check
      mfiles.include?("/src/l1/test2.js").should == false
    end

    it "should properly filter out relative ignores in files list" do
      config = Slinky::ConfigReader.new("ignore:\n  - l1/test2.js")
      config.ignore.should == ["l1/test2.js"]
      mdevel = Slinky::Manifest.new("/src", config)
      mfiles = mdevel.files(false).map{|x| x.source}.sort
      files = (@files - ["l1/test2.js"]).map{|x| "/src/" + x}.sort
      mfiles.should == files
      # double check
      mfiles.include?("/src/l1/test2.js").should == false
    end

    it "should properly filter out directory ignores in files list" do
      config = Slinky::ConfigReader.new("ignore:\n  - /l1/l2")
      config.ignore.should == ["/l1/l2"]
      mdevel = Slinky::Manifest.new("/src", config)
      mfiles = mdevel.files(false).map{|x| x.source}.sort
      files = (@files.reject{|x| x.start_with?("l1/l2")}).map{|x| "/src/" + x}.sort
      mfiles.should == files
    end

    it "should properly handle ignores for scripts" do
      File.open("/src/l1/l2/ignore.js", "w+"){|f| f.write("IGNORE!!!")}
      config = Slinky::ConfigReader.new("ignore:\n  - /l1/l2/ignore.js")
      config.ignore.should == ["/l1/l2/ignore.js"]

      mdevel = Slinky::Manifest.new("/src", config)
      mdevel.scripts_string.scan(/src=\"(.+?)\"/).flatten.
        include?("/l1/l2/ignore.js").should == false

      mprod = Slinky::Manifest.new("/src", config, :devel => false,
                                   :build_to => "/build")

      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times      
      mprod.build

      File.read("/build/scripts.js").include?("IGNORE!!!").should == false
    end

    it "should properly handle ignores for styles" do
      File.open("/src/l1/l2/ignore.css", "w+"){|f| f.write("IGNORE!!!")}
      config = Slinky::ConfigReader.new("ignore:\n  - /l1/l2/ignore.css")
      config.ignore.should == ["/l1/l2/ignore.css"]

      mdevel = Slinky::Manifest.new("/src", config)
      mdevel.styles_string.scan(/href=\"(.+?)\"/).flatten.
        include?("/l1/l2/ignore.css").should == false

      mprod = Slinky::Manifest.new("/src", config, :devel => false,
                                   :build_to => "/build")

      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times      
      mprod.build

      File.read("/build/styles.css").include?("IGNORE!!!").should == false
    end

    it "should recompile files when files they depend on change" do
      $stdout.should_receive(:puts).with(/Compiled .+/).exactly(4).times

      # We can't use FakeFS with SassC
      FakeFS.without do
        dir = Dir.mktmpdir
        begin
          FileUtils.mkdir("#{dir}/l1")
          File.open("#{dir}/l1/depender.scss", "w+"){|f|
            f.write("// slinky_depends('/l1/_dependee.scss')\n")
            f.write("@import \"dependee\";\n")
            f.write("body { color: $bodycolor }\n")
          }
          File.open("#{dir}/l1/_dependee.scss", "w+"){|f|
            f.write("$bodycolor: red;\n")
          }

          mdevel = Slinky::Manifest.new(dir, @config)

          mf = mdevel.find_by_path("/l1/depender.scss").first
          path = mf.process
          File.read(path).should match /color: red/

          File.open("#{dir}/l1/_dependee.scss", "w+"){|f|
            f.write("$bodycolor: green;\n")
          }

          mf = mdevel.find_by_path("/l1/depender.scss").first
          path = mf.process
          File.read(path).should match /color: green/
        ensure
          FileUtils.rm_rf(dir)
        end          
      end
    end
  end

  context "FindByPattern" do
    def test(md, pattern, files)
      md.find_by_pattern(pattern).map{|mf| mf.relative_source_path.to_s}
        .sort.should == files.sort
    end

    before :all do
      FileUtils.mkdir("/find")

      cf("/find/main.js")
      cf("/find/main/main.js")
      cf("/find/main/test.js")
      cf("/find/src/main.coffee")
      cf("/find/src/main_test.js")
      cf("/find/src/main/main.js")
      cf("/find/src/component/main.js")
      cf("/find/src/component/test.js")
      cf("/find/src/component/test/test.js")

      @md = Slinky::Manifest.new("/find", @config, :devel => false)
    end

    it "find_by_pattern should follow rule #1" do
      test(@md, "/src/", [
             "src/main.coffee",
             "src/main_test.js",
             "src/main/main.js",
             "src/component/main.js",
             "src/component/test.js",
             "src/component/test/test.js"
           ])
    end

    it "find_by_pattern should follow rule #2" do
      test(@md, "test.js", ["main/test.js",
                           "src/component/test.js",
                           "src/component/test/test.js"])
    end

    it "find_by_pattern should follow rule #3" do
      test(@md, "/main/*.js", [
             "main/main.js",
             "main/test.js"
           ])
    end

    it "find_by_pattern should follow rule #4" do
      test(@md, "main/", [
             "main/main.js",
             "main/test.js",
             "src/main/main.js"
           ])

      test(@md, "main/main*", [
             "main/main.js",
             "src/main/main.js"
           ])
    end

    it "find_by_pattern should follow rule #5" do
      test(@md, "/*/*.js", [
             "main/main.js",
             "main/test.js",
             "src/main.coffee",
             "src/main_test.js"
           ])

      test(@md, "/*/*test.js", [
             "main/test.js",
             "src/main_test.js"
           ])
    end

    it "find_by_pattern should follow rule #6" do
      test(@md, "/**/*.js", [
             "main.js",
             "main/main.js",
             "main/test.js",
             "src/main.coffee",
             "src/main_test.js",
             "src/main/main.js",
             "src/component/main.js",
             "src/component/test.js",
             "src/component/test/test.js"
           ])

      test(@md, "src/**/*.js", [
             "src/main.coffee",
             "src/main_test.js",
             "src/main/main.js",
             "src/component/main.js",
             "src/component/test.js",
             "src/component/test/test.js"
           ])
    end
  end

  context "Products" do
    it "should fail if non-configured product is requested" do
      proc { @mdevel.files_for_product("/something.js") }
        .should raise_error Slinky::NoSuchProductError
    end

    it "should allow specification of products" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/*.js"
    exclude:
      - "/l1/exclude.js"
eos
      config = Slinky::ConfigReader.new(config)
      config.produce.should == {"/special.js" => {
                                   "include" => ["/l1/*.js"],
                                   "exclude" => ["/l1/exclude.js"]
                                }}

      File.open("/src/l1/exclude.js", "w+").close

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)

      mdevel.files_for_product("/special.js")
        .map{|x| x.source}.sort.should == [
        "/src/l1/test2.js", "/src/l1/test.js", "/src/l1/test5.js",
        "/src/l1/l2/test3.coffee", "/src/l1/l2/test6.js"].sort
    end

    it "should not require an exclude for products" do
      config = {"produce" => {"/special.js" => {"include" => ["/l1/*.js"]}}}

      config = Slinky::ConfigReader.new(config)

      File.open("/src/l1/exclude.js", "w+").close

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)

      mdevel.files_for_product("/special.js")
        .map{|x| x.source}.sort.should == ["/src/l1/exclude.js",
                                           "/src/l1/l2/test3.coffee",
                                           "/src/l1/l2/test6.js",
                                           "/src/l1/test.js",
                                           "/src/l1/test2.js",
                                           "/src/l1/test5.js"].sort
    end

    it "should support full match syntax for excludes" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/*.js"
    exclude:
      - "exclude.js"
eos
      config = Slinky::ConfigReader.new(config)
      config.produce.should == {"/special.js" => {
                                  "include" => ["/l1/*.js"],
                                  "exclude" => ["exclude.js"]
                                }}

      File.open("/src/l1/exclude.js", "w+").close

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)

      mdevel.files_for_product("/special.js")
        .map{|x| x.source}.sort.should == [
        "/src/l1/test2.js", "/src/l1/test.js", "/src/l1/test5.js",
        "/src/l1/l2/test3.coffee", "/src/l1/l2/test6.js"].sort
    end
    
    it "should fail if a product rule does not match anything" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/doesntexist.js"
eos
      config = Slinky::ConfigReader.new(config)

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)

      proc { mdevel.files_for_product("/special.js") }
        .should raise_error Slinky::FileNotFoundError
    end

    it "should allow product directives" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/*.js"
eos
      config = Slinky::ConfigReader.new(config)

      File.open("/src/product.html", "w+"){|f|
        f.write("<html><head>\nslinky_product('/special.js')\n</head></html")
      }

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)
      path = mdevel.find_by_path("/product.html").first.process(nil, true)

      contents = File.read(path)
      contents.include?("slinky_product").should == false
      contents.include?('<script type="text/javascript" src="/l1/test.js">').
        should == true
    end

    it "should full match syntax" do
      config = {"produce" => {"/special.js" => {"include" => ["/l1/**/*.js"]}}}

      config = Slinky::ConfigReader.new(config)

      mdevel = Slinky::Manifest.new("/src", config, :devel => true)

      mdevel.files_for_product("/special.js")
        .map{|x| x.source}.sort.should == ["/src/l1/l2/test3.coffee",
                                           "/src/l1/l2/test6.js",
                                           "/src/l1/test.js",
                                           "/src/l1/test2.js",
                                           "/src/l1/test5.js"].sort
    end

    it "should build products in production mode" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/*.js"
eos
      config = Slinky::ConfigReader.new(config)

      File.open("/src/product.html", "w+"){|f|
        f.write("<html><head>\nslinky_product('/special.js')\n</head></html")
      }

      mprod = Slinky::Manifest.new("/src",
                                   config,
                                   :devel => false,
                                   :build_to => "/build_special")

      $stdout.should_receive(:puts).with(/Compiled/).exactly(2).times
      path = mprod.find_by_path("/product.html").first.process(nil, true)
      mprod.build

      File.exists?("/build_special/special.js").should == true
      File.read("/build_special/special.js").
        include?('console.log("Hello!");').should == true
      File.exists?("/build_special/scripts.js").should == false
      File.exists?("/build_special/styles.css").should == false
    end

    it "should build products inside directories" do
      config = <<eos
produce:
  "/d1/d2/d3/special.js":
    include:
      - "/l1/*.js"
eos
      config = Slinky::ConfigReader.new(config)

      mprod = Slinky::Manifest.new("/src",
                                   config,
                                   :devel => false,
                                   :build_to => "/build_nested")

      $stdout.should_receive(:puts).with(/Compiled/).exactly(2).times
      mprod.build

      File.exists?("/build_nested/d1/d2/d3/special.js").should == true
    end

    it "should not build scripts if they are not included in products" do
      config = <<eos
produce:
  "/special.js":
    include:
      - "/l1/l2/test6.js"
eos
      config = Slinky::ConfigReader.new(config)

      File.open("/src/product.html", "w+"){|f|
        f.write("<html><head>\nslinky_product('/special.js')\n</head></html")
      }

      mprod = Slinky::Manifest.new("/src",
                                   config,
                                   :devel => false,
                                   :build_to => "/build_special")

      $stdout.should_receive(:puts).with(/Compiled/).exactly(1).times
      path = mprod.find_by_path("/product.html").first.process(nil, true)
      mprod.build

      File.exists?("/build_special/special.js").should == true
      File.read("/build_special/special.js").
        include?('console.log("Hello!");').should == false
      File.exists?("/build_special/scripts.js").should == false
      File.exists?("/build_special/styles.css").should == false
    end
  end
end
