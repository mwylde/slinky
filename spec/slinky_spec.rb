require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'em-http'

describe "Slinky" do
  context "Runner" do
    it "should output help" do
      $stdout.should_receive(:puts).with(/Usage: slinky/)
      lambda { ::Slinky::Runner.new(["--help"]).run }.should raise_error SystemExit
    end

    it "should output a version" do
      $stdout.should_receive(:puts).with(/slinky \d+\.\d+\.\d+/)
      FakeFS.deactivate!
      lambda { ::Slinky::Runner.new(["--version"]).run }.should raise_error SystemExit
      FakeFS.activate!
    end
  end

  context "Manifest" do
    before :each do
      @mprod = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
      @mdevel = Slinky::Manifest.new("/src", @config)
      @md_prod = @mprod.manifest_dir
      @md_devel = @mdevel.manifest_dir
    end

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
      $stdout.should_receive(:puts).with("Compiled /src/test.haml".foreground(:green)).exactly(2).times
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
        '<script type="text/javascript" src="/l1/l2/test6.js"></script>',
        '<script type="text/javascript" src="/l1/test2.js"></script>',
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
      $stderr.should_receive(:puts).with(/Failed on/)
      mf = Slinky::ManifestFile.new("/src/l1/l2/bad.sass", "/src/build", @mprod)
      build_path = mf.process
      build_path.should == nil
    end

    it "shouldn't crash on syntax errors" do
      File.open("/src/l1/asdf.haml", "w+"){|f|
        f.write("%h1{:width => 50px}")
      }
      $stderr.should_receive(:puts).with(/Failed on/)
      mf = Slinky::ManifestFile.new("/src/l1/asdf.haml", "/src/build", @mprod)
      build_path = mf.process
      build_path.should == nil
    end

    it "should properly determine build directives" do
      mf = Slinky::ManifestFile.new("/src/test.haml", "/src/build", @mprod)
      mf.find_directives.should == {:slinky_scripts => [], :slinky_styles => []}
      mf = Slinky::ManifestFile.new("/src/l1/test.js", "/src/build", @mprod)
      mf.find_directives.should == {:slinky_require => ["test2.js", "l2/test3.js"]}
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
      mf = Slinky::ManifestFile.new("/src/l1/test.sass", "", @prod)
      mf.matches?("test.css").should == true
      mf.matches?("test.sass").should == true
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
      @mprod.build_dependency_graph.collect{|x| x.collect{|y| y.source}}.sort.should ==
        [["/src/l1/test2.js", "/src/l1/test.js"],
         ["/src/l1/l2/test3.coffee", "/src/l1/test.js"],
         ["/src/l1/test5.js", "/src/l1/test2.js"],
         ["/src/l1/l2/test6.js", "/src/l1/l2/test3.coffee"]].sort
    end

    it "should fail if a required file isn't in the manifest" do
      FileUtils.rm("/src/l1/test2.js")
      manifest = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
      $stderr.should_receive(:puts).with("Could not find file test2.js required by /src/l1/test.js".foreground(:red))
      proc {
        manifest.build_dependency_graph
      }.should raise_error Slinky::FileNotFoundError
    end

    it "should build a correct dependency list" do
      @mprod.dependency_list.collect{|x| x.source}.should == ["/src/test.haml", "/src/l1/test.sass", "/src/l1/test5.js", "/src/l1/l2/test.txt", "/src/l1/l2/test2.css", "/src/l1/l2/test6.js", "/src/l1/l2/l3/test2.txt", "/src/l1/test2.js", "/src/l1/l2/test3.coffee", "/src/l1/test.js"]
    end

    it "should fail if there is a cycle in the dependency graph" do
      File.open("/src/l1/test5.js", "w+"){|f| f.write("slinky_require('test.js')")}
      manifest = Slinky::Manifest.new("/src", @config, :devel => false, :build_to => "/build")
      $stderr.should_receive(:puts).with("Dependencies /src/l1/test2.js -> /src/l1/test.js, /src/l1/test5.js -> /src/l1/test2.js, /src/l1/test.js -> /src/l1/test5.js could not be satisfied".foreground(:red))
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
      $stdout.should_receive(:puts).with(/Compiled \/src\/test.haml/)
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
      $stdout.should_receive(:puts).with(/Compiled \/src\/test.haml/)
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
      File.exists?("/build/l1/l2/ignore.js").should == true
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
      File.exists?("/build/l1/l2/ignore.css").should == true
    end
  end

  context "Server" do
    before :each do
      @resp = double("EventMachine::DelegatedHttpResponse")
      @resp.stub(:content=){|c| @content = c}
      @resp.stub(:content){ @content }
      @mdevel = Slinky::Manifest.new("/src", @config)
    end

    it "path_for_uri should work correctly" do
      Slinky::Server.path_for_uri("http://localhost:124/test/hello/asdf.js?query=string&another").should == "test/hello/asdf.js"
    end

    it "should serve files" do
      Slinky::Server.serve_file @resp, "/src/l1/test.js"
      @resp.content.should == File.read("/src/l1/test.js")
    end

    it "should serve source files" do
      Slinky::Server.serve_file @resp, "/src/l1/l2/test3.coffee"
      @resp.content.should == File.read("/src/l1/l2/test3.coffee")
    end

    it "should serve 404s" do
      @resp.should_receive(:status=).with(404)
      Slinky::Server.serve_file @resp, "/src/asdf/faljshd"
      @resp.content.should == "File not found\n"
    end

    it "should handle static files" do
      mf = Slinky::ManifestFile.new("/src/l1/l2/test.txt", nil, @mdevel)
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == File.read("/src/l1/l2/test.txt")
    end

    it "should handle compiled files" do
      mf = Slinky::ManifestFile.new("/src/l1/test.sass", nil, @mdevel)
      $stdout.should_receive(:puts).with("Compiled /src/l1/test.sass".foreground(:green))
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == Slinky::SassCompiler::compile(File.read("/src/l1/test.sass"), "/src/l1/test.sass")
    end

    it "should handle non-existant files" do
      mf = Slinky::ManifestFile.new("/src/l1/asdf.txt", nil, @mdevel)
      @resp.should_receive(:status=).with(404)
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == "File not found\n"
    end

    it "should handle a global pushstate" do
      config = <<eos
