require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

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
      @mprod = Slinky::Manifest.new("/tmp", :devel => false, :build_to => "/build")
      @mdevel = Slinky::Manifest.new("/tmp")
      @md_prod = @mprod.manifest_dir
      @md_devel = @mdevel.manifest_dir
    end
    
    it "should build manifest dir with all files in current dir" do
      @md_prod.files.collect{|f| f.source}.should == ["/tmp/test.haml"]
      @md_devel.files.collect{|f| f.source}.should == ["/tmp/test.haml"]
    end

    it "should build manifest with all files in fs" do
      @mprod.files.collect{|f|
        f.source
      }.sort.should == @files.collect{|x| "/tmp/" + x}.sort
      @mdevel.files.collect{|f|
        f.source
      }.sort.should == @files.collect{|x| "/tmp/" + x}.sort
    end

    it "should find files in the manifest by path" do
      @mdevel.find_by_path("test.haml").source.should == "/tmp/test.haml"
      @mdevel.find_by_path("asdf.haml").should == nil
      @mdevel.find_by_path("l1/l2/test.txt").source.should == "/tmp/l1/l2/test.txt"
      @mdevel.find_by_path("l1/test.css").source.should == "/tmp/l1/test.sass"
    end

    it "should produce the correct scripts string for production" do
      @mprod.scripts_string.should == '<script type="text/javscript" src="/scripts.js" />'
    end

    it "should produce the correct scripts string for devel" do
      @mdevel.scripts_string.should == '<script type="text/javascript" src="l1/test5.js" /><script type="text/javascript" src="l1/l2/test6.js" /><script type="text/javascript" src="l1/test2.js" /><script type="text/javascript" src="l1/l2/test3.js" /><script type="text/javascript" src="l1/test.js" />'
    end

    it "should produce the correct styles string for production" do
      @mprod.styles_string.should == '<link rel="stylesheet" href="/styles.css" />'
    end

    it "should produce the correct styles string for development" do
      File.open("/tmp/l1/l2/bad.sass", "w+"){|f|
        f.write "require('../test.sass')\ncolor: red;"
      }
      manifest = Slinky::Manifest.new("/tmp")
      @mdevel.styles_string.should == '<link rel="stylesheet" href="l1/test.css" /><link rel="stylesheet" href="l1/l2/test2.css" />'
    end

    it "should allow the creation of ManifestFiles" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "", @mprod)
    end

    it "should correctly determine output_path" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      mf.output_path.to_s.should == "/tmp/test.html"
      mf = Slinky::ManifestFile.new("/tmp/l1/test.js", "/tmp/build", @mprod)
      mf.output_path.to_s.should == "/tmp/l1/test.js"
    end

    it "should correctly determine relative_output_path" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      mf.relative_output_path.to_s.should == "test.html"
      mf = Slinky::ManifestFile.new("/tmp/l1/test.js", "/tmp/build", @mprod)
      mf.relative_output_path.to_s.should == "l1/test.js"
    end

    it "should build tmp file without directives" do
      original = "/tmp/test.haml"
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      path = mf.handle_directives
      File.read(original).match(/slinky_scripts|slinky_styles/).should_not == nil
      File.read(path).match(/slinky_scripts|slinky_styles/).should == nil
    end

    it "should compile files that need it" do
      $stdout.should_receive(:puts).with("Compiled /tmp/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      build_path = mf.process
      build_path.to_s.split(".")[-1].should == "html"
      File.read("/tmp/test.haml").match("<head>").should == nil
      File.read(build_path).match("<head>").should_not == nil

      $stdout.should_receive(:puts).with("Compiled /tmp/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      build_path = mf.process "/tmp/build/test.html"
      File.read("/tmp/build/test.html").match("<head>").should_not == nil
    end

    it "should report errors for bad files" do
      File.open("/tmp/l1/l2/bad.sass", "w+"){|f|
        f.write "color: red;"
      }
      $stderr.should_receive(:puts).with(/Failed on/)
      mf = Slinky::ManifestFile.new("/tmp/l1/l2/bad.sass", "/tmp/build", @mprod)
      build_path = mf.process
      build_path.should == nil
    end

    it "should properly determine build directives" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      mf.find_directives.should == {:slinky_scripts => [], :slinky_styles => []}
      mf = Slinky::ManifestFile.new("/tmp/l1/test.js", "/tmp/build", @mprod)
      mf.find_directives.should == {:slinky_require => ["test2.js", "l2/test3.js"]}
    end

    it "should properly determine build_to path" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      mf.build_to.should == Pathname.new("/tmp/build/test.html")
      mf = Slinky::ManifestFile.new("/tmp/l1/test.js", "/tmp/build", @mprod)
      mf.build_to.should == Pathname.new("/tmp/build/test.js")
    end

    it "should build both compiled files and non-compiled files" do
      $stdout.should_receive(:puts).with("Compiled /tmp/test.haml".foreground(:green))
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      path = mf.build
      path.to_s.should == "/tmp/build/test.html"
      File.read("/tmp/test.haml").match("<head>").should == nil
      File.read(path).match("<head>").should_not == nil

      $stdout.should_not_receive(:puts)
      mf = Slinky::ManifestFile.new("/tmp/l1/l2/test.txt", "/tmp/build/l1/l2", @mprod)
      path = mf.build
      path.to_s.should == "/tmp/build/l1/l2/test.txt"
      File.read("/tmp/build/l1/l2/test.txt").should == "hello\n"
    end

    it "should match files" do
      mf = Slinky::ManifestFile.new("/tmp/l1/l2/test.txt", "/tmp/build/l1/l2", @mprod)
      mf.matches?("test.txt").should == true
      mf = Slinky::ManifestFile.new("/tmp/l1/test.sass", "", @prod)
      mf.matches?("test.css").should == true
      mf.matches?("test.sass").should == true
    end

    it "should correctly build the dependency graph" do
      @mprod.build_dependency_graph.collect{|x| x.collect{|y| y.source}}.sort.should ==
        [["/tmp/l1/test2.js", "/tmp/l1/test.js"],
         ["/tmp/l1/l2/test3.coffee", "/tmp/l1/test.js"],
         ["/tmp/l1/test5.js", "/tmp/l1/test2.js"],
         ["/tmp/l1/l2/test6.js", "/tmp/l1/l2/test3.coffee"]].sort
    end

    it "should fail if a required file isn't in the manifest" do
      FileUtils.rm("/tmp/l1/test2.js")
      manifest = Slinky::Manifest.new("/tmp", :devel => false, :build_to => "/build")
      $stderr.should_receive(:puts).with("Could not find file test2.js required by /tmp/l1/test.js".foreground(:red))
      proc {
        manifest.build_dependency_graph
      }.should raise_error Slinky::FileNotFoundError
    end

    it "should build a correct dependency list" do
      @mprod.dependency_list.collect{|x| x.source}.should == ["/tmp/test.haml", "/tmp/l1/test.sass", "/tmp/l1/test5.js", "/tmp/l1/l2/test.txt", "/tmp/l1/l2/test2.css", "/tmp/l1/l2/test6.js", "/tmp/l1/l2/l3/test2.txt", "/tmp/l1/test2.js", "/tmp/l1/l2/test3.coffee", "/tmp/l1/test.js"]
    end

    it "should fail if there is a cycle in the dependency graph" do
      File.open("/tmp/l1/test5.js", "w+"){|f| f.write("slinky_require('test.js')")}
      manifest = Slinky::Manifest.new("/tmp", :devel => false, :build_to => "/build")
      $stderr.should_receive(:puts).with("Dependencies /tmp/l1/test2.js -> /tmp/l1/test.js, /tmp/l1/test5.js -> /tmp/l1/test2.js, /tmp/l1/test.js -> /tmp/l1/test5.js could not be satisfied".foreground(:red))
      proc { manifest.dependency_list }.should raise_error Slinky::DependencyError
    end
  end

  context "Server" do
    before :each do
      @resp = double("EventMachine::DelegatedHttpResponse")
      @resp.stub(:content=){|c| @content = c}
      @resp.stub(:content){ @content }
    end
    it "should start when passed 'start'" do
      $stdout.should_receive(:puts).with(/Started static file server on port 5323/)
      run_for 0.3 do
        Slinky::Runner.new(["start"]).run
      end
    end

    it "should accept a port option" do
      port = 53453
      $stdout.should_receive(:puts).with(/Started static file server on port #{port}/)
      run_for 0.3 do
        Slinky::Runner.new(["start","--port", port.to_s]).run
      end
    end

    it "path_for_uri should work correctly" do
      Slinky::Server.path_for_uri("http://localhost:124/test/hello/asdf.js?query=string&another").should == "test/hello/asdf.js"
    end

    it "should serve files" do
      @resp.should_receive(:content_type).with(MIME::Types.type_for("/tmp/l1/test.js").first)
      Slinky::Server.serve_file @resp, "/tmp/l1/test.js"
      @resp.content.should == File.read("/tmp/l1/test.js")
    end

    it "should serve 404s" do
      @resp.should_receive(:status=).with(404)
      Slinky::Server.serve_file @resp, "/tmp/asdf/faljshd"
      @resp.content.should == "File not found"
    end

    it "should handle static files" do
      mf = Slinky::ManifestFile.new("/tmp/l1/l2/test.txt", nil, @mdevel)
      @resp.should_receive(:content_type).with(MIME::Types.type_for("/tmp/l1/le/test.txt").first)
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == File.read("/tmp/l1/l2/test.txt")
    end

    it "should handle compiled files" do
      mf = Slinky::ManifestFile.new("/tmp/l1/test.sass", nil, @mdevel)
      @resp.should_receive(:content_type).with(MIME::Types.type_for("test.css").first)
      $stdout.should_receive(:puts).with("Compiled /tmp/l1/test.sass".foreground(:green))
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == Slinky::SassCompiler::compile(File.read("/tmp/l1/test.sass"), "")
    end

    it "should handle non-existant files" do
      mf = Slinky::ManifestFile.new("/tmp/l1/asdf.txt", nil, @mdevel)
      @resp.should_receive(:status=).with(404)
      Slinky::Server.handle_file @resp, mf
      @resp.content.should == "File not found"
    end
  end
  context "Builder" do
    before :each do
      @compilation_subs = {".sass" => ".css", ".coffee" => ".js", ".haml" => ".html"}
      module Slinky
        module CoffeeCompiler
          def CoffeeCompiler::compile s, file
            FakeFS.deactivate!
            o = CoffeeScript::compile(s)
            FakeFS.activate!
            o
          end
        end
      end
    end
    it "should build manifest to build directory" do
      $stdout.should_receive(:puts).with(/Compiled \/tmp\/.+/).exactly(3).times
      Slinky::Builder.build("/tmp", "/build")
      manifest = Slinky::Manifest.new("/build")
      manifest.files.collect{|f|
        f.source
      }.sort.should == @files.collect{|x|
        f = Pathname("/build/") + Pathname.new(x)
        f.sub_ext(@compilation_subs[f.extname] || f.extname).to_s
      }.sort
    end
  end
end
