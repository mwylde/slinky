$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'slinky'
require 'fakefs/safe'
require 'fileutils'
require 'cover_me'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.before :all do
    FakeFS.activate!
    FileUtils.mkdir("/tmp")
    FileUtils.cd("/tmp")
    FileUtils.mkdir_p("l1/l2/l3")
    File.open("test.haml", "w+"){|f|
      f.write <<eos
!!!5
%head
  slinky_scripts
  slinky_styles
%body
  h1. hello
eos
    }

    File.open("l1/test.sass", "w+"){|f|
      f.write <<eos
h1
  color: red
eos
    }

    File.open("l1/test.js", "w+"){|f|
      f.write <<eos
slinky_require('test2.js')
slinky_require("test3.js")
eos
    }

    File.open("l1/l2/test.txt", "w+"){|f| f.write("hello\n") }
    File.open("l1/l2/l3/test2.txt", "w+"){|f| f.write("goodbye\n") }

    @files = ["test.haml", "l1/test.js", "l1/test.sass", "l1/l2/test.txt", "l1/l2/l3/test2.txt"]
    FakeFS.deactivate!
  end
end

def run_for secs
  EM.run do
    yield
    EM.add_timer(secs) {
      EM.stop_event_loop
    }
  end
end

