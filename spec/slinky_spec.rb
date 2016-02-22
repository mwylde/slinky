require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'em-http'

describe "Slinky" do
  context "Runner" do
    it "should output help" do
      $stdout.should_receive(:puts).with(/slinky \d+\.\d+\.\d+/)
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

    it "should serve the processed version of static files" do
      Slinky::Server.manifest = @mdevel
      @resp.should_receive(:content_type)
        .with("application/javascript; charset=utf-8").at_least(:once)
      Slinky::Server.process_path @resp, "/l1/test.js"
      File.read("/src/l1/test.js").match("slinky_require").should_not == nil
      @resp.content.match("slinky_require").should == nil
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
      @resp.should_receive(:content_type).with("text/html; charset=utf-8").at_least(:once)
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
      @resp.should_receive(:content_type).with("text/html; charset=utf-8").at_least(:once)
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
      @resp.should_receive(:content_type).with("text/html; charset=utf-8").at_least(:once)
      Slinky::Server.process_path @resp, "hello/doesnt/exist.html"
      @resp.content.include?("goodbye").should == true
    end

    it "should accept a port option" do
      port = 53455
      $stdout.should_receive(:puts).with(/slinky \d+\.\d+\.\d+/)
      $stdout.should_receive(:puts).with(/Started static file server on port #{port}/)
      run_for 0.3 do
        Slinky::Runner.new(["start","--port", port.to_s, "--no-livereload"]).run
      end
    end

    it "should not crash for syntax errors" do
      File.open("/src/bad_file.haml", "w+"){|f| f.write("%head{") }
      mf = Slinky::ManifestFile.new("/src/bad_file.haml", nil, @mdevel)
      $stderr.should_receive(:puts).with(/Compilation failed/)
      @resp.should_receive(:status=).with(500)
      Slinky::Server.handle_file @resp, mf
    end

    it "should serve files for realz" do
      $stdout.should_receive(:puts).with(/slinky \d+\.\d+\.\d+/)
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
  "/test2": "http://127.0.0.1:7000/"
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
produce:
  "/scripts.js":
    include:
      - "**/src/*.js"
  "/tests.js":
    include:
      - "**/test/*.js "
eos
      File.open("/src/slinky.yaml", "w+"){|f| f.write @config}
      @proxies = {
        "/test1" => "http://127.0.0.1:8000",
        "/test2" => "http://127.0.0.1:7000/"
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
  "/test1": "http://127.0.0.1:8000/"
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
        [["/test1", URI::parse("http://127.0.0.1:8000/").to_s],
         ["/test2/", URI::parse("http://127.0.0.1:7000").to_s]]
    end

    it "should properly process proxy servers" do
      Slinky::ProxyServer.process_proxy_servers(@proxies).should ==
        [["127.0.0.1", 8000], ["127.0.0.1", 7000]]
    end

    it "should find the correct matcher for a request" do
      p = Slinky::ProxyServer.find_matcher(@proxies, "/test1/this/is/another")
      p[0].should == "/test1"
      p[1].to_s.should == "http://127.0.0.1:8000/"

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

    it "should properly rewrite slashes for '/'" do
      config = <<eos
proxy:
  "/": "http://127.0.0.1:6000/"
eos
      cr = Slinky::ConfigReader.new(config)
      proxies = Slinky::ProxyServer.process_proxies(cr.proxy)

      data = "GET /hello HTTP/1.1\r\nHost:127.0.0.1:8000\r\n\r\n\n" 
      path = data.match(Slinky::ProxyServer::HTTP_MATCHER)[2]
      p2 = Slinky::ProxyServer.rewrite_path(path, proxies[0])
      p2.should == "/hello"
    end
  end
end
