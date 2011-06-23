require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Slinky" do
  context "Runner" do
    it "should output help" do
      $stdout.should_receive(:puts).with(/Usage: slinky/)
      lambda { ::Slinky::Runner.new(["--help"]).run }.should raise_error SystemExit
    end

    it "should output a version" do
      $stdout.should_receive(:puts).with(/slinky \d+\.\d+\.\d+/)
      lambda { ::Slinky::Runner.new(["--version"]).run }.should raise_error SystemExit      
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
  end
end