pushstate:
  "/": "/test.html"
eos
      File.open("/src/slinky.yaml", "w+"){|f| f.write config}
      cr = Slinky::ConfigReader.from_file("/src/slinky.yaml")
      Slinky::Server.config = cr
      Slinky::Server.manifest = @mdevel
      $stdout.should_receive(:puts).with("Compiled /src/test.haml".foreground(:green))
      @resp.should_receive(:content_type).with("text/html").at_least(:once)
      Slinky::Server.process_path @resp, "this/doesnt/exist.html"
      @resp.content.include?("html").should == true
    end

    it "should not enter an infinite loop with a non-existant pushstate index" do
      config = <<eos
pushstate:
  "/": "/notreal.html"
eos
      File.open("/src/slinky.yaml", "w+"){|f| f.write config}
      cr = Slinky::ConfigReader.from_file("/src/slinky.yaml")
      Slinky::Server.config = cr
      Slinky::Server.manifest = @mdevel
      @resp.should_receive(:status=).with(404)
      @resp.should_receive(:content_type).with("text/html").at_least(:once)
      Slinky::Server.process_path @resp, "this/doesnt/exist.html"
    end

    it "should choose the more specific pushstate path when conflicts are present" do
      config = <<eos
pushstate:
  "/": "/index.html"
  "/hello": "/test.html"
