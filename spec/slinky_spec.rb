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
    end

    it "should produce an appropriate scripts string for production" do
      @mprod.scripts_string.should == '<script type="text/javscript" src="/scripts.js" />'
    end

    it "should produce an appropriate scripts string for devel" do
      # @mdevel.scripts_string.should == '<
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

    it "should properly determine build directives" do
      mf = Slinky::ManifestFile.new("/tmp/test.haml", "/tmp/build", @mprod)
      mf.find_directives.should == {:slinky_scripts => [], :slinky_styles => []}
      mf = Slinky::ManifestFile.new("/tmp/l1/test.js", "/tmp/build", @mprod)
      mf.find_directives.should == {:slinky_require => ["test2.js", "test3.js"]}
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
  end

  context "Server" do
    it "should start when passed 'start'" do
      $stdout.should_receive(:puts).with(/Started static file server on port 5323/)
      run_for 1 do
        Slinky::Runner.new(["start"]).run
      end
    end
    
    it "should accept a port option" do
      port = 53453
      $stdout.should_receive(:puts).with(/Started static file server on port #{port}/)
      run_for 1 do
        Slinky::Runner.new(["start","--port", port.to_s]).run
      end
    end

    it "path_for_uri should work correctly" do
      Slinky::Server.path_for_uri("http://localhost:124/test/hello/asdf.js?query=string&another").should == "test/hello/asdf.js"
    end
  end
end