eos
      File.open("/src/slinky.yaml", "w+"){|f| f.write config}
      File.open("/src/index.html", "w+"){|f| f.write("goodbye")}
      cr = Slinky::ConfigReader.from_file("/src/slinky.yaml")
      Slinky::Server.config = cr
      manifest = Slinky::Manifest.new("/src", cr)
      Slinky::Server.manifest = manifest
      @resp.should_receive(:content_type).with("text/html").at_least(:once)
      Slinky::Server.process_path @resp, "hello/doesnt/exist.html"
      @resp.content.include?("goodbye").should == true
    end

    it "should accept a port option" do
      port = 53455
      $stdout.should_receive(:puts).with(/Started static file server on port #{port}/)
      run_for 0.3 do
        Slinky::Runner.new(["start","--port", port.to_s, "--no-livereload"]).run
      end
    end

    it "should not crash for syntax errors" do
      File.open("/src/bad_file.haml", "w+"){|f| f.write("%head{") }
      mf = Slinky::ManifestFile.new("/src/bad_file.haml", nil, @mdevel)
      $stderr.should_receive(:puts).with(/Failed on/)
      @resp.should_receive(:status=).with(500)
      Slinky::Server.handle_file @resp, mf
    end

    it "should serve files for realz" do
      $stdout.should_receive(:puts).with(/Started static file server on port 43453/)
      @results = []
      File.open("/src/index.haml", "w+"){|f|
        f.write <<eos
!!5
%head
  slinky_scripts
  slinky_styles
%body
  %h1 index
eos
      }
      run_for 3 do
        Slinky::Runner.new(["start","--port", "43453", "--src-dir", "/src", "--no-livereload"]).run
        base = "http://localhost:43453"
        multi = EventMachine::MultiRequest.new
        $stdout.should_receive(:puts).with(/Compiled \/src\/index.haml/)

        # add multiple requests to the multi-handler
        multi.add(:index, EventMachine::HttpRequest.new("#{base}/index.html").get)
        multi.add(:base, EventMachine::HttpRequest.new(base).get)
        multi.callback do
          rs = [multi.responses[:callback][:index], multi.responses[:callback][:base]]
          rs.compact.size.should == 2
          rs.each{|r|
            r.response.include?("<h1>index</h1>").should == true
          }
          multi.responses[:errback].size.should == 0
          EM.stop_event_loop
        end
      end
    end
  end

  context "Builder" do
    before :each do
      @compilation_subs = {".sass" => ".css", ".coffee" => ".js", ".haml" => ".html"}
    end
    it "should build manifest to build directory" do
      $stdout.should_receive(:puts).with(/Compiled \/src\/.+/).exactly(3).times
      options = {:src_dir => "/src", :build_dir => "/build"}
      Slinky::Builder.build(options, @config)
      File.exists?("/build").should == true
      File.exists?("/build/scripts.js").should == true
      File.exists?("/build/l1/l2/test.txt").should == true
    end
  end

  context "ConfigReader" do
    before :each do
      @config = <<eos
proxy:
  "/test1": "http://127.0.0.1:8000"
  "/test2": "http://127.0.0.1:7000"
ignore:
  - script/vendor
  - script/jquery.js
port: 5555
src_dir: "src/"
build_dir: "build/"
no_proxy: true
no_livereload: true
livereload_port: 5556
dont_minify: true
pushstate:
  "/app1": "/index.html"
  "/app2": "/index2.html"
eos
      File.open("/src/slinky.yaml", "w+"){|f| f.write @config}
      @proxies = {
        "/test1" => "http://127.0.0.1:8000",
        "/test2" => "http://127.0.0.1:7000"
      }
      @ignores = ["script/vendor", "script/jquery.js"]
      @pushstates = {
        "/app1" => "/index.html",
        "/app2" => "/index2.html"
      }
    end

    it "should be able to read configuration from strings" do
      cr = Slinky::ConfigReader.new(@config)
      cr.proxy.should == @proxies
      cr.ignore.should == @ignores
    end

    it "should be able to read configuration from files" do
      cr = Slinky::ConfigReader.from_file("/src/slinky.yaml")
      cr.proxy.should == @proxies
      cr.ignore.should == @ignores
      cr.port.should == 5555
      cr.src_dir.should == "src/"
      cr.build_dir.should == "build/"
      cr.no_proxy.should == true
      cr.no_livereload.should == true
      cr.livereload_port.should == 5556
      cr.dont_minify.should == true
      cr.pushstate.should == @pushstates
    end

    it "should be able to create the empty config" do
      Slinky::ConfigReader.empty.proxy.should == {}
      Slinky::ConfigReader.empty.ignore.should == []
    end

    it "should error on invalid configuration" do
      config = <<eos
invalid:
  -script/vendor
eos
      proc { Slinky::ConfigReader.new(config) }
        .should raise_error Slinky::InvalidConfigError
    end
  end

  context "ProxyServer" do
    before :each do
      @config = <<eos
proxy:
  "/test1": "http://127.0.0.1:8000"
  "/test2/": "http://127.0.0.1:7000"
eos
      @cr = Slinky::ConfigReader.new(@config)
      @proxies = Slinky::ProxyServer.process_proxies(@cr.proxy)
      @data = <<eos
GET /test1/something/and?q=asdf&c=E9oBiwFqZmoJam9uYXNmdXAyclkLEj0KABoMQ29ja3RhaWxJbXBsIzAFchIaA2Z0cyAAKgkaB3doaXNrZXkkS1IPd2VpZ2h0ZWRBdmFyYWdlWAJMDAsSDENvY2t0YWlsSW1wbCIGNDYtODE3DHIeGg93ZWlnaHRlZEF2YXJhZ2UgACoJIQAAAAAAAAAAggEA4AEAFA HTTP/1.1\r\nHost: 127.0.0.1:8888\nConnection: keep-alive\r\nX-Requested-With: XMLHttpRequest\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.904.0 Safari/535.7\r\nAccept: */*\r\nReferer: http://localhost:5323/\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: mp_super_properties=%7B%22all%22%3A%20%7B%22%24initial_referrer%22%3A%20%22http%3A//localhost%3A5323/%22%2C%22%24initial_referring_domain%22%3A%20%22localhost%3A5323%22%7D%2C%22events%22%3A%20%7B%7D%2C%22funnels%22%3A%20%7B%7D%7D\r\n\r\n
eos
    end

    it "should properly process proxies" do
      @proxies.map{|x|
        [x[0], x[1].to_s]
      }.should ==
        [["/test1", URI::parse("http://127.0.0.1:8000").to_s],
         ["/test2/", URI::parse("http://127.0.0.1:7000").to_s]]
    end

    it "should properly process proxy servers" do
      Slinky::ProxyServer.process_proxy_servers(@proxies).should ==
        [["127.0.0.1", 8000], ["127.0.0.1", 7000]]
    end

    it "should find the correct matcher for a request" do
      p = Slinky::ProxyServer.find_matcher(@proxies, "/test1/this/is/another")
      p[0].should == "/test1"
      p[1].to_s.should == "http://127.0.0.1:8000"

      p = Slinky::ProxyServer.find_matcher(@proxies, "/test2/whatsgoing.html?something=asdf")
      p[0].should == "/test2/"
      p[1].to_s.should == "http://127.0.0.1:7000"

      Slinky::ProxyServer.find_matcher(@proxies, "/asdf/test1/asdf").should == nil
      Slinky::ProxyServer.find_matcher(@proxies, "/test2x/asdf").should == nil
    end

    it "should properly parse out the path from a request" do
      method, path = @data.match(Slinky::ProxyServer::HTTP_MATCHER)[1..2]
      method.should == "GET"
      path.should == "/test1/something/and?q=asdf&c=E9oBiwFqZmoJam9uYXNmdXAyclkLEj0KABoMQ29ja3RhaWxJbXBsIzAFchIaA2Z0cyAAKgkaB3doaXNrZXkkS1IPd2VpZ2h0ZWRBdmFyYWdlWAJMDAsSDENvY2t0YWlsSW1wbCIGNDYtODE3DHIeGg93ZWlnaHRlZEF2YXJhZ2UgACoJIQAAAAAAAAAAggEA4AEAFA"
      Slinky::ProxyServer.find_matcher(@proxies, path)[0].should == "/test1"
    end

    it "should rewrite and replace paths correctly" do
      path = @data.match(Slinky::ProxyServer::HTTP_MATCHER)[2]
      p2 = Slinky::ProxyServer.rewrite_path(path, @proxies[0])
      p2.should == "/something/and?q=asdf&c=E9oBiwFqZmoJam9uYXNmdXAyclkLEj0KABoMQ29ja3RhaWxJbXBsIzAFchIaA2Z0cyAAKgkaB3doaXNrZXkkS1IPd2VpZ2h0ZWRBdmFyYWdlWAJMDAsSDENvY2t0YWlsSW1wbCIGNDYtODE3DHIeGg93ZWlnaHRlZEF2YXJhZ2UgACoJIQAAAAAAAAAAggEA4AEAFA"

      data = Slinky::ProxyServer.replace_path(@data, path, p2, @proxies[0][1].path)
      data.should == "GET /something/and?q=asdf&c=E9oBiwFqZmoJam9uYXNmdXAyclkLEj0KABoMQ29ja3RhaWxJbXBsIzAFchIaA2Z0cyAAKgkaB3doaXNrZXkkS1IPd2VpZ2h0ZWRBdmFyYWdlWAJMDAsSDENvY2t0YWlsSW1wbCIGNDYtODE3DHIeGg93ZWlnaHRlZEF2YXJhZ2UgACoJIQAAAAAAAAAAggEA4AEAFA HTTP/1.1\r\nHost: 127.0.0.1:8888\nConnection: keep-alive\r\nX-Requested-With: XMLHttpRequest\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.904.0 Safari/535.7\r\nAccept: */*\r\nReferer: http://localhost:5323/\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: mp_super_properties=%7B%22all%22%3A%20%7B%22%24initial_referrer%22%3A%20%22http%3A//localhost%3A5323/%22%2C%22%24initial_referring_domain%22%3A%20%22localhost%3A5323%22%7D%2C%22events%22%3A%20%7B%7D%2C%22funnels%22%3A%20%7B%7D%7D\r\n\r\n\n"

      data = Slinky::ProxyServer.replace_host(data,
                                              @proxies[0][1].select(:host, :port).join(":"))
      data.should == "GET /something/and?q=asdf&c=E9oBiwFqZmoJam9uYXNmdXAyclkLEj0KABoMQ29ja3RhaWxJbXBsIzAFchIaA2Z0cyAAKgkaB3doaXNrZXkkS1IPd2VpZ2h0ZWRBdmFyYWdlWAJMDAsSDENvY2t0YWlsSW1wbCIGNDYtODE3DHIeGg93ZWlnaHRlZEF2YXJhZ2UgACoJIQAAAAAAAAAAggEA4AEAFA HTTP/1.1\r\nHost: 127.0.0.1:8000\nConnection: keep-alive\r\nX-Requested-With: XMLHttpRequest\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_1) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.904.0 Safari/535.7\r\nAccept: */*\r\nReferer: http://localhost:5323/\r\nAccept-Encoding: gzip,deflate,sdch\r\nAccept-Language: en-US,en;q=0.8\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3\r\nCookie: mp_super_properties=%7B%22all%22%3A%20%7B%22%24initial_referrer%22%3A%20%22http%3A//localhost%3A5323/%22%2C%22%24initial_referring_domain%22%3A%20%22localhost%3A5323%22%7D%2C%22events%22%3A%20%7B%7D%2C%22funnels%22%3A%20%7B%7D%7D\r\n\r\n\n"
    end

    it "should support proxies with configuration" do
      @config = <<eos
proxy:
  "/test3":
    to: "http://127.0.0.1:6000"
    lag: 1000
eos
      @cr = Slinky::ConfigReader.new(@config)
      @proxies = Slinky::ProxyServer.process_proxies(@cr.proxy)

      @proxies[0][0].should == "/test3"
      @proxies[0][1].to_s.should == "http://127.0.0.1:6000"
      @proxies[0][2].should == {"lag" => 1000}
    end
  end
end
